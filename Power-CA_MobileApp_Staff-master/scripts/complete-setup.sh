#!/bin/bash
#
# Complete Supabase VPS Setup Script
# This script completes the Nginx + SSL + Firewall + PostgreSQL configuration
#
# Prerequisites: Nginx and Certbot must be installed
# Usage: Run this on the VPS after SSH login
# bash complete-setup.sh
#

set -e  # Exit on error

echo "=================================================="
echo "  Supabase VPS Complete Setup"
echo "  Domain: api.pcamobile.cloud"
echo "=================================================="
echo ""

# Step 1: Create initial Nginx configuration (HTTP only for SSL cert)
echo "[1/10] Creating initial Nginx configuration..."
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

# Enable configuration
ln -sf /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "✓ Initial Nginx configuration created"
echo ""

# Step 2: Obtain SSL certificate
echo "[2/10] Obtaining SSL certificate from Let's Encrypt..."
certbot certonly --nginx \
  -d api.pcamobile.cloud \
  --non-interactive \
  --agree-tos \
  --email admin@pcamobile.cloud

echo "✓ SSL certificate obtained"
echo ""

# Step 3: Create full Nginx configuration with SSL
echo "[3/10] Creating full Nginx configuration with SSL..."
cat > /etc/nginx/sites-available/supabase << 'EOF'
# Rate limiting zones
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

    # Proxy
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

nginx -t
systemctl reload nginx

echo "✓ Full Nginx configuration with SSL applied"
echo ""

# Step 4: Configure Firewall
echo "[4/10] Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "✓ Firewall configured"
echo ""

# Step 5: Expose PostgreSQL port in docker-compose
echo "[5/10] Configuring PostgreSQL for external access..."
cd /root/supabase/docker

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

# Add port mapping to db service if not already present
if ! grep -q "5432:5432" docker-compose.yml; then
    sed -i '/container_name: supabase-db/,/volumes:/ {
        /restart: unless-stopped/a\    ports:\n      - "5432:5432"
    }' docker-compose.yml
    echo "✓ PostgreSQL port added to docker-compose.yml"
else
    echo "✓ PostgreSQL port already exposed"
fi

echo ""

# Step 6: Restart Supabase with new configuration
echo "[6/10] Restarting Supabase stack..."
docker compose down
docker compose up -d

echo "Waiting for services to start..."
sleep 30

# Check status
docker compose ps

echo "✓ Supabase restarted"
echo ""

# Step 7: Create sync user
echo "[7/10] Creating PostgreSQL sync user..."

SYNC_PASSWORD=$(grep "SYNC_USER_PASSWORD=" /root/supabase-secrets.txt | cut -d'=' -f2)

docker exec supabase-db psql -U postgres << EOSQL
-- Create sync user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'sync_user') THEN
        CREATE USER sync_user WITH PASSWORD '${SYNC_PASSWORD}';
    END IF;
END
\$\$;

-- Grant permissions
GRANT CONNECT ON DATABASE postgres TO sync_user;
GRANT USAGE ON SCHEMA public TO sync_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sync_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sync_user;

-- Verify
\du sync_user
EOSQL

echo "✓ Sync user created"
echo ""

# Step 8: Create storage buckets
echo "[8/10] Creating storage buckets..."

docker exec supabase-db psql -U postgres << 'EOSQL'
-- Create avatars bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- Create documents bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'documents',
    'documents',
    false,
    104857600,
    ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO NOTHING;

-- Storage policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Avatar images are publicly accessible'
    ) THEN
        CREATE POLICY "Avatar images are publicly accessible"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'avatars');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can upload an avatar'
    ) THEN
        CREATE POLICY "Anyone can upload an avatar"
        ON storage.objects FOR INSERT
        WITH CHECK (bucket_id = 'avatars');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can read documents'
    ) THEN
        CREATE POLICY "Authenticated users can read documents"
        ON storage.objects FOR SELECT
        TO authenticated
        USING (bucket_id = 'documents');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Authenticated users can upload documents'
    ) THEN
        CREATE POLICY "Authenticated users can upload documents"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'documents');
    END IF;
END $$;

SELECT * FROM storage.buckets;
EOSQL

echo "✓ Storage buckets created"
echo ""

# Step 9: Set up backups
echo "[9/10] Setting up automated backups..."

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

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null | grep -v backup-supabase; echo "0 2 * * * /root/scripts/backup-supabase.sh >> /var/log/supabase-backup.log 2>&1") | crontab -

# Test backup
/root/scripts/backup-supabase.sh

echo "✓ Backup system configured"
echo ""

# Step 10: Configure Docker log rotation
echo "[10/10] Configuring Docker log rotation..."

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

echo "✓ Docker log rotation configured"
echo ""

echo "=================================================="
echo "  Setup Complete!"
echo "=================================================="
echo ""
echo "✅ Nginx with SSL configured"
echo "✅ Firewall enabled"
echo "✅ PostgreSQL accessible externally"
echo "✅ Sync user created"
echo "✅ Storage buckets configured"
echo "✅ Automated backups enabled"
echo ""
echo "Next Steps:"
echo "1. Test access: https://api.pcamobile.cloud"
echo "2. Login to dashboard with:"
echo "   - Username: admin"
echo "   - Password: (check /root/supabase-secrets.txt)"
echo "3. Configure your Flutter app with:"
echo "   - URL: https://api.pcamobile.cloud"
echo "   - ANON_KEY: (check /root/supabase-secrets.txt)"
echo ""
echo "To add firewall rule for sync server:"
echo "ufw allow from YOUR_LOCAL_IP to any port 5432 proto tcp comment 'PostgreSQL from sync server'"
echo ""
echo "View secrets: cat /root/supabase-secrets.txt"
echo "Check status: docker compose -f /root/supabase/docker/docker-compose.yml ps"
echo ""
