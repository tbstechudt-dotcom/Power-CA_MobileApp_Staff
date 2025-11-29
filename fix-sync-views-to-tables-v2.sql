-- Fixed sync_views_to_tables() function WITHOUT using ON CONFLICT
-- Since desktop tables have no unique constraints, we use DELETE + INSERT pattern

CREATE OR REPLACE FUNCTION public.sync_views_to_tables()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- 🔹 1. orgmaster
    -- Delete existing desktop records, then insert fresh data
    DELETE FROM orgmaster WHERE source = 'D' OR source IS NULL;
    INSERT INTO orgmaster (org_id, orgname, source, created_at, updated_at)
    SELECT org_id, orgname, 'D', NOW(), NOW()
    FROM v_orgmaster;

    -- 🔹 2. locmaster
    DELETE FROM locmaster WHERE source = 'D' OR source IS NULL;
    INSERT INTO locmaster (org_id, loc_id, locname, source, created_at, updated_at)
    SELECT org_id, loc_id, locname, 'D', NOW(), NOW()
    FROM v_locmaster;

    -- 🔹 3. conmaster
    DELETE FROM conmaster WHERE source = 'D' OR source IS NULL;
    INSERT INTO conmaster (org_id, con_id, conname, conmail, conphone, source, created_at, updated_at)
    SELECT org_id, bfir_n_firmid, bfir_s_name, bfir_s_email, bfir_s_phone1, 'D', NOW(), NOW()
    FROM v_conmaster;

    -- 🔹 4. climaster
    DELETE FROM climaster WHERE source = 'D' OR source IS NULL;
    INSERT INTO climaster (
        org_id, con_id, loc_id, client_id, clientname, clientmail, clientphone,
        source, created_at, updated_at
    )
    SELECT
        org_id, billfirm_id, loc_id, client_id, client_name, email, cell_no,
        'D', NOW(), NOW()
    FROM v_climaster;

    -- 🔹 5. mbstaff
    DELETE FROM mbstaff WHERE source = 'D' OR source IS NULL;
    INSERT INTO mbstaff (
        org_id, con_id, loc_id, staff_id, app_username, app_pw, stafftype, name,
        phonumber, dob, email, whetherca, ca_mem_no, desc_id, spdoj, createdby,
        createddate, suspendedby, suspendeddate, revokedby, revokeddate,
        terminatedby, terminateddate, active_status, source, created_at, updated_at
    )
    SELECT
        org_id, bfir_n_firmid, loc_id, sporgid, userloginname, userpassword,
        sptype, spfirname, sasmsmobno, spdob, saemail, prof_type, ca_mem_no,
        des_id, spdoj, createdby, createddate, suspendedby, suspendeddate,
        revokedby, revokeddate, terminatedby, terminateddate_final, active_status,
        source, NOW(), NOW()
    FROM v_mbstaff;

    -- 🔹 6. jobshead
    DELETE FROM jobshead WHERE source = 'D' OR source IS NULL;
    INSERT INTO jobshead (
        org_id, con_id, loc_id, job_id, year_id, client_id, jobdate, targetdate,
        job_nature, work_desc, act_man_min, job_status, sporg_id, jctincharge,
        source, created_at, updated_at
    )
    SELECT
        org_id, bfir_n_firmid, loc_id, job_id, year_id, client_id, job_dt, target_dt,
        job_job_nature, job_work_desc, act_man_min, job_status, sporgid, jctincharge,
        'D', NOW(), NOW()
    FROM v_jobshead;

    -- 🔹 7. jobtasks
    DELETE FROM jobtasks WHERE source = 'D' OR source IS NULL;
    INSERT INTO jobtasks (
        org_id, con_id, loc_id, job_id, year_id, task_id, taskorder, task_desc,
        jobdet_man_hrs, actual_man_hrs, checklistlinked, source, created_at, updated_at
    )
    SELECT
        org_id, bfir_n_firmid, loc_id, job_id, year_id, task_id, job_det_n_seq,
        task_desc, jobdet_man_hrs, actual_man_hrs, task_checklist_appl, 'D', NOW(), NOW()
    FROM v_jobtasks;

    -- 🔹 8. taskchecklist
    DELETE FROM taskchecklist WHERE source = 'D' OR source IS NULL;
    INSERT INTO taskchecklist (
        org_id, loc_id, task_id, checklistdesc, applicable, formatdoc,
        completedby, completeddate, comments, checkliststatus, source, created_at, updated_at
    )
    SELECT
        org_id, loc_id, task_id, tcldesc, 'Y', NULL, NULL, NULL, NULL, activestatus,
        'D', NOW(), NOW()
    FROM v_taskchecklist;

    -- 🔹 9. mbreminder
    DELETE FROM mbreminder WHERE source = 'D' OR source IS NULL;
    INSERT INTO mbreminder (
        rem_id, org_id, loc_id, year_id, staff_id, remdate, client_id, client_name,
        remtype, remnotes, remduedate, user_create, user_modify, user_create_dt,
        user_modify_dt, remtotype, remstatus, remtime, remtitle, color, source, created_at, updated_at
    )
    SELECT
        rem_id, org_id, loc_id, year_id, sporgid, remdate, client_id, client_name,
        remtype, remnotes, remduedate, user_create, user_modify, user_create_dt,
        user_modify_dt, remtotype, remstatus, remtime, remtitle, color, 'D', NOW(), NOW()
    FROM v_mbreminder;

    -- 🔹 10. mbremdetail
    DELETE FROM mbremdetail WHERE source = 'D' OR source IS NULL;
    INSERT INTO mbremdetail (
        remdetid, rem_id, staff_id, remresponse, remresstatus, source, created_at, updated_at
    )
    SELECT
        remdetid, rem_id, sporgid, remresponse, remresstatus, 'D', NOW(), NOW()
    FROM v_mbremdetail;

    RAISE NOTICE '✅ Data sync from views to tables completed successfully (DELETE+INSERT pattern)!';
END;
$function$;
