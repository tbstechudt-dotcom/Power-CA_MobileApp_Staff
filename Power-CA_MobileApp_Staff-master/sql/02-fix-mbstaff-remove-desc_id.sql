-- Migration: Remove desc_id column from mbstaff (if it exists)
-- Date: 2025-10-28
-- Reason: desc_id is not needed in mobile app, sync script will skip it

-- Drop desc_id column if it exists (safe - won't error if column doesn't exist)
ALTER TABLE mbstaff
DROP COLUMN IF EXISTS desc_id;

-- Verify the column was removed
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_name = 'mbstaff'
      AND column_name = 'desc_id'
    )
    THEN 'desc_id column still exists'
    ELSE 'desc_id column successfully removed (or never existed)'
  END AS result;
