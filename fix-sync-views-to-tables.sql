-- Fixed sync_views_to_tables() function with proper UPSERT logic
-- This prevents duplicate rows by using ON CONFLICT DO UPDATE

CREATE OR REPLACE FUNCTION public.sync_views_to_tables()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- 🔹 1. orgmaster (PRIMARY KEY: org_id)
    INSERT INTO orgmaster (org_id, orgname, source, created_at, updated_at)
    SELECT org_id, orgname, 'D', NOW(), NOW()
    FROM v_orgmaster
    ON CONFLICT (org_id) DO UPDATE SET
        orgname = EXCLUDED.orgname,
        updated_at = NOW()
    WHERE orgmaster.source = 'D' OR orgmaster.source IS NULL;

    -- 🔹 2. locmaster (PRIMARY KEY: org_id, loc_id)
    INSERT INTO locmaster (org_id, loc_id, locname, source, created_at, updated_at)
    SELECT org_id, loc_id, locname, 'D', NOW(), NOW()
    FROM v_locmaster
    ON CONFLICT (org_id, loc_id) DO UPDATE SET
        locname = EXCLUDED.locname,
        updated_at = NOW()
    WHERE locmaster.source = 'D' OR locmaster.source IS NULL;

    -- 🔹 3. conmaster (PRIMARY KEY: org_id, con_id)
    INSERT INTO conmaster (org_id, con_id, conname, conmail, conphone, source, created_at, updated_at)
    SELECT org_id, bfir_n_firmid, bfir_s_name, bfir_s_email, bfir_s_phone1, 'D', NOW(), NOW()
    FROM v_conmaster
    ON CONFLICT (org_id, con_id) DO UPDATE SET
        conname = EXCLUDED.conname,
        conmail = EXCLUDED.conmail,
        conphone = EXCLUDED.conphone,
        updated_at = NOW()
    WHERE conmaster.source = 'D' OR conmaster.source IS NULL;

    -- 🔹 4. climaster (PRIMARY KEY: org_id, client_id)
    INSERT INTO climaster (
        org_id, con_id, loc_id, client_id, clientname, clientmail, clientphone,
        source, created_at, updated_at
    )
    SELECT
        org_id, billfirm_id, loc_id, client_id, client_name, email, cell_no,
        'D', NOW(), NOW()
    FROM v_climaster
    ON CONFLICT (org_id, client_id) DO UPDATE SET
        con_id = EXCLUDED.con_id,
        loc_id = EXCLUDED.loc_id,
        clientname = EXCLUDED.clientname,
        clientmail = EXCLUDED.clientmail,
        clientphone = EXCLUDED.clientphone,
        updated_at = NOW()
    WHERE climaster.source = 'D' OR climaster.source IS NULL;

    -- 🔹 5. mbstaff (PRIMARY KEY: org_id, staff_id)
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
    FROM v_mbstaff
    ON CONFLICT (org_id, staff_id) DO UPDATE SET
        con_id = EXCLUDED.con_id,
        loc_id = EXCLUDED.loc_id,
        app_username = EXCLUDED.app_username,
        app_pw = EXCLUDED.app_pw,
        stafftype = EXCLUDED.stafftype,
        name = EXCLUDED.name,
        phonumber = EXCLUDED.phonumber,
        dob = EXCLUDED.dob,
        email = EXCLUDED.email,
        whetherca = EXCLUDED.whetherca,
        ca_mem_no = EXCLUDED.ca_mem_no,
        desc_id = EXCLUDED.desc_id,
        spdoj = EXCLUDED.spdoj,
        active_status = EXCLUDED.active_status,
        updated_at = NOW()
    WHERE mbstaff.source = 'D' OR mbstaff.source IS NULL;

    -- 🔹 6. jobshead (PRIMARY KEY: org_id, job_id, year_id)
    INSERT INTO jobshead (
        org_id, con_id, loc_id, job_id, year_id, client_id, jobdate, targetdate,
        job_nature, work_desc, act_man_min, job_status, sporg_id, jctincharge,
        source, created_at, updated_at
    )
    SELECT
        org_id, bfir_n_firmid, loc_id, job_id, year_id, client_id, job_dt, target_dt,
        job_job_nature, job_work_desc, act_man_min, job_status, sporgid, jctincharge,
        'D', NOW(), NOW()
    FROM v_jobshead
    ON CONFLICT (org_id, job_id, year_id) DO UPDATE SET
        con_id = EXCLUDED.con_id,
        loc_id = EXCLUDED.loc_id,
        client_id = EXCLUDED.client_id,
        jobdate = EXCLUDED.jobdate,
        targetdate = EXCLUDED.targetdate,
        job_nature = EXCLUDED.job_nature,
        work_desc = EXCLUDED.work_desc,
        act_man_min = EXCLUDED.act_man_min,
        job_status = EXCLUDED.job_status,
        sporg_id = EXCLUDED.sporg_id,
        jctincharge = EXCLUDED.jctincharge,
        updated_at = NOW()
    WHERE jobshead.source = 'D' OR jobshead.source IS NULL;

    -- 🔹 7. jobtasks (PRIMARY KEY: org_id, job_id, year_id, task_id)
    INSERT INTO jobtasks (
        org_id, con_id, loc_id, job_id, year_id, task_id, taskorder, task_desc,
        jobdet_man_hrs, actual_man_hrs, checklistlinked, source, created_at, updated_at
    )
    SELECT
        org_id, bfir_n_firmid, loc_id, job_id, year_id, task_id, job_det_n_seq,
        task_desc, jobdet_man_hrs, actual_man_hrs, task_checklist_appl, 'D', NOW(), NOW()
    FROM v_jobtasks
    ON CONFLICT (org_id, job_id, year_id, task_id) DO UPDATE SET
        con_id = EXCLUDED.con_id,
        loc_id = EXCLUDED.loc_id,
        taskorder = EXCLUDED.taskorder,
        task_desc = EXCLUDED.task_desc,
        jobdet_man_hrs = EXCLUDED.jobdet_man_hrs,
        actual_man_hrs = EXCLUDED.actual_man_hrs,
        checklistlinked = EXCLUDED.checklistlinked,
        updated_at = NOW()
    WHERE jobtasks.source = 'D' OR jobtasks.source IS NULL;

    -- 🔹 8. taskchecklist (PRIMARY KEY: org_id, task_id, checklistdesc)
    INSERT INTO taskchecklist (
        org_id, loc_id, task_id, checklistdesc, applicable, formatdoc,
        completedby, completeddate, comments, checkliststatus, source, created_at, updated_at
    )
    SELECT
        org_id, loc_id, task_id, tcldesc, 'Y', NULL, NULL, NULL, NULL, activestatus,
        'D', NOW(), NOW()
    FROM v_taskchecklist
    ON CONFLICT (org_id, task_id, checklistdesc) DO UPDATE SET
        loc_id = EXCLUDED.loc_id,
        applicable = EXCLUDED.applicable,
        checkliststatus = EXCLUDED.checkliststatus,
        updated_at = NOW()
    WHERE taskchecklist.source = 'D' OR taskchecklist.source IS NULL;

    -- 🔹 9. mbreminder (PRIMARY KEY: org_id, rem_id)
    INSERT INTO mbreminder (
        rem_id, org_id, loc_id, year_id, staff_id, remdate, client_id, client_name,
        remtype, remnotes, remduedate, user_create, user_modify, user_create_dt,
        user_modify_dt, remtotype, remstatus, remtime, remtitle, color, source, created_at, updated_at
    )
    SELECT
        rem_id, org_id, loc_id, year_id, sporgid, remdate, client_id, client_name,
        remtype, remnotes, remduedate, user_create, user_modify, user_create_dt,
        user_modify_dt, remtotype, remstatus, remtime, remtitle, color, 'D', NOW(), NOW()
    FROM v_mbreminder
    ON CONFLICT (org_id, rem_id) DO UPDATE SET
        loc_id = EXCLUDED.loc_id,
        year_id = EXCLUDED.year_id,
        staff_id = EXCLUDED.staff_id,
        remdate = EXCLUDED.remdate,
        client_id = EXCLUDED.client_id,
        client_name = EXCLUDED.client_name,
        remtype = EXCLUDED.remtype,
        remnotes = EXCLUDED.remnotes,
        remduedate = EXCLUDED.remduedate,
        user_modify = EXCLUDED.user_modify,
        user_modify_dt = EXCLUDED.user_modify_dt,
        remtotype = EXCLUDED.remtotype,
        remstatus = EXCLUDED.remstatus,
        remtime = EXCLUDED.remtime,
        remtitle = EXCLUDED.remtitle,
        color = EXCLUDED.color,
        updated_at = NOW()
    WHERE mbreminder.source = 'D' OR mbreminder.source IS NULL;

    -- 🔹 10. mbremdetail (PRIMARY KEY: org_id, remdetid)
    INSERT INTO mbremdetail (
        remdetid, rem_id, staff_id, remresponse, remresstatus, source, created_at, updated_at
    )
    SELECT
        remdetid, rem_id, sporgid, remresponse, remresstatus, 'D', NOW(), NOW()
    FROM v_mbremdetail
    ON CONFLICT (org_id, remdetid) DO UPDATE SET
        rem_id = EXCLUDED.rem_id,
        staff_id = EXCLUDED.staff_id,
        remresponse = EXCLUDED.remresponse,
        remresstatus = EXCLUDED.remresstatus,
        updated_at = NOW()
    WHERE mbremdetail.source = 'D' OR mbremdetail.source IS NULL;

    RAISE NOTICE '✅ Data sync from views to tables completed successfully with UPSERT!';
END;
$function$;
