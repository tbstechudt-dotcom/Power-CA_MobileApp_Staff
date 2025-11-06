/**
 * Schema Migration: Add jt_id to jobtasks and desc_id to mbstaff
 *
 * Changes:
 * 1. Add jt_id as auto-incrementing primary key to jobtasks
 * 2. Move existing composite PK (job_id, task_id) to unique constraint
 * 3. Add desc_id column to mbstaff
 *
 * Run this in Supabase SQL Editor
 */

-- =============================================================================
-- 1. ADD jt_id TO jobtasks
-- =============================================================================

-- Step 1: Drop existing primary key constraint
ALTER TABLE jobtasks
DROP CONSTRAINT jobtasks_pkey;

-- Step 2: Add jt_id column as BIGSERIAL (auto-incrementing)
ALTER TABLE jobtasks
ADD COLUMN jt_id BIGSERIAL;

-- Step 3: Set jt_id as new primary key
ALTER TABLE jobtasks
ADD PRIMARY KEY (jt_id);

-- Step 4: Add unique constraint on old composite key to maintain data integrity
ALTER TABLE jobtasks
ADD CONSTRAINT jobtasks_job_task_unique UNIQUE (job_id, task_id);

-- Step 5: Add index on job_id for performance (FK lookups)
CREATE INDEX IF NOT EXISTS idx_jobtasks_job_id ON jobtasks(job_id);

-- Step 6: Add index on task_id for performance (FK lookups)
CREATE INDEX IF NOT EXISTS idx_jobtasks_task_id ON jobtasks(task_id);

-- Verify jobtasks structure
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'jobtasks'
ORDER BY ordinal_position;

-- =============================================================================
-- 2. ADD desc_id TO mbstaff
-- =============================================================================

-- Add desc_id column to mbstaff (designation ID)
ALTER TABLE mbstaff
ADD COLUMN IF NOT EXISTS desc_id NUMERIC(8);

-- Add comment
COMMENT ON COLUMN mbstaff.desc_id IS 'Designation ID (reference to descmaster - marked as technical debt)';

-- Note: No FK constraint since descmaster table doesn't exist yet (technical debt)

-- Verify mbstaff structure
SELECT
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'mbstaff'
ORDER BY ordinal_position;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Check jobtasks primary key
SELECT
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'jobtasks'
    AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.constraint_type, kcu.ordinal_position;

-- Check mbstaff columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'mbstaff'
    AND column_name IN ('staff_id', 'desc_id', 'des_id')
ORDER BY column_name;

-- =============================================================================
-- SUCCESS MESSAGE
-- =============================================================================
SELECT 'Migration completed successfully!' AS status,
       'jobtasks now has jt_id as primary key' AS jobtasks_status,
       'mbstaff now has desc_id column' AS mbstaff_status;
