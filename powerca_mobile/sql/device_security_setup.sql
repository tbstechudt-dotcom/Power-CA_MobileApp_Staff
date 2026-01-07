-- ============================================
-- Device Security Setup for PowerCA Mobile
-- OTP-based device verification with PIN lock
-- ============================================

-- 1. Create staff_devices table
-- Tracks verified devices for each staff member
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

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_staff_devices_staff ON staff_devices(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_devices_fingerprint ON staff_devices(device_fingerprint);

-- Add comment
COMMENT ON TABLE staff_devices IS 'Tracks verified devices for each staff member for OTP-based device verification';

-- 2. Create device_otp_requests table
-- Temporary storage for OTP verification requests
CREATE TABLE IF NOT EXISTS device_otp_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    staff_id NUMERIC(8) NOT NULL,
    device_fingerprint VARCHAR(64) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    otp_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_device_otp_staff ON device_otp_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_device_otp_expires ON device_otp_requests(expires_at);

-- Add comment
COMMENT ON TABLE device_otp_requests IS 'Temporary storage for OTP verification requests with expiry and attempt tracking';

-- 3. Create updated_at trigger for staff_devices
CREATE OR REPLACE FUNCTION update_staff_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_staff_devices_updated_at ON staff_devices;
CREATE TRIGGER trigger_staff_devices_updated_at
    BEFORE UPDATE ON staff_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_staff_devices_updated_at();

-- ============================================
-- RPC FUNCTIONS
-- ============================================

-- 4. check_device_status - Check if device is already verified
CREATE OR REPLACE FUNCTION check_device_status(
    p_staff_id NUMERIC,
    p_device_fingerprint VARCHAR
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device RECORD;
BEGIN
    SELECT * INTO v_device
    FROM staff_devices
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint;

    IF v_device IS NULL THEN
        RETURN json_build_object(
            'device_registered', false,
            'is_verified', false
        );
    END IF;

    -- Update last active
    UPDATE staff_devices
    SET last_active_at = NOW()
    WHERE id = v_device.id;

    RETURN json_build_object(
        'device_registered', true,
        'is_verified', v_device.is_verified,
        'verified_at', v_device.verified_at,
        'device_name', v_device.device_name
    );
END;
$$;

-- 5. send_device_verification_otp - Generate and prepare OTP for sending
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
    v_phone VARCHAR;
    v_otp VARCHAR(6);
    v_otp_hash VARCHAR;
    v_expires_at TIMESTAMPTZ;
    v_rate_limit_count INTEGER;
BEGIN
    -- Get staff phone number (column name is 'phonumber' in mbstaff)
    SELECT phonumber INTO v_phone
    FROM mbstaff
    WHERE staff_id = p_staff_id AND active_status IN (0, 1);

    IF v_phone IS NULL OR v_phone = '' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'PHONE_NOT_FOUND',
            'message', 'No phone number registered for this staff member. Please contact admin.'
        );
    END IF;

    -- Rate limit check: max 3 OTPs per hour per staff
    SELECT COUNT(*) INTO v_rate_limit_count
    FROM device_otp_requests
    WHERE staff_id = p_staff_id
      AND created_at > NOW() - INTERVAL '1 hour';

    IF v_rate_limit_count >= 3 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'RATE_LIMIT_EXCEEDED',
            'message', 'Too many OTP requests. Please wait before trying again.'
        );
    END IF;

    -- Generate 6-digit OTP
    v_otp := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    v_otp_hash := encode(sha256(v_otp::bytea), 'hex');
    v_expires_at := NOW() + INTERVAL '5 minutes';

    -- Invalidate previous OTPs for this device
    DELETE FROM device_otp_requests
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint
      AND verified = false;

    -- Store OTP request
    INSERT INTO device_otp_requests (
        staff_id, device_fingerprint, phone_number, otp_hash, expires_at
    ) VALUES (
        p_staff_id, p_device_fingerprint, v_phone, v_otp_hash, v_expires_at
    );

    -- Create or update device record
    INSERT INTO staff_devices (
        staff_id, device_fingerprint, device_name, device_model, platform
    ) VALUES (
        p_staff_id, p_device_fingerprint, p_device_name, p_device_model, p_platform
    )
    ON CONFLICT (staff_id, device_fingerprint) DO UPDATE SET
        device_name = COALESCE(EXCLUDED.device_name, staff_devices.device_name),
        device_model = COALESCE(EXCLUDED.device_model, staff_devices.device_model),
        platform = COALESCE(EXCLUDED.platform, staff_devices.platform),
        updated_at = NOW();

    -- Return success with masked phone and OTP (OTP for testing - remove in production)
    RETURN json_build_object(
        'success', true,
        'phone_masked', CONCAT('******', RIGHT(v_phone, 4)),
        'expires_in_seconds', 300,
        'otp', v_otp  -- NOTE: Remove this line in production! Only for testing
    );
END;
$$;

-- 6. verify_device_otp - Verify OTP and mark device as verified
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
    v_request RECORD;
    v_otp_hash VARCHAR;
BEGIN
    -- Get latest OTP request for this device
    SELECT * INTO v_request
    FROM device_otp_requests
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint
      AND verified = false
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_request IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'NO_OTP_REQUEST',
            'message', 'No pending OTP verification found. Please request a new OTP.'
        );
    END IF;

    -- Check expiry
    IF v_request.expires_at < NOW() THEN
        RETURN json_build_object(
            'success', false,
            'error', 'OTP_EXPIRED',
            'message', 'OTP has expired. Please request a new one.'
        );
    END IF;

    -- Check attempts (max 5)
    IF v_request.attempts >= 5 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'MAX_ATTEMPTS_EXCEEDED',
            'message', 'Too many failed attempts. Please request a new OTP.'
        );
    END IF;

    -- Verify OTP
    v_otp_hash := encode(sha256(p_otp::bytea), 'hex');

    IF v_request.otp_hash != v_otp_hash THEN
        -- Increment attempts
        UPDATE device_otp_requests
        SET attempts = attempts + 1
        WHERE id = v_request.id;

        RETURN json_build_object(
            'success', false,
            'error', 'INVALID_OTP',
            'message', 'Invalid OTP. Please try again.',
            'remaining_attempts', 5 - v_request.attempts - 1
        );
    END IF;

    -- OTP verified - mark device as verified
    UPDATE staff_devices
    SET is_verified = true,
        verified_at = NOW(),
        last_active_at = NOW(),
        updated_at = NOW()
    WHERE staff_id = p_staff_id
      AND device_fingerprint = p_device_fingerprint;

    -- Mark OTP as used
    UPDATE device_otp_requests
    SET verified = true
    WHERE id = v_request.id;

    RETURN json_build_object(
        'success', true,
        'message', 'Device verified successfully. Please set up your PIN.'
    );
END;
$$;

-- 7. Cleanup old OTP requests (run periodically via cron/scheduled function)
CREATE OR REPLACE FUNCTION cleanup_expired_otp_requests()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    DELETE FROM device_otp_requests
    WHERE expires_at < NOW() - INTERVAL '1 day'
       OR (verified = true AND created_at < NOW() - INTERVAL '1 hour');

    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- ============================================
-- ROW LEVEL SECURITY (Optional but recommended)
-- ============================================

-- Enable RLS
ALTER TABLE staff_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_otp_requests ENABLE ROW LEVEL SECURITY;

-- Allow service role full access (for RPC functions)
CREATE POLICY "Service role has full access to staff_devices"
    ON staff_devices
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role has full access to device_otp_requests"
    ON device_otp_requests
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION check_device_status(NUMERIC, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION send_device_verification_otp(NUMERIC, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_device_otp(NUMERIC, VARCHAR, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_otp_requests() TO service_role;
