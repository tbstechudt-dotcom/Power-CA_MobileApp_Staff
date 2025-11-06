# SSH Connection Guide for Windows

## VPS Connection Details
- **IP Address**: 72.60.220.188
- **Username**: root
- **Domain**: api.pcamobile.cloud (srv1087534.hstgr.cloud)

---

## Method 1: Using Windows Terminal / PowerShell (Recommended)

Windows 10/11 has built-in OpenSSH client.

### Step 1: Open Terminal
1. Press `Win + X` and select "Windows Terminal" or "PowerShell"
2. Or search for "PowerShell" in Start menu

### Step 2: Connect via SSH
```powershell
ssh root@72.60.220.188
```

### Step 3: Enter Password
- When prompted, type your root password
- **Note**: You won't see the password as you type (security feature)
- Press Enter

### Expected Output:
```
The authenticity of host '72.60.220.188' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '72.60.220.188' (ED25519) to the list of known hosts.
root@72.60.220.188's password:
```

### Step 4: Verify Connection
Once connected, you should see:
```
root@srv1087534:~#
```

---

## Method 2: Using PuTTY (Alternative)

If you prefer a GUI application:

### Step 1: Download PuTTY
- Visit: https://www.putty.org/
- Download and install PuTTY

### Step 2: Configure Connection
1. Open PuTTY
2. In "Host Name (or IP address)" field, enter: `72.60.220.188`
3. Port: `22`
4. Connection type: `SSH`
5. Click "Open"

### Step 3: Login
1. When terminal appears, login as: `root`
2. Enter password when prompted

---

## Method 3: Using VS Code (Integrated Development)

Great for editing files directly on the VPS!

### Step 1: Install Extension
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Remote - SSH"
4. Install the extension by Microsoft

### Step 2: Connect
1. Press `F1` or `Ctrl+Shift+P`
2. Type "Remote-SSH: Connect to Host"
3. Enter: `root@72.60.220.188`
4. Enter password when prompted

### Step 3: Work Remotely
- Now you can edit files on the VPS directly in VS Code!
- Open folder: `/root/supabase/docker`

---

## Method 4: Using Hostinger's Web Terminal

Hostinger provides a web-based terminal in their control panel.

### Steps:
1. Login to Hostinger VPS Panel
2. Navigate to your VPS
3. Click "Terminal" or "SSH Access" button
4. This opens a web-based terminal already logged in

---

## Troubleshooting

### Issue 1: "Connection refused"
**Solution:**
- Check if VPS is running in Hostinger panel
- Verify IP address: `72.60.220.188`
- Check if port 22 is blocked by your firewall

### Issue 2: "Permission denied"
**Solution:**
- Verify you're using the correct root password
- Reset password through Hostinger panel if needed

### Issue 3: "Host key verification failed"
**Solution:**
```powershell
# Remove old host key
ssh-keygen -R 72.60.220.188

# Try connecting again
ssh root@72.60.220.188
```

### Issue 4: "Connection timeout"
**Solution:**
- Check your internet connection
- Check if your office/network firewall blocks SSH (port 22)
- Try from a different network (mobile hotspot)

---

## Recommended Workflow for Setup

### Option A: Direct Terminal (Fastest)
1. Open PowerShell
2. Connect: `ssh root@72.60.220.188`
3. Copy/paste commands from SETUP-GUIDE.md

### Option B: VS Code Remote (Best for Editing)
1. Connect via Remote-SSH
2. Edit files directly: `/root/supabase/docker/.env`
3. Use integrated terminal for commands

### Option C: Use Complete Setup Script
1. Connect via any method
2. Upload complete-setup.sh to VPS
3. Run: `bash /tmp/complete-setup.sh`

---

## Quick Reference Commands

### After Connecting:

```bash
# Check current directory
pwd

# View Supabase secrets
cat /root/supabase-secrets.txt

# Navigate to Supabase directory
cd /root/supabase/docker

# View current configuration
cat .env | head -20

# Check Docker containers
docker compose ps

# View logs
docker compose logs --tail=100

# Check system resources
htop  # or: top
```

---

## Security Best Practices

### 1. Change Root Password (After Setup)
```bash
passwd
```

### 2. Create SSH Key for Passwordless Login (Optional)

**On Your Windows Machine:**
```powershell
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key to VPS
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@72.60.220.188 "cat >> ~/.ssh/authorized_keys"
```

**Now you can connect without password:**
```powershell
ssh root@72.60.220.188
```

### 3. Disable Password Login (After Setting Up Key)
```bash
# Edit SSH config
nano /etc/ssh/sshd_config

# Change this line:
PasswordAuthentication no

# Restart SSH
systemctl restart sshd
```

---

## File Transfer (if needed)

### Using SCP (Secure Copy)

**From Windows to VPS:**
```powershell
scp C:\path\to\file.txt root@72.60.220.188:/root/
```

**From VPS to Windows:**
```powershell
scp root@72.60.220.188:/root/file.txt C:\path\to\destination\
```

### Using SFTP (FileZilla, WinSCP)

1. Download FileZilla or WinSCP
2. Connect with:
   - Host: `72.60.220.188`
   - Username: `root`
   - Password: (your password)
   - Port: `22`
   - Protocol: `SFTP`

---

## Next Steps After Connecting

1. **View your generated secrets:**
   ```bash
   cat /root/supabase-secrets.txt
   ```

2. **Run the complete setup script:**
   ```bash
   # Copy the complete-setup.sh content to VPS
   # Then run:
   bash /tmp/complete-setup.sh
   ```

3. **Or follow manual setup:**
   - Follow [SETUP-GUIDE.md](./SETUP-GUIDE.md) step by step

---

## Getting Help

If you encounter any issues:
1. Check the error message carefully
2. Try the troubleshooting steps above
3. Verify VPS status in Hostinger panel
4. Check [SETUP-GUIDE.md](./SETUP-GUIDE.md) for detailed instructions

**Common First Command to Run:**
```bash
# This shows you're connected and where you are
pwd && ls -la && cat /root/supabase-secrets.txt
```

---

**Created**: 2025-10-28
**VPS**: Hostinger srv1087534.hstgr.cloud
**IP**: 72.60.220.188
