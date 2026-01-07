// Supabase Edge Function: send-otp-sms
// Sends OTP via BulkSMSGateway.in

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

    // BulkSMSGateway credentials
    const SMS_USER = Deno.env.get('BULKSMS_USER') || 'tbsindiaudt@gmail.com'
    const SMS_PASSWORD = Deno.env.get('BULKSMS_PASSWORD') || 'TBSSms@123'
    const SMS_SENDER = Deno.env.get('BULKSMS_SENDER') || 'TBSTEC'
    const SMS_TEMPLATE_ID = Deno.env.get('BULKSMS_TEMPLATE_ID') || '1407161157481665461'

    // Parse request body
    const { phone, device_fingerprint, device_name, device_model, platform }: SendOtpRequest = await req.json()

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
    const { data: staffData, error: staffError } = await supabase
      .from('mbstaff')
      .select('staff_id, phonumber')
      .eq('phonumber', phone)
      .single()

    if (staffError || !staffData) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'PHONE_NOT_FOUND',
          message: 'Phone number not registered in the system.'
        }),
        {
          status: 404,
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

    // Send SMS via BulkSMSGateway
    const message = `Thanks for Choosing Power CA. OTP for Login User Account creation is: ${otp}.`
    const encodedMessage = encodeURIComponent(message)

    const smsUrl = `http://api.bulksmsgateway.in/sendmessage.php?user=${encodeURIComponent(SMS_USER)}&password=${encodeURIComponent(SMS_PASSWORD)}&mobile=${phone}&message=${encodedMessage}&sender=${SMS_SENDER}&type=3&template_id=${SMS_TEMPLATE_ID}`

    console.log('Sending SMS to:', phone)

    const smsResponse = await fetch(smsUrl)
    const smsResult = await smsResponse.text()

    console.log('SMS Gateway Response:', smsResult)

    // Check if SMS was sent successfully
    // BulkSMSGateway typically returns "success" or an error message
    if (smsResult.toLowerCase().includes('success') || smsResult.includes('sent')) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'OTP sent successfully',
          phone_masked: maskPhone(phone),
          expires_in_seconds: 300
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    } else {
      // SMS sending failed, but OTP is stored - return success with warning
      // This allows testing even if SMS fails
      console.error('SMS sending may have failed:', smsResult)
      return new Response(
        JSON.stringify({
          success: true,
          message: 'OTP generated. SMS delivery status: ' + smsResult,
          phone_masked: maskPhone(phone),
          expires_in_seconds: 300,
          // For debugging - remove in production
          debug_otp: otp
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

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
