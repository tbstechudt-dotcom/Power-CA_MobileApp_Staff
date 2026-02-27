-- Migration: Create staff_sessions table for single-device authentication
-- Date: 2026-01-09
-- Description: This table tracks active sessions per staff member.
--              When a staff member logs in on a new device, the previous session is invalidated.
--              This ensures only one device can be logged in at a time per staff member.

-- Create the staff_sessions table
CREATE TABLE IF NOT EXISTS staff_sessions (
    id SERIAL PRIMARY KEY,
    staff_id INTEGER NOT NULL UNIQUE,  -- One session per staff (UNIQUE constraint)
    device_id VARCHAR(255) NOT NULL,   -- Unique device identifier
    device_name VARCHAR(255),          -- Human-readable device name (e.g., "Samsung Galaxy S21")
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Foreign key to mbstaff table
    CONSTRAINT fk_staff_sessions_staff
        FOREIGN KEY (staff_id)
        REFERENCES mbstaff(staff_id)
        ON DELETE CASCADE
);

-- Create index for faster lookups by staff_id
CREATE INDEX IF NOT EXISTS idx_staff_sessions_staff_id ON staff_sessions(staff_id);

-- Create index for faster lookups by device_id
CREATE INDEX IF NOT EXISTS idx_staff_sessions_device_id ON staff_sessions(device_id);

-- Add comment to table
COMMENT ON TABLE staff_sessions IS 'Tracks active login sessions for single-device authentication. Only one device per staff member can be active at a time.';

-- Add comments to columns
COMMENT ON COLUMN staff_sessions.staff_id IS 'Staff member ID - unique constraint ensures only one session per staff';
COMMENT ON COLUMN staff_sessions.device_id IS 'Unique device identifier from device_info_plus package';
COMMENT ON COLUMN staff_sessions.device_name IS 'Human-readable device name for display in session expired message';
COMMENT ON COLUMN staff_sessions.last_active IS 'Last time this session was active';
COMMENT ON COLUMN staff_sessions.is_active IS 'Whether this session is currently active';

-- Enable Row Level Security (RLS)
ALTER TABLE staff_sessions ENABLE ROW LEVEL SECURITY;

-- Policy: Staff can only see their own sessions
CREATE POLICY "Staff can view own sessions" ON staff_sessions
    FOR SELECT
    USING (true);  -- Allow all reads for now (service key handles auth)

-- Policy: Allow insert/update for authenticated users
CREATE POLICY "Allow session management" ON staff_sessions
    FOR ALL
    USING (true)
    WITH CHECK (true);  -- Allow all operations (service key handles auth)

-- Grant permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_sessions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE staff_sessions_id_seq TO authenticated;

-- Grant permissions to anon users (for initial login)
GRANT SELECT, INSERT, UPDATE ON staff_sessions TO anon;
GRANT USAGE, SELECT ON SEQUENCE staff_sessions_id_seq TO anon;

-- ================================================
-- IMPORTANT: Enable Supabase Realtime for this table
-- ================================================
-- This allows the mobile app to receive instant notifications
-- when another device logs in and takes over the session.

-- Add table to supabase_realtime publication for real-time updates
-- Note: Run this in Supabase SQL Editor
ALTER PUBLICATION supabase_realtime ADD TABLE staff_sessions;

-- Alternative: If the above doesn't work, you can enable realtime via Supabase Dashboard:
-- 1. Go to Database > Replication
-- 2. Find 'staff_sessions' table
-- 3. Toggle ON for 'Insert', 'Update', 'Delete' events

-- ================================================
-- Trigger to auto-update updated_at timestamp
-- ================================================
CREATE OR REPLACE FUNCTION update_staff_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_staff_sessions_updated_at
    BEFORE UPDATE ON staff_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_staff_sessions_updated_at();
