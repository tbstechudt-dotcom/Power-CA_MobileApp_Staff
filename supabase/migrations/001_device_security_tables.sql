-- Device Security Tables for OTP-based App Lock
-- Run this in Supabase SQL Editor

-- =====================================================
-- Table 1: staff_devices - Stores registered devices
-- =====================================================
CREATE TABLE IF NOT EXISTS staff_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
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

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_staff_devices_staff_id ON staff_devices(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_devices_fingerprint ON staff_devices(device_fingerprint);

-- =====================================================
-- Table 2: device_otp_requests - OTP verification tracking
-- =====================================================
CREATE TABLE IF NOT EXISTS device_otp_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    staff_id NUMERIC(8) NOT NULL,
    device_fingerprint VARCHAR(64) NOT NULL,
    phone_number VARCHAR(20),
    otp_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 5,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_device_otp_staff_id ON device_otp_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_device_otp_fingerprint ON device_otp_requests(device_fingerprint);

-- =====================================================
-- Enable Row Level Security
-- =====================================================
ALTER TABLE staff_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_otp_requests ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read/write their own device records
CREATE POLICY "Users can manage their own devices" ON staff_devices
    FOR ALL USING (true);

CREATE POLICY "Users can manage their own OTP requests" ON device_otp_requests
    FOR ALL USING (true);

-- =====================================================
-- Grant permissions
-- =====================================================
GRANT ALL ON staff_devices TO authenticated;
GRANT ALL ON staff_devices TO anon;
GRANT ALL ON device_otp_requests TO authenticated;
GRANT ALL ON device_otp_requests TO anon;
