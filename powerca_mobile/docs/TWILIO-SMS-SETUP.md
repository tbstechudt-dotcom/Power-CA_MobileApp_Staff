# Twilio SMS OTP Setup Guide

This guide explains how to configure Twilio SMS for real-time OTP verification in the PowerCA Mobile Staff app.

## Prerequisites

1. Twilio Account (https://www.twilio.com)
2. Supabase Project with Edge Functions enabled
3. Supabase CLI installed

## Step 1: Get Twilio Credentials

1. Log in to your Twilio Console: https://console.twilio.com
2. From the dashboard, note down:
   - **Account SID**: Found on the main dashboard
   - **Auth Token**: Click "Show" to reveal (keep this secret!)
3. Get or purchase a phone number:
   - Go to Phone Numbers > Manage > Active Numbers
   - If none, buy a number with SMS capability
   - Note down the phone number (e.g., +1234567890)

## Step 2: Set Supabase Edge Function Secrets

Run these commands to set the Twilio credentials as secrets:

```bash
# Navigate to your Supabase project directory
cd powerca_mobile/supabase

# Set Twilio Account SID
npx supabase secrets set TWILIO_ACCOUNT_SID=your_account_sid_here

# Set Twilio Auth Token
npx supabase secrets set TWILIO_AUTH_TOKEN=your_auth_token_here

# Set Twilio Phone Number (with country code, e.g., +1234567890)
npx supabase secrets set TWILIO_PHONE_NUMBER=+1234567890
```

## Step 3: Deploy Edge Functions

Deploy both OTP Edge Functions to Supabase:

```bash
# Deploy send-otp-sms function
npx supabase functions deploy send-otp-sms

# Deploy verify-otp-sms function
npx supabase functions deploy verify-otp-sms
```

## Step 4: Test the Functions

### Test Send OTP

```bash
curl -X POST "https://jacqfogzgzvbjeizljqf.supabase.co/functions/v1/send-otp-sms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "phone": "0412345678",
    "device_fingerprint": "test-device-123",
    "device_name": "Test Device",
    "device_model": "Test Model",
    "platform": "android"
  }'
```

Expected response:
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "phone_masked": "****5678",
  "expires_in_seconds": 300
}
```

### Test Verify OTP

```bash
curl -X POST "https://jacqfogzgzvbjeizljqf.supabase.co/functions/v1/verify-otp-sms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "phone": "0412345678",
    "device_fingerprint": "test-device-123",
    "otp": "123456"
  }'
```

## Database Tables Required

Ensure these tables exist in your Supabase database:

### staff_devices
```sql
CREATE TABLE IF NOT EXISTS staff_devices (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    staff_id NUMERIC(8) NOT NULL,
    device_fingerprint VARCHAR(64) NOT NULL,
    device_name VARCHAR(100),
    device_model VARCHAR(100),
    platform VARCHAR(20),
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(staff_id, device_fingerprint)
);
```

### device_otp_requests
```sql
CREATE TABLE IF NOT EXISTS device_otp_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    staff_id NUMERIC(8),
    device_fingerprint VARCHAR(64) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 5,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Twilio Pricing

- SMS messages typically cost $0.0075 - $0.02 per message (varies by country)
- Consider setting up rate limiting to prevent abuse
- Current rate limit: 3 OTPs per phone per hour

## Troubleshooting

### "Phone number not registered"
- Ensure the phone number exists in `mbstaff.phonumber` column
- Check phone format matches (with or without country code)

### "Rate limit exceeded"
- Wait 1 hour before requesting new OTP
- Or clear old records from `device_otp_requests` table

### "Twilio API error"
- Verify credentials are correct in Supabase secrets
- Check Twilio console for error logs
- Ensure phone number is SMS-capable

### SMS not received
- Check spam/blocked messages on phone
- Verify Twilio has SMS capability in target country
- Check Twilio logs for delivery status

## Security Considerations

1. **OTP Expiry**: OTPs expire after 5 minutes
2. **Attempt Limit**: Max 5 verification attempts per OTP
3. **Rate Limiting**: Max 3 OTPs per phone per hour
4. **Device Binding**: OTP is tied to specific device fingerprint
5. **One-time Use**: OTP is marked verified after successful use

## Edge Function Logs

View logs for debugging:

```bash
# View send-otp-sms logs
npx supabase functions logs send-otp-sms

# View verify-otp-sms logs
npx supabase functions logs verify-otp-sms
```

## Alternative: Development Mode

For testing without Twilio (not for production):
- The Edge Functions will fail if Twilio secrets are not set
- Use the RPC functions (`send_otp_with_phone`, `verify_otp_with_phone`) for dev testing
- Dev OTP is stored in `device_otp_requests.otp_code` column
