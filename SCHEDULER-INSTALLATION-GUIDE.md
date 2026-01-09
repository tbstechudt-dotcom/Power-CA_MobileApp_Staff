# PowerCA Sync Scheduler - Installation Guide

Complete guide to install and configure the automated sync scheduler for 6 clients.

---

## 📋 Prerequisites

- ✅ Windows Server or Windows 10/11
- ✅ Node.js installed (v14 or higher)
- ✅ Administrator access to install Windows Service
- ✅ Desktop PostgreSQL running (port 5433)
- ✅ Supabase connection configured in `.env`

---

## 🚀 Installation Steps

### Step 1: Install Dependencies

**Option A: Automated (Recommended)**
```bash
cd sync/scheduler
setup.bat
```

**Option B: Manual**
```bash
npm install node-cron winston nodemailer node-windows --save
```

---

### Step 2: Configure Clients

Edit `sync/scheduler/clients-config.js`:

```javascript
{
  id: 1,
  name: 'Client 1',
  org_id: 1,           // ← Your client's org_id
  enabled: true,        // ← Set to false to disable
  schedule: {
    incremental: '0 2 * * *',    // Daily at 2:00 AM
    full: '0 3 * * 0'             // Sunday at 3:00 AM
  }
}
```

**Configure all 6 clients** with their respective `org_id` values.

---

### Step 3: Test Configuration

```bash
cd sync/scheduler
node test-scheduler.js
```

Expected output:
```
✅ Configuration is valid! The scheduler is ready to run.
```

---

### Step 4: Test Manual Run (Optional but Recommended)

```bash
node sync-scheduler.js
```

This will:
- ✅ Start the scheduler
- ✅ Show scheduled times for all clients
- ✅ Wait for cron triggers (press Ctrl+C to stop)

**Note:** This is just a test. For production, install as a service (next step).

---

### Step 5: Install as Windows Service

**🔐 IMPORTANT: Run as Administrator!**

Right-click **Command Prompt** → **Run as administrator**

**Option A: Using Batch File (Easiest)**
```bash
cd sync/scheduler
install-service.bat
```

Then select option `1` (Install service)

**Option B: Manual**
```bash
cd sync/scheduler
node install-service.js install
```

---

### Step 6: Configure Auto-Start

```bash
sc config "PowerCA Sync Scheduler" start=auto
```

This ensures the service starts automatically when the server reboots.

---

### Step 7: Start the Service

**Option A: Using Batch File**
```bash
install-service.bat
```
Select option `3` (Start service)

**Option B: Manual**
```bash
node install-service.js start
```

**Option C: Windows Services**
```bash
services.msc
```
Find "PowerCA Sync Scheduler" → Right-click → Start

---

### Step 8: Verify Service is Running

```bash
sc query "PowerCA Sync Scheduler"
```

Expected output:
```
STATE              : 4  RUNNING
```

---

## 📅 Default Sync Schedule

| Client | Org ID | Daily Incremental | Weekly Full | Duration |
|--------|--------|------------------|-------------|----------|
| Client 1 | 1 | 2:00 AM | Sun 3:00 AM | ~40-60s |
| Client 2 | 2 | 2:15 AM | Sun 3:30 AM | ~40-60s |
| Client 3 | 3 | 2:30 AM | Sun 4:00 AM | ~40-60s |
| Client 4 | 4 | 2:45 AM | Sun 4:30 AM | ~40-60s |
| Client 5 | 5 | 3:00 AM | Sun 5:00 AM | ~40-60s |
| Client 6 | 6 | 3:15 AM | Sun 5:30 AM | ~40-60s |

**Total daily duration:** ~6-10 minutes (staggered over 1.5 hours)

---

## 📊 Monitoring

### Check Logs

```bash
# View all logs
type sync\scheduler\logs\combined.log

# View errors only
type sync\scheduler\logs\error.log

# Live monitoring (PowerShell)
Get-Content sync\scheduler\logs\combined.log -Wait -Tail 50
```

### Log File Locations

```
sync/scheduler/logs/
├── combined.log    ← All logs (info, warnings, errors)
└── error.log       ← Errors only
```

### Example Log Output

```
[2025-11-28 02:00:00] info: [CRON] Triggered incremental sync for Client 1
[2025-11-28 02:00:00] info: [Client 1: Client 1] Starting incremental sync (org_id=1)
[2025-11-28 02:00:45] info: [Client 1: Client 1] Sync completed successfully in 45.23s
```

---

## 🔧 Service Management Commands

### Check Service Status
```bash
sc query "PowerCA Sync Scheduler"
```

### Start Service
```bash
net start "PowerCA Sync Scheduler"
```

### Stop Service
```bash
net stop "PowerCA Sync Scheduler"
```

### Restart Service
```bash
node sync/scheduler/install-service.js restart
```

### Uninstall Service
```bash
node sync/scheduler/install-service.js uninstall
```

### View Service Configuration
```bash
sc qc "PowerCA Sync Scheduler"
```

---

## 📧 Email Notifications (Optional)

### Enable Email Alerts

Edit `sync/scheduler/clients-config.js`:

```javascript
settings: {
  emailNotifications: {
    enabled: true,                        // ← Enable notifications
    onFailure: true,                      // Send email on sync failures
    onSuccess: false,                     // Don't send on success (too many)
    recipients: ['admin@example.com']     // Add your email
  }
},

email: {
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password'             // ← Gmail App Password
  },
  from: 'PowerCA Sync <noreply@powerca.com>'
}
```

### Get Gmail App Password

1. Go to https://myaccount.google.com/security
2. Enable **2-Step Verification**
3. Go to **App passwords**
4. Create password for "Mail"
5. Copy the 16-character password
6. Use in `clients-config.js`

**⚠️ Never use your regular Gmail password!**

---

## 🐛 Troubleshooting

### Service Won't Start

**Solution 1: Check Logs**
```bash
type sync\scheduler\logs\error.log
```

**Solution 2: Run Manually to See Errors**
```bash
cd sync\scheduler
node sync-scheduler.js
```

**Solution 3: Verify Node.js Path**
```bash
node --version
```
If not found, reinstall Node.js and ensure it's in PATH.

**Solution 4: Reinstall Service**
```bash
node install-service.js uninstall
node install-service.js install
```

---

### Sync Failures

**Check Desktop Database Connection**
```bash
psql -h localhost -p 5433 -U postgres -d enterprise_db -c "SELECT 1"
```

**Check Supabase Connection**
```bash
node -e "require('dotenv').config(); console.log(process.env.SUPABASE_DB_HOST)"
```

**Test Manual Sync**
```bash
node sync/full-sync.js --mode=incremental --org-id=1
```

**Increase Timeout** (in `clients-config.js`):
```javascript
syncTimeout: 1200000  // 20 minutes instead of 10
```

---

### Logs Not Appearing

**Create logs directory manually:**
```bash
cd sync\scheduler
mkdir logs
```

**Check file permissions:**
- Service needs write access to `sync/scheduler/logs/`

---

### Service Crashes After Reboot

**Solution: Configure recovery options**
```bash
sc failure "PowerCA Sync Scheduler" reset=86400 actions=restart/60000/restart/60000/restart/60000
```

This will automatically restart the service if it crashes.

---

## 🎯 Production Checklist

Before going live:

- [ ] Configured all 6 clients in `clients-config.js`
- [ ] Tested configuration: `node test-scheduler.js`
- [ ] Tested manual run: `node sync-scheduler.js`
- [ ] Installed as Windows Service
- [ ] Configured auto-start on boot
- [ ] Verified service is running: `sc query "PowerCA Sync Scheduler"`
- [ ] Checked logs are being created: `sync/scheduler/logs/`
- [ ] (Optional) Configured email notifications
- [ ] (Optional) Configured service recovery on failure
- [ ] Documented sync schedule for team

---

## 📚 Additional Resources

- [Scheduler README](sync/scheduler/README.md) - Detailed documentation
- [Sync Workflow Guide](SYNC-WORKFLOW.md) - Complete sync process
- [Clients Configuration](sync/scheduler/clients-config.js) - Configuration file

---

## 🆘 Support

**If you encounter issues:**

1. **Check logs first:**
   ```bash
   type sync\scheduler\logs\error.log
   ```

2. **Test manually:**
   ```bash
   node sync/full-sync.js --mode=incremental --org-id=1
   ```

3. **Review this guide**

4. **Check Windows Event Viewer:**
   - Application logs for service errors

---

## 🎉 Success!

If you've completed all steps, your automated sync scheduler is now running! 🚀

**What happens now:**
- ✅ Syncs run automatically on schedule
- ✅ All 6 clients sync without manual intervention
- ✅ Logs are created for monitoring
- ✅ Service restarts automatically if it crashes
- ✅ Service starts automatically on server reboot

**You're done!** The system is now fully automated. 🎊

---

**Last Updated:** 2025-11-26
**Version:** 1.0
