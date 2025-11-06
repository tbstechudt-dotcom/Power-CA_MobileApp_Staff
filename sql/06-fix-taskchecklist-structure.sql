/**
 * Fix taskchecklist structure to match desktop
 * Desktop has generic task templates (no job-specific columns)
 */

BEGIN;

-- 1. Drop primary key
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_pkey;

-- 2. Drop all foreign key constraints
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_org_id_fkey;
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_con_id_fkey;
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_loc_id_fkey;
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_client_id_fkey;
ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_task_id_fkey;

-- 3. Drop job-specific columns
ALTER TABLE taskchecklist DROP COLUMN IF EXISTS con_id;
ALTER TABLE taskchecklist DROP COLUMN IF EXISTS job_id;
ALTER TABLE taskchecklist DROP COLUMN IF EXISTS year_id;
ALTER TABLE taskchecklist DROP COLUMN IF EXISTS client_id;

-- 4. Add tc_id as primary key (auto-increment)
ALTER TABLE taskchecklist ADD COLUMN tc_id BIGSERIAL PRIMARY KEY;

-- 5. Re-add foreign key constraints for remaining columns
ALTER TABLE taskchecklist
  ADD CONSTRAINT taskchecklist_org_id_fkey
  FOREIGN KEY (org_id) REFERENCES orgmaster(org_id);

ALTER TABLE taskchecklist
  ADD CONSTRAINT taskchecklist_loc_id_fkey
  FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id);

ALTER TABLE taskchecklist
  ADD CONSTRAINT taskchecklist_task_id_fkey
  FOREIGN KEY (task_id) REFERENCES taskmaster(task_id);

COMMIT;

-- Verify the structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'taskchecklist'
ORDER BY ordinal_position;
