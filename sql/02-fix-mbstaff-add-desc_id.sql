-- Migration: Add missing desc_id column to mbstaff table
-- Date: 2025-10-28
-- Issue: Desktop mbstaff has desc_id column but mobile schema was missing it

-- Add desc_id column to mbstaff table
ALTER TABLE mbstaff
ADD COLUMN desc_id NUMERIC(8);

-- Add comment
COMMENT ON COLUMN mbstaff.desc_id IS 'Designation ID - references designation master';

-- Verify the column was added
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'mbstaff'
AND column_name = 'desc_id';

-- Success message
SELECT 'Column desc_id added successfully to mbstaff table' AS result;
