// Supabase Edge Function: send-otp-sms
// Sends OTP via BulkSMSGateway.in (primary) with BhashSMS as fallback.
// Falls back automatically when the primary provider is unreachable
// or returns a non-success response.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SendOtpRequest {
  phone: string
  device_fingerprint: string
  device_name: string
  device_model: string
  platform: string
  staff_id?: number  // Optional: If provided, validates phone belongs to this staff
}

// mbstaff.phonumber is synced from the desktop app and can carry stray
// whitespace / CR-LF (e.g. "9080834476\r\n"), so an exact match misses it.
// Match on the last 10 digits instead; prefer preferStaffId when several
// rows share the number.
// deno-lint-ignore no-explicit-any
async function findStaffByPhone(supabase: any, phone: string, preferStaffId?: number) {
  const digits = (phone ?? '').replace(/\D/g, '').slice(-10)
  if (digits.length !== 10) return null
  const { data, error } = await supabase
    .from('mbstaff')
    .select('staff_id, phonumber, name')
    .like('phonumber', `%${digits}%`)
  if (error || !data) return null
  // deno-lint-ignore no-explicit-any
  const matches = data.filter((r: any) =>
    String(r.phonumber ?? '').replace(/\D/g, '').slice(-10) === digits)
  if (matches.length === 0) return null
  // deno-lint-ignore no-explicit-any
  return matches.find((r: any) => preferStaffId && r.staff_id === preferStaffId) ?? matches[0]
}

// Generate 6-digit OTP
function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

// Mask phone number for display
function maskPhone(phone: string): string {
  if (phone.length <= 4) return '****'
  return '****' + phone.slice(-4)
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    // BulkSMSGateway credentials (primary provider)
    const SMS_USER = Deno.env.get('BULKSMS_USER') ?? ''
    const SMS_PASSWORD = Deno.env.get('BULKSMS_PASSWORD') ?? ''
    const SMS_SENDER = Deno.env.get('BULKSMS_SENDER') || 'TBSTEC'
    const SMS_TEMPLATE_ID = Deno.env.get('BULKSMS_TEMPLATE_ID') || '1407161157481665461'

    // BhashSMS credentials (fallback provider — used when BulkSMSGateway fails)
    const BHASHSMS_USER = Deno.env.get('BHASHSMS_USER') ?? ''
    const BHASHSMS_PASS = Deno.env.get('BHASHSMS_PASS') ?? ''
    const BHASHSMS_SENDER = Deno.env.get('BHASHSMS_SENDER') || 'TBSTEC'
    const BHASHSMS_PRIORITY = Deno.env.get('BHASHSMS_PRIORITY') || 'ndnd'
    const BHASHSMS_STYPE = Deno.env.get('BHASHSMS_STYPE') || 'normal'

    // Parse request body
    const { phone, device_fingerprint, device_name, device_model, platform, staff_id }: SendOtpRequest = await req.json()

    if (!phone || !device_fingerprint) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'INVALID_REQUEST',
          message: 'Phone and device fingerprint are required.'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

    // Check if phone number exists in mbstaff
    const staffData = await findStaffByPhone(supabase, phone, staff_id)

    if (!staffData) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'PHONE_NOT_FOUND',
          message: 'Phone number not registered in the Power CA app.'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // IMPORTANT: Validate phone belongs to logged-in staff
    // If staff_id is provided, the phone MUST belong to that staff
    if (staff_id && staffData.staff_id !== staff_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'PHONE_MISMATCH',
          message: 'This phone number is not registered to your account. Please enter your registered phone number.'
        }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const staffId = staffData.staff_id

    // Check rate limiting (max 3 OTPs per hour)
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count } = await supabase
      .from('device_otp_requests')
      .select('*', { count: 'exact', head: true })
      .eq('phone_number', phone)
      .gte('created_at', oneHourAgo)

    if (count && count >= 3) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'RATE_LIMIT',
          message: 'Too many OTP requests. Please try again later.'
        }),
        {
          status: 429,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Generate OTP
    const otp = generateOTP()
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000) // 5 minutes

    // Register/update device
    await supabase
      .from('staff_devices')
      .upsert({
        staff_id: staffId,
        device_fingerprint: device_fingerprint,
        device_name: device_name || 'Unknown Device',
        device_model: device_model || 'Unknown Model',
        platform: platform || 'unknown',
        is_verified: false,
        updated_at: new Date().toISOString()
      }, {
        onConflict: 'staff_id,device_fingerprint'
      })

    // Store OTP request
    await supabase
      .from('device_otp_requests')
      .insert({
        staff_id: staffId,
        device_fingerprint: device_fingerprint,
        phone_number: phone,
        otp_code: otp,
        expires_at: expiresAt.toISOString(),
        attempts: 0,
        max_attempts: 5,
        verified: false
      })

    // Send SMS — try BulkSMSGateway first, fall back to BhashSMS if it fails.
    const message = `Thanks for Choosing Power CA. OTP for Login User Account creation is: ${otp}.`
    const encodedMessage = encodeURIComponent(message)

    // Both providers return free-form text rather than a structured status,
    // so we use a heuristic: a response is treated as a successful delivery
    // unless it contains an explicit failure keyword. This catches BhashSMS
    // responses that are just bare numeric message IDs (e.g. "1701234567")
    // which don't contain any of the obvious "success" words.
    const looksDelivered = (responseText: string): boolean => {
      const t = responseText.trim().toLowerCase()
      if (t.length === 0) return false
      const failurePatterns = [
        'invalid', 'error', 'fail', 'denied', 'refused',
        'expire', 'unauthorized', 'forbidden',
        'insufficient', 'balance', 'credit',
        'not found', 'not registered', 'not approved',
        'template', 'dlt',
        'blocked', 'reject',
      ]
      if (failurePatterns.some(p => t.includes(p))) return false
      // Explicit positive markers also count, in case the failure scan
      // missed something the gateway buries inside a success message.
      return true
    }

    interface ProviderAttempt {
      provider: string
      delivered: boolean
      response: string
    }

    const attempts: ProviderAttempt[] = []

    // === Attempt 1: BulkSMSGateway ===
    const bulkSmsUrl = `http://api.bulksmsgateway.in/sendmessage.php?user=${encodeURIComponent(SMS_USER)}&password=${encodeURIComponent(SMS_PASSWORD)}&mobile=${phone}&message=${encodedMessage}&sender=${SMS_SENDER}&type=3&template_id=${SMS_TEMPLATE_ID}`

    console.log('Attempt 1: Sending SMS via BulkSMSGateway to:', phone)
    try {
      const r = await fetch(bulkSmsUrl, { signal: AbortSignal.timeout(15000) })
      const text = await r.text()
      console.log('BulkSMSGateway response:', text)
      attempts.push({ provider: 'bulksmsgateway', delivered: looksDelivered(text), response: text })
    } catch (e) {
      const msg = (e as Error)?.message ?? 'fetch failed'
      console.error('BulkSMSGateway fetch failed:', msg)
      attempts.push({ provider: 'bulksmsgateway', delivered: false, response: `fetch_failed: ${msg}` })
    }

    // === Attempt 2: BhashSMS fallback (only if primary did not deliver) ===
    if (!attempts[0].delivered) {
      const bhashUrl = `http://bhashsms.com/api/sendmsg.php?user=${encodeURIComponent(BHASHSMS_USER)}&pass=${encodeURIComponent(BHASHSMS_PASS)}&sender=${BHASHSMS_SENDER}&phone=${phone}&text=${encodedMessage}&priority=${BHASHSMS_PRIORITY}&stype=${BHASHSMS_STYPE}`
      console.log('Attempt 2: Falling back to BhashSMS')
      try {
        const r = await fetch(bhashUrl, { signal: AbortSignal.timeout(15000) })
        const text = await r.text()
        console.log('BhashSMS response:', text)
        attempts.push({ provider: 'bhashsms', delivered: looksDelivered(text), response: text })
      } catch (e) {
        const msg = (e as Error)?.message ?? 'fetch failed'
        console.error('BhashSMS fetch failed:', msg)
        attempts.push({ provider: 'bhashsms', delivered: false, response: `fetch_failed: ${msg}` })
      }
    }

    const winner = attempts.find(a => a.delivered)

    if (winner) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'OTP sent successfully',
          phone_masked: maskPhone(phone),
          expires_in_seconds: 300,
          provider: winner.provider
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // All providers failed
    console.error('All SMS providers failed:', attempts)
    return new Response(
      JSON.stringify({
        success: false,
        error: 'SMS_DELIVERY_FAILED',
        message: 'Could not deliver OTP via SMS. Please try again or contact support.',
        provider_responses: attempts
      }),
      {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred. Please try again.'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
