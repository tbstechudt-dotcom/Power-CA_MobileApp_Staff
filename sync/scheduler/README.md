# PowerCA Sync Scheduler - Automated Multi-Client Sync

Automated sync scheduler that runs syncs for all 6 clients on schedule.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Run the setup script (Windows)
setup.bat

# Or manually install
npm install node-cron winston nodemailer node-windows
```

### 2. Configure Clients

Edit `clients-config.js` to configure your 6 clients:

```javascript
{
  id: 1,
  name: 'Client 1',
  org_id: 1,
  enabled: true,
  schedule: {
    incremental: '0 2 * * *',    // Daily at 2:00 AM
    full: '0 3 * * 0'             // Sunday at 3:00 AM
  }
}
```

### 3. Test the Scheduler

```bash
# Test run (won't install as service)
node sync-scheduler.js
```

Press Ctrl+C to stop.

### 4. Install as Windows Service

**Option A: Using batch file (Recommended)**
```bash
# Right-click and "Run as administrator"
install-service.bat
```

**Option B: Manual installation**
```bash
# Install service (run as administrator)
node install-service.js install

# Configure auto-start
sc config "PowerCA Sync Scheduler" start=auto

# Start the service
node install-service.js start
```

---

## 📅 Default Schedule

| Client | Org ID | Daily Incremental | Weekly Full |
|--------|--------|------------------|-------------|
| Client 1 | 1 | 2:00 AM | Sun 3:00 AM |
| Client 2 | 2 | 2:15 AM | Sun 3:30 AM |
| Client 3 | 3 | 2:30 AM | Sun 4:00 AM |
| Client 4 | 4 | 2:45 AM | Sun 4:30 AM |
| Client 5 | 5 | 3:00 AM | Sun 5:00 AM |
| Client 6 | 6 | 3:15 AM | Sun 5:30 AM |

**Total time:** Staggered over 1.5 hours to avoid server overload

---

## 🔧 Configuration

### Sync Schedule (Cron Format)

```
* * * * *
│ │ │ │ │
│ │ │ │ └─ Day of week (0-7) (Sunday=0 or 7)
│ │ │ └─── Month (1-12)
│ │ └───── Day of month (1-31)
│ └─────── Hour (0-23)
└───────── Minute (0-59)
```

**Examples:**
- `0 2 * * *` - Every day at 2:00 AM
- `30 2 * * *` - Every day at 2:30 AM
- `0 3 * * 0` - Every Sunday at 3:00 AM
- `0 */6 * * *` - Every 6 hours

### Email Notifications

Enable email alerts in `clients-config.js`:

```javascript
emailNotifications: {
  enabled: true,
  onFailure: true,     // Send email when sync fails
  onSuccess: false,    // Send email when sync succeeds
  recipients: ['admin@example.com', 'backup@example.com']
}
```

Configure email settings:

```javascript
email: {
  service: 'gmail',
  auth: {
    user: 'your-email@gmail.com',
    pass: 'your-app-password'  // Use Gmail App Password
  }
}
```

**Note:** For Gmail, you need to create an [App Password](https://support.google.com/accounts/answer/185833):
1. Go to Google Account settings
2. Security → 2-Step Verification → App passwords
3. Generate password for "Mail"
4. Use that password in config

---

## 📊 Monitoring

### View Logs

```bash
# View combined logs
type logs\combined.log

# View errors only
type logs\error.log

# Live tail (using PowerShell)
Get-Content logs\combined.log -Wait -Tail 50
```

### Check Service Status

```bash
# Check if service is running
sc query "PowerCA Sync Scheduler"

# View service configuration
sc qc "PowerCA Sync Scheduler"
```

### Log Files

| File | Contents |
|------|----------|
| `logs/combined.log` | All logs (info, warnings, errors) |
| `logs/error.log` | Errors only |

Logs are automatically rotated and kept for 30 days (configurable).

---

## 🛠️ Service Management

### Install Service
```bash
node install-service.js install
```

### Start Service
```bash
node install-service.js start
# or
net start "PowerCA Sync Scheduler"
```

### Stop Service
```bash
node install-service.js stop
# or
net stop "PowerCA Sync Scheduler"
```

### Restart Service
```bash
node install-service.js restart
```

### Uninstall Service
```bash
node install-service.js uninstall
```

### Configure Auto-Start
```bash
# Start automatically on boot
sc config "PowerCA Sync Scheduler" start=auto

# Start manually
sc config "PowerCA Sync Scheduler" start=demand

# Disable
sc config "PowerCA Sync Scheduler" start=disabled
```

---

## 🐛 Troubleshooting

### Service Won't Start

1. **Check logs:**
   ```bash
   type logs\error.log
   ```

2. **Verify Node.js is in PATH:**
   ```bash
   node --version
   ```

3. **Run scheduler manually to see errors:**
   ```bash
   node sync-scheduler.js
   ```

4. **Reinstall service:**
   ```bash
   node install-service.js uninstall
   node install-service.js install
   ```

### Sync Failures

1. **Check network connectivity:**
   - Desktop PostgreSQL accessible?
   - Supabase reachable?

2. **Verify credentials in `.env` file**

3. **Check sync timeout** (increase in `clients-config.js`):
   ```javascript
   syncTimeout: 1200000  // 20 minutes
   ```

4. **Manual test sync:**
   ```bash
   cd ..\..
   node sync/full-sync.js --mode=incremental --org-id=1
   ```

### Email Notifications Not Working

1. **Verify email configuration** in `clients-config.js`
2. **Use Gmail App Password** (not regular password)
3. **Check email logs** in `logs/combined.log`
4. **Test email manually:**
   ```javascript
   const nodemailer = require('nodemailer');
   const config = require('./clients-config');
   const transporter = nodemailer.createTransporter(config.email);
   transporter.sendMail({
     from: config.email.from,
     to: 'test@example.com',
     subject: 'Test',
     text: 'Test email'
   });
   ```

---

## 📝 Advanced Configuration

### Disable Specific Client

In `clients-config.js`:

```javascript
{
  id: 3,
  name: 'Client 3',
  org_id: 3,
  enabled: false,  // Disable syncs for this client
  ...
}
```

### Change Timezone

In `sync-scheduler.js`, change:

```javascript
cron.schedule('0 2 * * *', async () => {
  // ...
}, {
  timezone: 'America/New_York'  // Your timezone
});
```

[List of timezones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

### Retry Configuration

In `clients-config.js`:

```javascript
settings: {
  retryOnFailure: true,
  maxRetries: 5,           // Retry 5 times
  retryDelay: 600000,      // Wait 10 minutes between retries
}
```

---

## 📚 Additional Resources

- [Sync Workflow Guide](../../SYNC-WORKFLOW.md)
- [Node-Cron Documentation](https://www.npmjs.com/package/node-cron)
- [Node-Windows Documentation](https://www.npmjs.com/package/node-windows)
- [Winston Logger Documentation](https://www.npmjs.com/package/winston)

---

## 🆘 Support

If you encounter issues:

1. Check logs: `logs/error.log`
2. Review this README
3. Test sync manually: `node ../full-sync.js --mode=incremental`
4. Check Windows Event Viewer (Application logs)

---

**Last Updated:** 2025-11-26
**Version:** 1.0
