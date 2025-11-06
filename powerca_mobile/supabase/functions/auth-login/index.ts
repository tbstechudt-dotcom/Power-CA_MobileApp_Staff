// Supabase Edge Function: auth-login
// Handles PowerCA Mobile authentication
// Simple plain-text password comparison (for development/testing)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const { username, password } = await req.json()

    // Validate inputs
    if (!username || !password) {
      return new Response(
        JSON.stringify({ error: 'Username and password are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Create Supabase client with service role (bypass RLS)
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Query mbstaff table for user
    const { data: user, error: queryError } = await supabase
      .from('mbstaff')
      .select('*')
      .eq('app_username', username)
      .maybeSingle()

    if (queryError) {
      console.error('Database query error:', queryError)
      return new Response(
        JSON.stringify({ error: 'Database error' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if user exists
    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Invalid username or password' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if password is configured
    if (!user.app_pw) {
      return new Response(
        JSON.stringify({ error: 'User password not configured' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Simple plain-text password comparison
    console.log('Auth attempt:', {
      username,
      storedPassword: user.app_pw,
      inputPassword: password,
    })

    // Compare passwords directly (plain text)
    if (password !== user.app_pw) {
      console.log('Password mismatch')
      return new Response(
        JSON.stringify({ error: 'Invalid username or password' }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if user is active (0 or 1 = active)
    const isActive = user.active_status === 0 || user.active_status === 1
    if (!isActive) {
      return new Response(
        JSON.stringify({ error: 'User account is inactive' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Authentication successful! Return staff data (without password)
    const staffData = {
      staff_id: user.staff_id,
      name: user.name,
      app_username: user.app_username,
      org_id: user.org_id,
      loc_id: user.loc_id,
      con_id: user.con_id,
      email: user.email,
      phonumber: user.phonumber,
      dob: user.dob,
      stafftype: user.stafftype,
      active_status: user.active_status,
    }

    return new Response(
      JSON.stringify({
        success: true,
        staff: staffData,
        message: `Welcome, ${user.name}!`
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
