# Enable IPv6 Connectivity for Supabase

## Problem
Your system doesn't have IPv6 connectivity, but Supabase database only provides IPv6 addresses.

## Solution: Install Cloudflare WARP

### Step 1: Download & Install
1. Go to: https://1.1.1.1/
2. Download "WARP" for Windows
3. Install the application

### Step 2: Connect
1. Open Cloudflare WARP app
2. Click "Connect" button
3. Wait for connection (takes 5-10 seconds)

### Step 3: Update .env Configuration
Once WARP is connected, update your `.env` file to use direct connection:

```env
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=Powerca@2025
```

### Step 4: Test Connection
```bash
cd "d:\PowerCA Mobile"
node sync/runner.js --test
```

## Alternative: Teredo (Built-in Windows IPv6 Tunnel)

If you don't want to install WARP, enable Windows Teredo:

```cmd
netsh interface teredo set state enterpriseclient
netsh interface teredo show state
```

Then test again.

## Verify IPv6 Works

After enabling IPv6, verify:

```cmd
ping -6 db.jacqfogzgzvbjeizljqf.supabase.co
```

Should show successful pings.
