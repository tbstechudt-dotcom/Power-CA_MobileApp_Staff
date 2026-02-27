-- Migration: Create login_requests table for permission-based authentication
-- Date: 2026-01-09
-- Description: When a new device tries to login, it creates a request here.
--              The currently logged-in device receives the request and can approve/deny it.
--              This provides extra security by requiring permission from the existing device.

-- Create the login_requests table
CREATE TABLE IF NOT EXISTS login_requests (
    id SERIAL PRIMARY KEY,
    staff_id INTEGER NOT NULL,
    requesting_device_id VARCHAR(255) NOT NULL,   -- Device trying to login
    requesting_device_name VARCHAR(255),          -- Human-readable name (e.g., "Samsung Galaxy S21")
    current_device_id VARCHAR(255),               -- Device that needs to approve
    status VARCHAR(20) DEFAULT 'pending',         -- pending, approved, denied, expired
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,        -- When approval/denial happened
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '2 minutes'),  -- Auto-expire after 2 mins

    -- Foreign key to mbstaff table
    CONSTRAINT fk_login_requests_staff
        FOREIGN KEY (staff_id)
        REFERENCES mbstaff(staff_id)
        ON DELETE CASCADE
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_login_requests_staff_id ON login_requests(staff_id);
CREATE INDEX IF NOT EXISTS idx_login_requests_status ON login_requests(status);
CREATE INDEX IF NOT EXISTS idx_login_requests_current_device ON login_requests(current_device_id);

-- Add comments
COMMENT ON TABLE login_requests IS 'Tracks login requests for permission-based multi-device authentication';
COMMENT ON COLUMN login_requests.status IS 'pending=waiting for response, approved=login allowed, denied=login blocked, expired=timed out';

-- Enable Row Level Security (RLS)
ALTER TABLE login_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations (service handles auth)
CREATE POLICY "Allow login request management" ON login_requests
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON login_requests TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE login_requests_id_seq TO authenticated;
GRANT SELECT, INSERT, UPDATE ON login_requests TO anon;
GRANT USAGE, SELECT ON SEQUENCE login_requests_id_seq TO anon;

-- ================================================
-- Enable Supabase Realtime for instant notifications
-- ================================================
ALTER PUBLICATION supabase_realtime ADD TABLE login_requests;

-- ================================================
-- Function to auto-expire old pending requests
-- ================================================
CREATE OR REPLACE FUNCTION expire_old_login_requests()
RETURNS TRIGGER AS $$
BEGIN
    -- Mark old pending requests as expired
    UPDATE login_requests
    SET status = 'expired'
    WHERE staff_id = NEW.staff_id
      AND status = 'pending'
      AND id != NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: When new request is created, expire old pending ones
CREATE TRIGGER trigger_expire_old_requests
    AFTER INSERT ON login_requests
    FOR EACH ROW
    EXECUTE FUNCTION expire_old_login_requests();

-- ================================================
-- Function to cleanup expired requests (run periodically)
-- ================================================
CREATE OR REPLACE FUNCTION cleanup_expired_login_requests()
RETURNS void AS $$
BEGIN
    UPDATE login_requests
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < NOW();

    -- Delete requests older than 24 hours
    DELETE FROM login_requests
    WHERE created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;
