/**
 * Schema Migration: Fix con_id constraints to allow 0 and NULL
 *
 * Problem:
 * - 594 clients in desktop have con_id=0 or NULL (representing "no contractor")
 * - Supabase requires con_id to reference conmaster (FK constraint)
 * - con_id=0 doesn't exist in conmaster, causing sync failures
 *
 * Solution:
 * 1. Insert dummy conmaster record with con_id=0
 * 2. Make con_id nullable in climaster
 *
 * Run this in Supabase SQL Editor
 */

-- =============================================================================
-- 1. CREATE DUMMY CONTRACTOR RECORD (con_id=0)
-- =============================================================================

-- Insert a dummy contractor record to represent "no contractor assigned"
INSERT INTO conmaster (con_id, con_name)
VALUES (0, 'No Contractor')
ON CONFLICT (con_id) DO NOTHING;

COMMENT ON COLUMN conmaster.con_id IS 'Contractor ID (0 = No contractor assigned)';

-- Verify the record was created
SELECT * FROM conmaster WHERE con_id = 0;

-- =============================================================================
-- 2. MAKE con_id NULLABLE IN climaster
-- =============================================================================

-- Drop the NOT NULL constraint on con_id
ALTER TABLE climaster
ALTER COLUMN con_id DROP NOT NULL;

-- Verify the column definition
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'climaster' AND column_name = 'con_id';

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Check the FK constraint still exists
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'climaster'
    AND kcu.column_name = 'con_id';

-- =============================================================================
-- TEST INSERT
-- =============================================================================

-- Test that we can now insert records with con_id=0
-- (This is just a test, will be rolled back)
BEGIN;

-- Assuming org_id=1 and loc_id=1 exist
INSERT INTO climaster (org_id, con_id, loc_id, client_id)
VALUES (1, 0, 1, 999999);

SELECT * FROM climaster WHERE client_id = 999999;

ROLLBACK;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================

SELECT 'Migration completed successfully!' AS status,
       'con_id=0 now represents "No Contractor"' AS conmaster_status,
       'climaster.con_id is now nullable' AS climaster_status;
