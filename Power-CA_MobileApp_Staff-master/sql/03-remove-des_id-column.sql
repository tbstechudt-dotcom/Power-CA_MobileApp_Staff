-- Migration: Remove des_id column from mbstaff table
-- Date: 2025-10-28
-- Reason: des_id was incorrect column name, should be desc_id

-- Drop des_id column (the incorrect one)
ALTER TABLE mbstaff
DROP COLUMN IF EXISTS des_id;

-- Verify the column was removed
SELECT
  column_name,
  data_type
FROM information_schema.columns
WHERE table_name = 'mbstaff'
AND column_name IN ('des_id', 'desc_id')
ORDER BY column_name;

-- Expected result: Only desc_id should remain
