# PowerCA Mobile - Client Quick Reference Card

## Installation Summary (5 Minutes)

### 1. Install Node.js
```
Download: https://nodejs.org/dist/v18.20.0/node-v18.20.0-x64.msi
Install with defaults -> Verify: node --version
```

### 2. Copy Files
```
Copy folder to: C:\PowerCA-Sync\
```

### 3. Configure
```
Edit: C:\PowerCA-Sync\.env
Set: DESKTOP_DB_PASSWORD=your_password
```

### 4. Install Service (As Admin)
```
cd C:\PowerCA-Sync\sync\scheduler
install-service.bat
Select: 1 (Install) -> 3 (Start)
```

### 5. Verify
```
Open: services.msc
Find: "PowerCA Sync Scheduler"
Status: Running
```

---

## Automatic Sync Schedule

- **Daily:** Incremental sync at 2:00 AM
- **Weekly:** Full sync on Sunday at 3:00 AM

**No manual work needed!**

---

## Common Commands

### Check Service Status
```bash
sc query "PowerCA Sync Scheduler"
```

### Start/Stop Service
```bash
net start "PowerCA Sync Scheduler"
net stop "PowerCA Sync Scheduler"
```

### View Logs
```bash
type C:\PowerCA-Sync\sync\scheduler\logs\combined.log
```

### Manual Sync (Testing)
```bash
cd C:\PowerCA-Sync
node sync\full-sync.js --mode=incremental
```

---

## Troubleshooting (3 Quick Checks)

### 1. Service Won't Start?
```bash
node --version                  # Check Node.js installed
# Test sync manually (see above)
# Check logs: sync\scheduler\logs\error.log
```

### 2. Sync Fails?
```bash
# Check Desktop PostgreSQL is running
# Verify .env password is correct
# Test internet connection
```

### 3. Need to Change Schedule?
```bash
# Edit: sync\scheduler\clients-config.js
# Restart service: install-service.bat (option 5)
```

---

## Key Files & Locations

| What | Where |
|------|-------|
| **Installation** | C:\PowerCA-Sync\ |
| **Configuration** | C:\PowerCA-Sync\.env |
| **Service Installer** | C:\PowerCA-Sync\sync\scheduler\install-service.bat |
| **Logs** | C:\PowerCA-Sync\sync\scheduler\logs\ |
| **Schedule Config** | C:\PowerCA-Sync\sync\scheduler\clients-config.js |

---

## Network Requirements

- [X] Sync PC can connect to Desktop PostgreSQL (local network)
- [X] Sync PC has internet access (HTTPS to Supabase)
- [X] **No inbound ports needed** (firewall stays closed)

---

## Support Contacts

**Email:** support@powerca.com
**Website:** https://powerca.com/support

---

## What's Happening Behind the Scenes?

1. Windows Service runs 24/7 in background
2. At scheduled times, service wakes up
3. Connects to your Desktop PostgreSQL (local)
4. Syncs changes to Supabase Cloud (internet)
5. Mobile apps read from Supabase in real-time
6. Service goes back to sleep until next schedule

**Your desktop data stays on your network - only sync service needs internet access!**

---

**Version:** 1.0
**Last Updated:** 2025-11-28
