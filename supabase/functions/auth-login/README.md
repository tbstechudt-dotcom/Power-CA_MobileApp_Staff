# PowerCA Mobile - Auth Login Edge Function

## Overview

This Supabase Edge Function handles authentication for PowerCA Mobile with **server-side password decryption**. The encryption key never leaves the backend, ensuring maximum security.

## Security Architecture

```
Mobile App  →  Edge Function  →  Database
  (username/password)    ↓          (encrypted passwords)
                    Decrypt with
                    secure key
                         ↓
                    Verify & Return
```

### Key Benefits

✅ **Encryption key stays on server only**
✅ **Matches desktop PowerBuilder encryption (AES-CBC)**
✅ **Can rotate keys without app updates**
✅ **Centralized security control**

---

## Deployment Instructions

### Step 1: Install Supabase CLI

```bash
npm install -g supabase
```

### Step 2: Link to Your Supabase Project

```bash
cd "d:\PowerCA Mobile\powerca_mobile"
supabase login
supabase link --project-ref jacqfogzgzvbjeizljqf
```

### Step 3: Set Encryption Key Secret

**CRITICAL:** Set the encryption key as a secret environment variable:

```bash
supabase secrets set ENCRYPTION_KEY=PCASVR-29POWERCA
```

**Verify it was set:**

```bash
supabase secrets list
```

### Step 4: Deploy the Function

```bash
supabase functions deploy auth-login
```

### Step 5: Verify Deployment

Test the function with curl:

```bash
curl --request POST \
  --url 'https://jacqfogzgzvbjeizljqf.supabase.co/functions/v1/auth-login' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "username": "MM",
    "password": "your_test_password"
  }'
```

**Expected successful response:**

```json
{
  "success": true,
  "staff": {
    "staff_id": 2,
    "name": "MUTHAMMAL M",
    "app_username": "MM",
    "org_id": 1,
    "loc_id": 1,
    "con_id": 0,
    "email": null,
    "phonumber": null,
    "dob": null,
    "stafftype": null,
    "active_status": 0
  },
  "message": "Welcome, MUTHAMMAL M!"
}
```

**Expected error responses:**

```json
// Invalid credentials
{
  "error": "Invalid username or password"
}

// Inactive user
{
  "error": "User account is inactive"
}
```

---

## How It Works

### 1. Request Flow

```typescript
POST /functions/v1/auth-login
{
  "username": "MM",
  "password": "plaintext_password"
}
```

### 2. Backend Processing

1. **Receive credentials** from mobile app
2. **Fetch encryption key** from environment variable (`ENCRYPTION_KEY`)
3. **Query mbstaff table** for user with matching username
4. **Decrypt password** on server using AES-CBC
5. **Verify password** matches user input
6. **Check active status** (0 or 1 = active)
7. **Return staff data** (without password)

### 3. Password Decryption (Server-Side)

The function uses Web Crypto API to decrypt passwords with AES-CBC:

```typescript
// Key preparation (16 bytes for AES-128)
const preparedKey = new Uint8Array(16);
preparedKey.set(keyBytes.slice(0, 16));

// IV preparation (same as key, PowerBuilder compatible)
const preparedIV = new Uint8Array(16);
preparedIV.set(keyBytes.slice(0, 16));

// Decrypt using Web Crypto API
const cryptoKey = await crypto.subtle.importKey(
  'raw',
  preparedKey,
  { name: 'AES-CBC' },
  false,
  ['decrypt']
);

const decryptedBuffer = await crypto.subtle.decrypt(
  { name: 'AES-CBC', iv: preparedIV },
  cryptoKey,
  encryptedBytes
);
```

This matches the desktop PowerBuilder implementation:
- Algorithm: AES
- Mode: CBC
- Padding: PKCS7
- Encoding: Base64

---

## Environment Variables

The Edge Function requires these environment variables (automatically provided by Supabase):

| Variable | Description | Set By |
|----------|-------------|--------|
| `ENCRYPTION_KEY` | AES encryption key for password decryption | **You (via secrets)** |
| `SUPABASE_URL` | Your Supabase project URL | Supabase (automatic) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key for database access | Supabase (automatic) |

---

## Troubleshooting

### Error: "ENCRYPTION_KEY environment variable not set!"

**Cause:** The encryption key secret hasn't been configured.

**Solution:**
```bash
supabase secrets set ENCRYPTION_KEY=PCASVR-29POWERCA
supabase functions deploy auth-login
```

### Error: "Invalid username or password" (but credentials are correct)

**Possible causes:**

1. **Wrong encryption key** - Verify key matches desktop database
2. **Password not encrypted** - Check if mbstaff.app_pw is Base64-encoded
3. **Encoding mismatch** - Verify desktop uses same encryption algorithm

**Debug:**
```bash
# Check if password is encrypted
psql -c "SELECT app_username, app_pw FROM mbstaff WHERE app_username = 'MM'"

# Test decryption manually
node scripts/test-encryption.js
```

### Error: "Database error"

**Cause:** Supabase can't access mbstaff table.

**Solution:** Check Row Level Security (RLS) policies - service role should bypass RLS.

---

## Security Best Practices

### ✅ DO:

- Keep encryption key in Supabase secrets (never in code)
- Use HTTPS for all API calls
- Rotate encryption key periodically
- Monitor function logs for suspicious activity
- Set up rate limiting if available

### ❌ DON'T:

- Hardcode encryption key in function code
- Log decrypted passwords
- Return encryption key in responses
- Disable CORS (keep restricted to your domains)

---

## Monitoring & Logs

View function logs in Supabase Dashboard:

```
Dashboard > Edge Functions > auth-login > Logs
```

Or via CLI:

```bash
supabase functions serve auth-login
```

---

## Updating the Function

After making changes:

```bash
# Deploy updated function
supabase functions deploy auth-login

# Verify deployment
supabase functions list
```

---

## Alternative: Fetch Encryption Key from Database

If you prefer to store the key in your database (like desktop):

```typescript
// Query encryption key from database
const { data: keyData } = await supabase
  .from('encryption_config')
  .select('encryption_key')
  .single()

const ENCRYPTION_KEY = keyData.encryption_key
```

Then use this key for decryption instead of environment variable.

---

## Cost Estimate

Supabase Edge Functions pricing (as of 2024):

- **Free tier:** 500K function invocations/month
- **Pro tier:** $25/month for 2M invocations
- **Additional:** $2 per 1M invocations

**Expected usage:**
- ~100 logins/day = 3,000/month (well within free tier)

---

## Support

For issues or questions:

1. Check Supabase Edge Functions docs: https://supabase.com/docs/guides/functions
2. Review function logs in Supabase Dashboard
3. Test locally: `supabase functions serve auth-login`

---

**Last Updated:** 2025-11-01
**Function Version:** 1.0
**Status:** Production-ready
