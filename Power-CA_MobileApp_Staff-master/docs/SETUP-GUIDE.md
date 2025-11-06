# Supabase VPS Setup - Step-by-Step Guide

## Prerequisites
- SSH access to your VPS: `root@72.60.220.188`
- Domain configured: `api.pcamobile.cloud` → `72.60.220.188`
- Windows terminal or PowerShell for SSH

## 📋 Table of Contents
1. [Phase 1: Generate Production Secrets](#phase-1-generate-production-secrets)
2. [Phase 2: Backup & Update Supabase Configuration](#phase-2-backup--update-supabase-configuration)
3. [Phase 3: Install & Configure Nginx + SSL](#phase-3-install--configure-nginx--ssl)
4. [Phase 4: Configure Firewall](#phase-4-configure-firewall)
5. [Phase 5: Configure PostgreSQL for External Access](#phase-5-configure-postgresql-for-external-access)
6. [Phase 6: Set Up Storage & Authentication](#phase-6-set-up-storage--authentication)
7. [Phase 7: Security Hardening & Backups](#phase-7-security-hardening--backups)

---

## Phase 1: Generate Production Secrets

### Step 1.1: Connect to VPS
```bash
ssh root@72.60.220.188
```

### Step 1.2: Generate All Secrets
Copy and run this entire script on your VPS:

```bash
# Create and run secret generation script
cat > /tmp/gen-secrets.sh << 'EOF'
#!/bin/bash
echo "=================================================="
echo "  Generating Production Secrets"
echo "=================================================="

# Generate all secrets
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
DASHBOARD_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
VAULT_ENC_KEY=$(openssl rand -base64 32 | tr -d '\n')
PG_META_CRYPTO_KEY=$(openssl rand -base64 32 | tr -d '\n')
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')
LOGFLARE_API_KEY=$(openssl rand -base64 48 | tr -d '\n')
SYNC_USER_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

# Save to file
SECRETS_FILE="/root/supabase-secrets.txt"
cat > "$SECRETS_FILE" <<SECRETS
================================================
SUPABASE PRODUCTION SECRETS
Generated: $(date)
================================================

JWT_SECRET=$JWT_SECRET
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=$DASHBOARD_PASSWORD
VAULT_ENC_KEY=$VAULT_ENC_KEY
PG_META_CRYPTO_KEY=$PG_META_CRYPTO_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE
LOGFLARE_API_KEY=$LOGFLARE_API_KEY
SYNC_USER_PASSWORD=$SYNC_USER_PASSWORD

================================================
NEXT: Generate JWT Keys at https://jwt.io
================================================
Use JWT_SECRET above as the "secret" field

FOR ANON_KEY:
Algorithm: HS256
Payload:
{
  "role": "anon",
  "iss": "supabase",
  "iat": 1730000000,
  "exp": 1893456000
}

FOR SERVICE_ROLE_KEY:
Algorithm: HS256
Payload:
{
  "role": "service_role",
  "iss": "supabase",
  "iat": 1730000000,
  "exp": 1893456000
}
================================================
SECRETS

cat "$SECRETS_FILE"
echo ""
echo "Secrets saved to: $SECRETS_FILE"
echo ""
echo "⚠️  IMPORTANT: Copy these secrets to your password manager NOW!"
EOF

chmod +x /tmp/gen-secrets.sh
/tmp/gen-secrets.sh
```

### Step 1.3: Generate JWT Keys

1. Open https://jwt.io in your browser
2. Copy the `JWT_SECRET` value from the output above
3. Generate **ANON_KEY**:
   - Algorithm: HS256
   - Payload:
     ```json
     {
       "role": "anon",
       "iss": "supabase",
       "iat": 1730000000,
       "exp": 1893456000
     }
     ```
   - Paste your `JWT_SECRET` in the "your-256-bit-secret" field
   - Copy the generated token (left side) - this is your `ANON_KEY`

4. Generate **SERVICE_ROLE_KEY**:
   - Same process, but change payload `role` to `"service_role"`
   - Copy the generated token - this is your `SERVICE_ROLE_KEY`

5. Add these to your secrets file:
```bash
cat >> /root/supabase-secrets.txt << EOF

ANON_KEY=<paste-your-anon-key-here>
SERVICE_ROLE_KEY=<paste-your-service-role-key-here>
EOF
```

### Step 1.4: View Complete Secrets
```bash
cat /root/supabase-secrets.txt
```

**⚠️ CRITICAL: Copy all secrets to a secure password manager before proceeding!**

---

## Phase 2: Backup & Update Supabase Configuration

### Step 2.1: Backup Current Configuration
```bash
cd /root/supabase/docker
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
ls -la .env*
```

### Step 2.2: View Current .env
```bash
cat /root/supabase/docker/.env | head -30
```

### Step 2.3: Update .env File
You need to update these specific values in `/root/supabase/docker/.env`:

```bash
# Edit the .env file
nano /root/supabase/docker/.env
```

**Update these lines** (use secrets from `/root/supabase-secrets.txt`):

```env
############
# Secrets
############
POSTGRES_PASSWORD=<your-generated-postgres-password>
JWT_SECRET=<your-generated-jwt-secret>
ANON_KEY=<your-generated-anon-key>
SERVICE_ROLE_KEY=<your-generated-service-role-key>
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=<your-generated-dashboard-password>
SECRET_KEY_BASE=<your-generated-secret-key-base>

############
# API URLs (IMPORTANT!)
############
SITE_URL=https://api.pcamobile.cloud
API_EXTERNAL_URL=https://api.pcamobile.cloud
SUPABASE_PUBLIC_URL=https://api.pcamobile.cloud

############
# Database
############
POSTGRES_DB=postgres
POSTGRES_HOST=db
POSTGRES_PORT=5432

############
# Email (update with your SMTP details later)
############
SMTP_ADMIN_EMAIL=admin@pcamobile.cloud
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_SENDER_NAME=PowerCA Mobile
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=false

############
# Additional Settings
############
ENABLE_ANONYMOUS_USERS=false
DISABLE_SIGNUP=false
```

**Save and exit**: `Ctrl+X`, then `Y`, then `Enter`

### Step 2.4: Verify Configuration
```bash
grep -v '^#' /root/supabase/docker/.env | grep -v '^$' | head -25
```

---

## Phase 3: Install & Configure Nginx + SSL

### Step 3.1: Install Nginx and Certbot
```bash
apt update
apt install -y nginx certbot python3-certbot-nginx
```

### Step 3.2: Create Nginx Configuration
```bash
cat > /etc/nginx/sites-available/supabase << 'EOF'
# HTTP - for Let's Encrypt verification
server {
    listen 80;
    listen [::]:80;
    server_name api.pcamobile.cloud;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF

# Enable configuration
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test configuration
nginx -t

# Start Nginx
systemctl start nginx
systemctl enable nginx
systemctl status nginx
```

### Step 3.3: Obtain SSL Certificate
```bash
certbot certonly --nginx \
  -d api.pcamobile.cloud \
  --non-interactive \
  --agree-tos \
  --email admin@pcamobile.cloud

# Verify certificate
certbot certificates
```

### Step 3.4: Update Nginx with Full HTTPS Configuration
```bash
cat > /etc/nginx/sites-available/supabase << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;

upstream supabase_kong {
    server localhost:8000;
    keepalive 32;
}

# HTTP -> HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name api.pcamobile.cloud;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.pcamobile.cloud;

    # SSL
    ssl_certificate /etc/letsencrypt/live/api.pcamobile.cloud/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.pcamobile.cloud/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Logs
    access_log /var/log/nginx/supabase_access.log;
    error_log /var/log/nginx/supabase_error.log;

    client_max_body_size 100M;

    # Proxy settings
    location / {
        limit_req zone=api_limit burst=20 nodelay;

        proxy_pass http://supabase_kong;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
    }

    # Auth with stricter limits
    location /auth/ {
        limit_req zone=auth_limit burst=10 nodelay;
        proxy_pass http://supabase_kong;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Test and reload
nginx -t
systemctl reload nginx
```

### Step 3.5: Test SSL
```bash
curl -I https://api.pcamobile.cloud
```

---

## Phase 4: Configure Firewall

```bash
# Reset UFW
ufw --force reset

# Set defaults
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (CRITICAL!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP/HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable firewall
ufw enable

# Check status
ufw status numbered
```

**Note:** We'll add PostgreSQL rules later after we know your local IP address for the sync script.

---

## Phase 5: Configure PostgreSQL for External Access

### Step 5.1: Expose PostgreSQL Port
```bash
cd /root/supabase/docker
nano docker-compose.yml
```

Find the `db:` service section and add port mapping:
```yaml
  db:
    container_name: supabase-db
    image: supabase/postgres:15.8.1.085
    # ... other config ...
    ports:
      - "5432:5432"  # ADD THIS LINE
    # ... rest of config ...
```

Save and exit: `Ctrl+X`, `Y`, `Enter`

### Step 5.2: Restart Supabase Stack
```bash
cd /root/supabase/docker
docker compose down
docker compose up -d

# Wait for services to start
sleep 30

# Check status
docker compose ps
```

### Step 5.3: Create Sync User
```bash
docker exec -it supabase-db psql -U postgres << 'EOF'
-- Create sync user
CREATE USER sync_user WITH PASSWORD '<use-SYNC_USER_PASSWORD-from-secrets-file>';

-- Grant permissions
GRANT CONNECT ON DATABASE postgres TO sync_user;
GRANT USAGE ON SCHEMA public TO sync_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sync_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sync_user;

-- Verify
\du sync_user
EOF
```

### Step 5.4: Allow PostgreSQL Through Firewall
**Replace `YOUR_LOCAL_IP` with your actual office/home IP address:**

```bash
# Find your IP at: https://whatismyipaddress.com/
ufw allow from YOUR_LOCAL_IP to any port 5432 proto tcp comment 'PostgreSQL from sync server'
ufw status
```

### Step 5.5: Test External Connection
**From your local Windows machine:**

```powershell
# Test connection (if you have psql installed)
psql -h 72.60.220.188 -U sync_user -d postgres -p 5432
# Enter the SYNC_USER_PASSWORD when prompted
```

---

## Phase 6: Set Up Storage & Authentication

### Step 6.1: Access Supabase Dashboard
1. Open browser: https://api.pcamobile.cloud
2. Login with:
   - Username: `admin`
   - Password: `<your-DASHBOARD_PASSWORD>`

### Step 6.2: Create Storage Buckets via SQL
```bash
docker exec -it supabase-db psql -U postgres << 'EOF'
-- Create avatars bucket (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create documents bucket (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    false,
    104857600,
    ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Anyone can upload an avatar"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'avatars');

-- Documents policies
CREATE POLICY "Authenticated users can read documents"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'documents');

CREATE POLICY "Authenticated users can upload documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'documents');

-- Verify
SELECT * FROM storage.buckets;
EOF
```

### Step 6.3: Create Example Profiles Table with RLS
```bash
docker exec -it supabase-db psql -U postgres << 'EOF'
-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Verify
\d public.profiles
EOF
```

### Step 6.4: Test Authentication
```bash
# Get your ANON_KEY from secrets file
ANON_KEY=$(grep "ANON_KEY=" /root/supabase-secrets.txt | cut -d'=' -f2)

# Test signup
curl -X POST "https://api.pcamobile.cloud/auth/v1/signup" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpassword123"
  }'
```

---

## Phase 7: Security Hardening & Backups

### Step 7.1: Configure Unattended Upgrades
```bash
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

### Step 7.2: Docker Log Rotation
```bash
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker
cd /root/supabase/docker
docker compose up -d
```

### Step 7.3: Create Backup Script
```bash
mkdir -p /root/scripts /root/backups/supabase

cat > /root/scripts/backup-supabase.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups/supabase"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker exec supabase-db pg_dumpall -U postgres | gzip > $BACKUP_DIR/postgres_$DATE.sql.gz

# Backup config
cp /root/supabase/docker/.env $BACKUP_DIR/env_$DATE.bak

# Clean old backups
find $BACKUP_DIR -name "postgres_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "env_*.bak" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
EOF

chmod +x /root/scripts/backup-supabase.sh

# Test backup
/root/scripts/backup-supabase.sh
ls -lh /root/backups/supabase/
```

### Step 7.4: Schedule Daily Backups
```bash
# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /root/scripts/backup-supabase.sh >> /var/log/supabase-backup.log 2>&1") | crontab -

# Verify
crontab -l
```

### Step 7.5: Delete Secrets File
```bash
# ONLY after you've saved all secrets to your password manager
rm /root/supabase-secrets.txt
```

---

## ✅ Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. Check Supabase containers
docker compose -f /root/supabase/docker/docker-compose.yml ps

# 2. Check Nginx
systemctl status nginx
curl -I https://api.pcamobile.cloud

# 3. Check SSL certificate
certbot certificates

# 4. Check firewall
ufw status numbered

# 5. Test Supabase API
curl https://api.pcamobile.cloud/health

# 6. Check PostgreSQL connection
docker exec -it supabase-db psql -U postgres -c "SELECT version();"

# 7. Verify backups
ls -lh /root/backups/supabase/

# 8. Check cron jobs
crontab -l
```

---

## 🎯 Next Steps

1. Save API keys for your Flutter app:
   - API URL: `https://api.pcamobile.cloud`
   - ANON_KEY: (from secrets file)
   - SERVICE_ROLE_KEY: (from secrets file - keep secret!)

2. Configure SMTP for email authentication (update .env)

3. Create your Power CA custom database schema

4. Set up the sync script (Phase 2A documentation)

---

## 📞 Support

If you encounter issues:
1. Check logs: `docker compose -f /root/supabase/docker/docker-compose.yml logs --tail=100`
2. Check Nginx logs: `tail -f /var/log/nginx/supabase_error.log`
3. Verify DNS: `nslookup api.pcamobile.cloud`

**Documentation created**: 2025-10-28
