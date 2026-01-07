-- Device Security RPC Functions
-- Run this in Supabase SQL Editor AFTER running 001_device_security_tables.sql

-- =====================================================
-- Function 1: check_device_status
-- Checks if a device is registered and verified
-- =====================================================
CREATE OR REPLACE FUNCTION check_device_status(
    p_staff_id NUMERIC,
    p_device_fingerprint VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device staff_devices%ROWTYPE;
    v_result JSON;
BEGIN
    -- Look up the device
    SELECT * INTO v_device
    FROM staff_devices
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint;

    IF v_device.id IS NULL THEN
        -- Device not registered
        v_result := json_build_object(
            'device_registered', false,
            'is_verified', false,
            'device_id', null,
            'verified_at', null
        );
    ELSE
        -- Update last active time
        UPDATE staff_devices
        SET last_active_at = NOW(),
            updated_at = NOW()
        WHERE id = v_device.id;

        -- Return device status
        v_result := json_build_object(
            'device_registered', true,
            'is_verified', v_device.is_verified,
            'device_id', v_device.id,
            'verified_at', v_device.verified_at
        );
    END IF;

    RETURN v_result;
END;
$$;

-- =====================================================
-- Function 2: send_device_verification_otp
-- Generates and stores OTP for device verification
-- =====================================================
CREATE OR REPLACE FUNCTION send_device_verification_otp(
    p_staff_id NUMERIC,
    p_device_fingerprint VARCHAR,
    p_device_name VARCHAR DEFAULT NULL,
    p_device_model VARCHAR DEFAULT NULL,
    p_platform VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_otp VARCHAR(6);
    v_phone VARCHAR(20);
    v_masked_phone VARCHAR(20);
    v_expires_at TIMESTAMPTZ;
    v_recent_count INTEGER;
BEGIN
    -- Rate limiting: Check for recent OTP requests (max 3 per hour)
    SELECT COUNT(*) INTO v_recent_count
    FROM device_otp_requests
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_recent_count >= 3 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'RATE_LIMITED',
            'message', 'Too many OTP requests. Please try again later.'
        );
    END IF;

    -- Get staff phone number from mbstaff table (column is 'phonumber')
    SELECT phonumber INTO v_phone
    FROM mbstaff
    WHERE staff_id = p_staff_id;

    IF v_phone IS NULL OR v_phone = '' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'NO_PHONE',
            'message', 'No phone number registered for this staff member.'
        );
    END IF;

    -- Generate 6-digit OTP
    v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    v_expires_at := NOW() + INTERVAL '5 minutes';

    -- Create masked phone (show last 4 digits)
    v_masked_phone := '****' || RIGHT(v_phone, 4);

    -- Register device if not exists
    INSERT INTO staff_devices (staff_id, device_fingerprint, device_name, device_model, platform)
    VALUES (p_staff_id, p_device_fingerprint, p_device_name, p_device_model, p_platform)
    ON CONFLICT (staff_id, device_fingerprint) DO UPDATE
    SET device_name = COALESCE(p_device_name, staff_devices.device_name),
        device_model = COALESCE(p_device_model, staff_devices.device_model),
        platform = COALESCE(p_platform, staff_devices.platform),
        updated_at = NOW();

    -- Store OTP request
    INSERT INTO device_otp_requests (
        staff_id,
        device_fingerprint,
        phone_number,
        otp_code,
        expires_at
    ) VALUES (
        p_staff_id,
        p_device_fingerprint,
        v_phone,
        v_otp,
        v_expires_at
    );

    -- NOTE: In production, you would integrate with an SMS service here
    -- For now, we'll log the OTP (check Supabase logs or return in dev mode)
    RAISE NOTICE 'OTP for staff %: %', p_staff_id, v_otp;

    RETURN json_build_object(
        'success', true,
        'phone_masked', v_masked_phone,
        'expires_in_seconds', 300,
        'message', 'OTP sent successfully',
        -- FOR DEVELOPMENT ONLY - Remove in production!
        'dev_otp', v_otp
    );
END;
$$;

-- =====================================================
-- Function 3: verify_device_otp
-- Verifies the OTP and marks device as verified
-- =====================================================
CREATE OR REPLACE FUNCTION verify_device_otp(
    p_staff_id NUMERIC,
    p_device_fingerprint VARCHAR,
    p_otp VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_otp_record device_otp_requests%ROWTYPE;
    v_device_id UUID;
BEGIN
    -- Find the most recent unexpired, unverified OTP
    SELECT * INTO v_otp_record
    FROM device_otp_requests
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint
      AND verified = false
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_otp_record.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'OTP_EXPIRED',
            'message', 'OTP has expired. Please request a new one.'
        );
    END IF;

    -- Check attempt limit
    IF v_otp_record.attempts >= v_otp_record.max_attempts THEN
        RETURN json_build_object(
            'success', false,
            'error', 'MAX_ATTEMPTS',
            'message', 'Maximum verification attempts exceeded. Please request a new OTP.'
        );
    END IF;

    -- Increment attempt count
    UPDATE device_otp_requests
    SET attempts = attempts + 1
    WHERE id = v_otp_record.id;

    -- Verify OTP
    IF v_otp_record.otp_code != p_otp THEN
        RETURN json_build_object(
            'success', false,
            'error', 'INVALID_OTP',
            'message', 'Invalid OTP. Please try again.',
            'attempts_remaining', v_otp_record.max_attempts - v_otp_record.attempts - 1
        );
    END IF;

    -- OTP is valid - mark as verified
    UPDATE device_otp_requests
    SET verified = true
    WHERE id = v_otp_record.id;

    -- Mark device as verified
    UPDATE staff_devices
    SET is_verified = true,
        verified_at = NOW(),
        updated_at = NOW()
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint
    RETURNING id INTO v_device_id;

    RETURN json_build_object(
        'success', true,
        'message', 'Device verified successfully',
        'device_id', v_device_id
    );
END;
$$;

-- =====================================================
-- Function 4: check_device_status_by_fingerprint
-- Checks if a device is verified using only fingerprint
-- =====================================================
CREATE OR REPLACE FUNCTION check_device_status_by_fingerprint(
    p_device_fingerprint VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device staff_devices%ROWTYPE;
    v_result JSON;
BEGIN
    -- Look up the device by fingerprint only
    SELECT * INTO v_device
    FROM staff_devices
    WHERE device_fingerprint = p_device_fingerprint
      AND is_verified = true
    LIMIT 1;

    IF v_device.id IS NULL THEN
        -- Device not found or not verified
        v_result := json_build_object(
            'device_registered', false,
            'is_verified', false,
            'device_id', null,
            'verified_at', null
        );
    ELSE
        -- Device is verified
        v_result := json_build_object(
            'device_registered', true,
            'is_verified', true,
            'device_id', v_device.id,
            'verified_at', v_device.verified_at
        );
    END IF;

    RETURN v_result;
END;
$$;

-- =====================================================
-- Function 5: send_otp_with_phone
-- Sends OTP using phone number (for first-time verification)
-- =====================================================
CREATE OR REPLACE FUNCTION send_otp_with_phone(
    p_phone VARCHAR,
    p_device_fingerprint VARCHAR,
    p_device_name VARCHAR DEFAULT NULL,
    p_device_model VARCHAR DEFAULT NULL,
    p_platform VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_otp VARCHAR(6);
    v_staff_id NUMERIC(8);
    v_masked_phone VARCHAR(20);
    v_expires_at TIMESTAMPTZ;
    v_recent_count INTEGER;
BEGIN
    -- Find staff by phone number
    SELECT staff_id INTO v_staff_id
    FROM mbstaff
    WHERE phonumber = p_phone;

    IF v_staff_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'PHONE_NOT_FOUND',
            'message', 'Phone number not registered. Please contact admin.'
        );
    END IF;

    -- Rate limiting: Check for recent OTP requests (max 3 per hour)
    SELECT COUNT(*) INTO v_recent_count
    FROM device_otp_requests
    WHERE device_fingerprint = p_device_fingerprint
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_recent_count >= 3 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'RATE_LIMITED',
            'message', 'Too many OTP requests. Please try again later.'
        );
    END IF;

    -- Generate 6-digit OTP
    v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    v_expires_at := NOW() + INTERVAL '5 minutes';

    -- Create masked phone (show last 4 digits)
    v_masked_phone := '****' || RIGHT(p_phone, 4);

    -- Register device if not exists
    INSERT INTO staff_devices (staff_id, device_fingerprint, device_name, device_model, platform)
    VALUES (v_staff_id, p_device_fingerprint, p_device_name, p_device_model, p_platform)
    ON CONFLICT (staff_id, device_fingerprint) DO UPDATE
    SET device_name = COALESCE(p_device_name, staff_devices.device_name),
        device_model = COALESCE(p_device_model, staff_devices.device_model),
        platform = COALESCE(p_platform, staff_devices.platform),
        updated_at = NOW();

    -- Store OTP request
    INSERT INTO device_otp_requests (
        staff_id,
        device_fingerprint,
        phone_number,
        otp_code,
        expires_at
    ) VALUES (
        v_staff_id,
        p_device_fingerprint,
        p_phone,
        v_otp,
        v_expires_at
    );

    -- NOTE: In production, integrate with SMS service here
    RAISE NOTICE 'OTP for phone %: %', p_phone, v_otp;

    RETURN json_build_object(
        'success', true,
        'phone_masked', v_masked_phone,
        'expires_in_seconds', 300,
        'message', 'OTP sent successfully',
        'staff_id', v_staff_id,
        -- FOR DEVELOPMENT ONLY - Remove in production!
        'dev_otp', v_otp
    );
END;
$$;

-- =====================================================
-- Function 6: verify_otp_with_phone
-- Verifies OTP using phone number
-- =====================================================
CREATE OR REPLACE FUNCTION verify_otp_with_phone(
    p_phone VARCHAR,
    p_device_fingerprint VARCHAR,
    p_otp VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_otp_record device_otp_requests%ROWTYPE;
    v_device_id UUID;
    v_staff_id NUMERIC(8);
BEGIN
    -- Find staff by phone
    SELECT staff_id INTO v_staff_id
    FROM mbstaff
    WHERE phonumber = p_phone;

    IF v_staff_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'PHONE_NOT_FOUND',
            'message', 'Phone number not registered.'
        );
    END IF;

    -- Find the most recent unexpired, unverified OTP
    SELECT * INTO v_otp_record
    FROM device_otp_requests
    WHERE phone_number = p_phone
      AND device_fingerprint = p_device_fingerprint
      AND verified = false
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_otp_record.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'OTP_EXPIRED',
            'message', 'OTP has expired. Please request a new one.'
        );
    END IF;

    -- Check attempt limit
    IF v_otp_record.attempts >= v_otp_record.max_attempts THEN
        RETURN json_build_object(
            'success', false,
            'error', 'MAX_ATTEMPTS',
            'message', 'Maximum verification attempts exceeded. Please request a new OTP.'
        );
    END IF;

    -- Increment attempt count
    UPDATE device_otp_requests
    SET attempts = attempts + 1
    WHERE id = v_otp_record.id;

    -- Verify OTP
    IF v_otp_record.otp_code != p_otp THEN
        RETURN json_build_object(
            'success', false,
            'error', 'INVALID_OTP',
            'message', 'Invalid OTP. Please try again.',
            'attempts_remaining', v_otp_record.max_attempts - v_otp_record.attempts - 1
        );
    END IF;

    -- OTP is valid - mark as verified
    UPDATE device_otp_requests
    SET verified = true
    WHERE id = v_otp_record.id;

    -- Mark device as verified
    UPDATE staff_devices
    SET is_verified = true,
        verified_at = NOW(),
        updated_at = NOW()
    WHERE staff_id = v_staff_id
      AND device_fingerprint = p_device_fingerprint
    RETURNING id INTO v_device_id;

    RETURN json_build_object(
        'success', true,
        'message', 'Device verified successfully',
        'device_id', v_device_id,
        'staff_id', v_staff_id
    );
END;
$$;

-- =====================================================
-- Grant execute permissions
-- =====================================================
GRANT EXECUTE ON FUNCTION check_device_status(NUMERIC, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION check_device_status(NUMERIC, VARCHAR) TO anon;
GRANT EXECUTE ON FUNCTION check_device_status_by_fingerprint(VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION check_device_status_by_fingerprint(VARCHAR) TO anon;
GRANT EXECUTE ON FUNCTION send_device_verification_otp(NUMERIC, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION send_device_verification_otp(NUMERIC, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO anon;
GRANT EXECUTE ON FUNCTION send_otp_with_phone(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION send_otp_with_phone(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO anon;
GRANT EXECUTE ON FUNCTION verify_device_otp(NUMERIC, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_device_otp(NUMERIC, VARCHAR, VARCHAR) TO anon;
GRANT EXECUTE ON FUNCTION verify_otp_with_phone(VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_otp_with_phone(VARCHAR, VARCHAR, VARCHAR) TO anon;
