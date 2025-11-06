# Supabase VPS Setup - Quick Start Guide

## 🎯 Overview

This guide will help you complete your Supabase VPS setup in about 10-15 minutes.

**What We're Setting Up:**
- ✅ Supabase backend on VPS (api.pcamobile.cloud)
- ✅ SSL/HTTPS with Let's Encrypt
- ✅ Firewall security
- ✅ PostgreSQL external access for sync
- ✅ Storage buckets and authentication
- ✅ Automated backups

---

## 📋 Prerequisites

### Already Completed ✅
- [x] Domain configured: `api.pcamobile.cloud` → `72.60.220.188`
- [x] Production secrets generated (saved in supabase-vps-setup.md)
- [x] JWT tokens created (ANON_KEY, SERVICE_ROLE_KEY)
- [x] Supabase .env updated with production values

### What You Need
- [ ] SSH access to VPS (root password from Hostinger)
- [ ] 10-15 minutes of time
- [ ] Windows terminal or PowerShell

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Connect to VPS via SSH (2 minutes)

**Open PowerShell and run:**
```powershell
ssh root@72.60.220.188
```

**Enter your root password when prompted** (you won't see it typing)

**Need help?** See detailed instructions in [SSH-CONNECTION-GUIDE.md](./SSH-CONNECTION-GUIDE.md)

---

### Step 2: Upload and Run Complete Setup Script (5 minutes)

Once connected to VPS, run these commands:

```bash
# Create the complete setup script
cat > /tmp/complete-setup.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "=================================================="
echo "  Supabase VPS Complete Setup"
echo "=================================================="
echo ""

# 1. Install Nginx and Certbot
echo "[1/10] Installing Nginx and Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx
systemctl enable nginx

# 2. Create initial Nginx config (HTTP for cert)
echo "[2/10] Creating initial Nginx configuration..."
cat > /etc/nginx/sites-available/supabase << 'EOF'
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

ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# 3. Obtain SSL certificate
echo "[3/10] Obtaining SSL certificate..."
certbot certonly --nginx -d api.pcamobile.cloud --non-interactive --agree-tos --email admin@pcamobile.cloud

# 4. Create full Nginx config with SSL
echo "[4/10] Updating Nginx with SSL..."
cat > /etc/nginx/sites-available/supabase << 'EOF'
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;

upstream supabase_kong {
    server localhost:8000;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name api.pcamobile.cloud;
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.pcamobile.cloud;

    ssl_certificate /etc/letsencrypt/live/api.pcamobile.cloud/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.pcamobile.cloud/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    access_log /var/log/nginx/supabase_access.log;
    error_log /var/log/nginx/supabase_error.log;
    client_max_body_size 100M;

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
    }

    location /auth/ {
        limit_req zone=auth_limit burst=10 nodelay;
        proxy_pass http://supabase_kong;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

nginx -t && systemctl reload nginx

# 5. Configure firewall
echo "[5/10] Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

# 6. Configure PostgreSQL
echo "[6/10] Configuring PostgreSQL..."
cd /root/supabase/docker
cp docker-compose.yml docker-compose.yml.backup.\$(date +%Y%m%d_%H%M%S)
if ! grep -q "5432:5432" docker-compose.yml; then
    sed -i '/container_name: supabase-db/,/volumes:/ { /restart: unless-stopped/a\    ports:\n      - "5432:5432" }' docker-compose.yml
fi

# 7. Restart Supabase
echo "[7/10] Restarting Supabase..."
docker compose down && docker compose up -d
sleep 30

# 8. Create sync user
echo "[8/10] Creating sync user..."
SYNC_PASSWORD=\$(grep "SYNC_USER_PASSWORD=" /root/supabase-secrets.txt | cut -d'=' -f2)
docker exec supabase-db psql -U postgres << EOSQL
DO \\\$\\\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'sync_user') THEN
        CREATE USER sync_user WITH PASSWORD '\${SYNC_PASSWORD}';
    END IF;
END \\\$\\\$;
GRANT CONNECT ON DATABASE postgres TO sync_user;
GRANT USAGE ON SCHEMA public TO sync_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sync_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sync_user;
EOSQL

# 9. Create storage buckets
echo "[9/10] Creating storage buckets..."
docker exec supabase-db psql -U postgres << 'EOSQL'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg']) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documents', 'documents', false, 104857600, ARRAY['application/pdf']) ON CONFLICT DO NOTHING;
EOSQL

# 10. Set up backups
echo "[10/10] Setting up backups..."
mkdir -p /root/scripts /root/backups/supabase
cat > /root/scripts/backup-supabase.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/backups/supabase"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR
docker exec supabase-db pg_dumpall -U postgres | gzip > \$BACKUP_DIR/postgres_\$DATE.sql.gz
find \$BACKUP_DIR -name "postgres_*.sql.gz" -mtime +7 -delete
echo "Backup completed: \$DATE"
EOF
chmod +x /root/scripts/backup-supabase.sh
(crontab -l 2>/dev/null | grep -v backup-supabase; echo "0 2 * * * /root/scripts/backup-supabase.sh >> /var/log/supabase-backup.log 2>&1") | crontab -
/root/scripts/backup-supabase.sh

echo ""
echo "=================================================="
echo "  ✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Test your installation:"
echo "  https://api.pcamobile.cloud"
echo ""
echo "Dashboard login:"
echo "  cat /root/supabase-secrets.txt | grep DASHBOARD"
echo ""
echo "Flutter app credentials:"
echo "  cat /root/supabase-secrets.txt | grep -E '(ANON_KEY|SERVICE_ROLE_KEY)'"
echo ""
EOFSCRIPT

# Run the script
chmod +x /tmp/complete-setup.sh
bash /tmp/complete-setup.sh
```

**This will take about 5 minutes to complete.**

---

### Step 3: Verify Installation (2 minutes)

After the script completes, run:

```bash
# Test HTTPS access
curl -I https://api.pcamobile.cloud

# Check Supabase containers
docker compose -f /root/supabase/docker/docker-compose.yml ps

# View your secrets
cat /root/supabase-secrets.txt

# Test SSL certificate
certbot certificates
```

**Expected output:** All containers should be "healthy" and HTTPS should return `200 OK`

---

## 📝 Important: Save Your Credentials

### 1. Supabase Dashboard Access
```bash
cat /root/supabase-secrets.txt | grep -E '(DASHBOARD_USERNAME|DASHBOARD_PASSWORD)'
```

**URL**: https://api.pcamobile.cloud

### 2. Flutter App Credentials
```bash
cat /root/supabase-secrets.txt | grep -E '(ANON_KEY|SERVICE_ROLE_KEY)'
```

**Copy these values to your Flutter project!**

---

## 🔐 Additional Configuration

### Allow Your Local IP for PostgreSQL Sync

**Find your IP:** Visit https://whatismyipaddress.com/

**Add firewall rule:**
```bash
ufw allow from YOUR_LOCAL_IP to any port 5432 proto tcp comment 'PostgreSQL sync'
ufw status
```

---

## ✅ Verification Checklist

Run these commands to verify everything is working:

```bash
# 1. HTTPS working
curl -I https://api.pcamobile.cloud
# Should return: HTTP/2 200

# 2. Containers healthy
docker ps --filter name=supabase
# All should show "healthy"

# 3. SSL certificate
certbot certificates
# Should show: Valid until ~3 months from now

# 4. Firewall active
ufw status
# Should show: Status: active

# 5. PostgreSQL accessible
psql -h 127.0.0.1 -U postgres -d postgres -c "SELECT version();"
# Should show PostgreSQL version

# 6. Backup configured
ls -lh /root/backups/supabase/
# Should show recent backup file

# 7. Cron job scheduled
crontab -l
# Should show backup cron job
```

---

## 🎓 What We've Accomplished

✅ **SSL/HTTPS**: Your API is secure with Let's Encrypt certificate
✅ **Firewall**: Only necessary ports are open (22, 80, 443)
✅ **Production Config**: All default passwords changed to secure values
✅ **PostgreSQL Access**: Ready for external sync from your local server
✅ **Storage**: Buckets created for avatars and documents
✅ **Backups**: Daily automated backups at 2 AM
✅ **Authentication**: Ready for user signup/login

---

## 📱 Next Steps: Flutter Integration

Your Supabase backend is ready! Here's what to do next:

### 1. Create Flutter Project
```bash
flutter create power_ca_mobile
cd power_ca_mobile
flutter pub add supabase_flutter
```

### 2. Initialize Supabase in Flutter
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://api.pcamobile.cloud',
    anonKey: 'YOUR_ANON_KEY_FROM_SECRETS_FILE',
  );

  runApp(MyApp());
}
```

### 3. Set Up Data Sync (Phase 2A)
Follow the sync script documentation to replicate data from your local Power CA database to Supabase.

---

## 🆘 Troubleshooting

### Issue: SSL certificate failed
```bash
# Check domain DNS
nslookup api.pcamobile.cloud
# Should return: 72.60.220.188

# Retry certificate
certbot certonly --nginx -d api.pcamobile.cloud --force-renewal
```

### Issue: Containers not healthy
```bash
# Check logs
docker compose -f /root/supabase/docker/docker-compose.yml logs --tail=100

# Restart
docker compose -f /root/supabase/docker/docker-compose.yml restart
```

### Issue: Can't access dashboard
```bash
# Check Kong is running
docker ps | grep kong

# Test locally
curl http://localhost:8000/health

# Check Nginx
systemctl status nginx
nginx -t
```

---

## 📚 Documentation Reference

- **Detailed Setup**: [SETUP-GUIDE.md](./SETUP-GUIDE.md)
- **SSH Help**: [SSH-CONNECTION-GUIDE.md](./SSH-CONNECTION-GUIDE.md)
- **Secrets**: [supabase-vps-setup.md](./supabase-vps-setup.md)

---

## 🎯 Summary

**Time**: ~10-15 minutes
**Difficulty**: Easy
**Result**: Production-ready Supabase backend with SSL, security, and automated backups

**Your Supabase API**: https://api.pcamobile.cloud
**Dashboard**: https://api.pcamobile.cloud (login with admin credentials)

Ready to build your Flutter app! 🚀

---

**Created**: 2025-10-28
**Status**: Ready for execution
**Support**: Refer to detailed guides for help
