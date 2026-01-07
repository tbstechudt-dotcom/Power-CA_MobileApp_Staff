// Supabase Edge Function: verify-otp-sms
// Verifies OTP and marks device as verified

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VerifyOtpRequest {
  phone: string
  device_fingerprint: string
  otp: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    // Parse request body
    const { phone, device_fingerprint, otp }: VerifyOtpRequest = await req.json()

    if (!phone || !device_fingerprint || !otp) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'INVALID_REQUEST',
          message: 'Phone, device fingerprint, and OTP are required.'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

    // Find staff by phone number (including name for response)
    const { data: staffData, error: staffError } = await supabase
      .from('mbstaff')
      .select('staff_id, name')
      .eq('phonumber', phone)
      .single()

    if (staffError || !staffData) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'PHONE_NOT_FOUND',
          message: 'Phone number not registered.'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const staffId = staffData.staff_id
    const staffName = staffData.name

    // Find the most recent unexpired, unverified OTP
    const { data: otpRecord, error: otpError } = await supabase
      .from('device_otp_requests')
      .select('*')
      .eq('phone_number', phone)
      .eq('device_fingerprint', device_fingerprint)
      .eq('verified', false)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    if (otpError || !otpRecord) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'OTP_EXPIRED',
          message: 'OTP has expired. Please request a new one.'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check attempt limit
    if (otpRecord.attempts >= otpRecord.max_attempts) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'MAX_ATTEMPTS',
          message: 'Maximum verification attempts exceeded. Please request a new OTP.'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Increment attempt count
    await supabase
      .from('device_otp_requests')
      .update({ attempts: otpRecord.attempts + 1 })
      .eq('id', otpRecord.id)

    // Verify OTP
    if (otpRecord.otp_code !== otp) {
      const attemptsRemaining = otpRecord.max_attempts - otpRecord.attempts - 1
      return new Response(
        JSON.stringify({
          success: false,
          error: 'INVALID_OTP',
          message: 'Invalid OTP. Please try again.',
          attempts_remaining: attemptsRemaining
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // OTP is valid - mark as verified
    await supabase
      .from('device_otp_requests')
      .update({ verified: true })
      .eq('id', otpRecord.id)

    // Mark device as verified
    const { data: deviceData } = await supabase
      .from('staff_devices')
      .update({
        is_verified: true,
        verified_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('staff_id', staffId)
      .eq('device_fingerprint', device_fingerprint)
      .select('id')
      .single()

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Device verified successfully',
        device_id: deviceData?.id,
        staff_id: staffId,
        staff_name: staffName
      }),
      {
        status: 200,
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
