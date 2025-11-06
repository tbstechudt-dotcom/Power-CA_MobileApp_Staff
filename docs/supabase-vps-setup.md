# Supabase VPS Setup Documentation

## Project Details
- **Domain**: api.pcamobile.cloud
- **VPS IP**: 72.60.220.188
- **OS**: Ubuntu 24.04
- **Location**: India - Mumbai
- **Resources**: 1 CPU, 4GB RAM, 50GB Disk

## Setup Progress

### Phase 1: VPS Supabase Production Setup

#### 1.1 Production Secrets Generated
**Date**: 2025-10-28

Generated secrets will be documented below. **KEEP THIS FILE SECURE AND DO NOT COMMIT TO GIT!**

```
# JWT Secret (for signing tokens)
JWT_SECRET=Jd5crFW4JOC76iNOyAKxm8cTt1fK9ZUlJ3h8Vh9rVKHeV9dvWvxjOilg0vvHBB5J

# ANON Key (public, for client apps)
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzMwMDAwMDAwLCJleHAiOjE4OTM0NTYwMDB9.0J8dOZaEPmKR3mlvZq0Zvnl9Lw3ZDv8Xhe35qGO3DMI

# SERVICE_ROLE_KEY (secret, for admin operations - KEEP SECRET!)
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MzAwMDAwMDAsImV4cCI6MTg5MzQ1NjAwMH0.3tD3kWNs1odidQuVEbQZ4nhs9F2COC8Y7Eo3qckNhVs

# PostgreSQL Password
POSTGRES_PASSWORD=pHOcVN/dcHk9tRGpO9NCMMF/Ku6AIO1vChQ9usdxnfU=

# Dashboard Credentials
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=/jS8Nfopay0HHE4Uz4n45iceYKqxJwRR

# Vault Encryption Key
VAULT_ENC_KEY=n/LPFozj447C9G5g57fmdmH/5y1fUNWMQLCOLzlJDo8=

# PG Meta Crypto Key
PG_META_CRYPTO_KEY=khXBVUgCHh4YtT1NnLrn2rH7YvGfmLiIhT150ZVnEN0=

# Secret Key Base
SECRET_KEY_BASE=FM9xizj2pbCYV/Hkf/tEZz99r32Mu1XP1ibYeDXnKzh9rc9vMstyfcwGEgM44bzKCNxjFqOVBgisqd8Jq+Pkkg==

# Logflare API Key
LOGFLARE_API_KEY=CjqBdSfTTEIqIBCot/Nxu0FeLSYvhiSJzs29eumLfDXRs//OxZMJN4fxUJO+rJhi

# PostgreSQL Sync User (for data replication)
SYNC_USER_PASSWORD=qUpmfZ9rvDF9RNG8ry7na5TTwkTnxUvejqqMbH8IDhY=
```

#### 1.2 Configuration Updates
- Backup location: `/root/supabase/docker/.env.backup.<timestamp>`
- Production .env: `/root/supabase/docker/.env`

#### 1.3 SSL Configuration
- Certificate path: `/etc/letsencrypt/live/api.pcamobile.cloud/`
- Nginx config: `/etc/nginx/sites-available/supabase`
- Auto-renewal: Configured via certbot systemd timer

#### 1.4 Firewall Rules
```
- Port 22 (SSH): Allowed
- Port 80 (HTTP): Allowed
- Port 443 (HTTPS): Allowed
- Port 5432 (PostgreSQL): Allowed from specific IPs only
```

#### 1.5 Database Access
- Sync user: `sync_user`
- Connection string: `postgresql://sync_user:<password>@72.60.220.188:5432/postgres`

### Phase 2A: Sync Script Setup

#### Project Location
- Local path: `d:\PowerCA Mobile\supabase-sync\`
- Configuration: `.env` file with source and target DB details

#### Sync Configuration
- Sync method: Timestamp-based change detection
- Frequency: Configurable (default: daily or on-demand)
- Tables to sync: TBD based on Power CA schema

## Important URLs

- **Supabase API**: https://api.pcamobile.cloud
- **Supabase Dashboard**: https://api.pcamobile.cloud (same URL)
- **PostgreSQL**: 72.60.220.188:5432

## Backup Strategy

- Daily automated backups at 2 AM IST
- Backup location: `/root/backups/supabase/`
- Retention: 7 days

## Maintenance Commands

### Check Supabase Status
```bash
ssh root@72.60.220.188 "cd /root/supabase/docker && docker compose ps"
```

### View Logs
```bash
ssh root@72.60.220.188 "cd /root/supabase/docker && docker compose logs --tail=100 -f"
```

### Restart Services
```bash
ssh root@72.60.220.188 "cd /root/supabase/docker && docker compose restart"
```

### Check SSL Certificate
```bash
ssh root@72.60.220.188 "certbot certificates"
```

### Manual Backup
```bash
ssh root@72.60.220.188 "/root/scripts/backup-supabase.sh"
```

## Security Notes

1. **NEVER** commit this file to version control
2. Store secrets in a secure password manager
3. Rotate secrets periodically (every 90 days recommended)
4. Monitor access logs regularly
5. Keep system updated with security patches

## Troubleshooting

### Service Not Starting
```bash
ssh root@72.60.220.188 "cd /root/supabase/docker && docker compose logs <service_name>"
```

### SSL Certificate Issues
```bash
ssh root@72.60.220.188 "certbot renew --dry-run"
```

### Database Connection Issues
```bash
ssh root@72.60.220.188 "docker exec -it supabase-db psql -U postgres"
```

---

**Last Updated**: 2025-10-28
**Setup By**: Claude Code Assistant
