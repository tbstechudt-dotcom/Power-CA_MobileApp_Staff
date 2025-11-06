-- =====================================================
-- Power CA Mobile Database Schema for Supabase
-- =====================================================
-- This script creates all tables needed for the mobile app
-- Run this in Supabase SQL Editor
--
-- Order: Master tables first, then transactional tables
-- =====================================================

-- Drop existing tables (if re-running)
DROP TABLE IF EXISTS remdetail CASCADE;
DROP TABLE IF EXISTS reminder CASCADE;
DROP TABLE IF EXISTS workdiary CASCADE;
DROP TABLE IF EXISTS taskchecklist CASCADE;
DROP TABLE IF EXISTS jobtasks CASCADE;
DROP TABLE IF EXISTS jobshead CASCADE;
DROP TABLE IF EXISTS learequest CASCADE;
DROP TABLE IF EXISTS cliunimaster CASCADE;
DROP TABLE IF EXISTS jobmaster CASCADE;
DROP TABLE IF EXISTS taskmaster CASCADE;
DROP TABLE IF EXISTS climaster CASCADE;
DROP TABLE IF EXISTS mbstaff CASCADE;
DROP TABLE IF EXISTS conmaster CASCADE;
DROP TABLE IF EXISTS locmaster CASCADE;
DROP TABLE IF EXISTS orgmaster CASCADE;

-- =====================================================
-- MASTER TABLES
-- =====================================================

-- Organization Master
CREATE TABLE orgmaster (
    org_id   NUMERIC(3)   PRIMARY KEY NOT NULL,
    orgname  VARCHAR(100),
    source   CHAR(1) DEFAULT 'D',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE orgmaster IS 'Organization master data';
COMMENT ON COLUMN orgmaster.source IS 'D=Desktop, M=Mobile, S=Synced';

-- Location Master
CREATE TABLE locmaster (
    org_id   NUMERIC(3)   NOT NULL,
    loc_id   NUMERIC(3)   PRIMARY KEY NOT NULL,
    locname  VARCHAR(100),
    source   CHAR(1) DEFAULT 'D',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id)
);

COMMENT ON TABLE locmaster IS 'Location master data';

-- Consultant Master
CREATE TABLE conmaster (
    org_id    NUMERIC(3)   NOT NULL,
    con_id    INTEGER      PRIMARY KEY NOT NULL,
    conname   VARCHAR(60),
    conmail   VARCHAR(60),
    conphone  VARCHAR(25),
    source    CHAR(1) DEFAULT 'D',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id)
);

COMMENT ON TABLE conmaster IS 'Consultant master data';

-- Staff Master (Mobile)
CREATE TABLE mbstaff (
    org_id         NUMERIC(3)    NOT NULL,
    con_id         INTEGER       NOT NULL,
    loc_id         NUMERIC(3)    NOT NULL,
    staff_id       NUMERIC(8)    PRIMARY KEY NOT NULL,
    app_username   VARCHAR(50),
    app_pw         VARCHAR(50),
    stafftype      NUMERIC(1),
    name           VARCHAR(50),
    phonumber      VARCHAR(30),
    dob            DATE,
    email          VARCHAR(50),
    whetherca      VARCHAR(10),
    ca_mem_no      VARCHAR(10),
    des_id         NUMERIC(5),
    spdoj          DATE,
    createdby      VARCHAR(15),
    createddate    DATE,
    suspendedby    VARCHAR(15),
    suspendeddate  DATE,
    revokedby      VARCHAR(15),
    revokeddate    DATE,
    terminatedby   VARCHAR(15),
    terminateddate DATE,
    active_status  NUMERIC(1),
    source         CHAR(1) DEFAULT 'D',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id)
);

COMMENT ON TABLE mbstaff IS 'Staff/user information for mobile app';

-- Client Master
CREATE TABLE climaster (
    org_id      NUMERIC(3)   NOT NULL,
    con_id      INTEGER      NOT NULL,
    loc_id      NUMERIC(3)   NOT NULL,
    client_id   NUMERIC(7)   PRIMARY KEY NOT NULL,
    clientname  VARCHAR(80),
    clientmail  VARCHAR(60),
    clientphone VARCHAR(25),
    source      CHAR(1) DEFAULT 'D',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id)
);

COMMENT ON TABLE climaster IS 'Client master data';

-- Client Unit Master
CREATE TABLE cliunimaster (
    org_id             NUMERIC(3)   NOT NULL,
    con_id             INTEGER      NOT NULL,
    loc_id             NUMERIC(3)   NOT NULL,
    client_id          NUMERIC(7)   NOT NULL,
    cliunit_id         NUMERIC(7)   PRIMARY KEY NOT NULL,
    cliunitname        VARCHAR(80),
    cliunitadd1        VARCHAR(50),
    cliunitadd2        VARCHAR(50),
    cliunitcity        VARCHAR(50),
    cliunitpin         VARCHAR(8),
    cliunitstate       VARCHAR(35),
    cliunitcountry     VARCHAR(35),
    clientgeolocation  VARCHAR(100),
    cliunitmail        VARCHAR(40),
    cliunitphone       VARCHAR(25),
    cliunitcontactname VARCHAR(60),
    source             CHAR(1) DEFAULT 'D',
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id)
);

COMMENT ON TABLE cliunimaster IS 'Client unit/branch information';

-- Task Master
CREATE TABLE taskmaster (
    org_id      NUMERIC(3)   NOT NULL,
    con_id      INTEGER      NOT NULL,
    loc_id      NUMERIC(3)   NOT NULL,
    task_id     NUMERIC(7)   PRIMARY KEY NOT NULL,
    task_desc   VARCHAR(40),
    task_status NUMERIC(1),
    source      CHAR(1) DEFAULT 'D',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id)
);

COMMENT ON TABLE taskmaster IS 'Task master/template data';

-- Job Master
CREATE TABLE jobmaster (
    org_id     NUMERIC(3)   NOT NULL,
    con_id     INTEGER      NOT NULL,
    loc_id     NUMERIC(3)   NOT NULL,
    job_id     NUMERIC(10)  PRIMARY KEY NOT NULL,
    jobdesc    VARCHAR(100),
    jobstatus  CHAR(1),
    source     CHAR(1) DEFAULT 'D',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id)
);

COMMENT ON TABLE jobmaster IS 'Job master/template data';

-- =====================================================
-- TRANSACTIONAL TABLES
-- =====================================================

-- Jobs Head
CREATE TABLE jobshead (
    org_id           NUMERIC(3)   NOT NULL,
    con_id           INTEGER      NOT NULL,
    loc_id           NUMERIC(3)   NOT NULL,
    job_id           NUMERIC(10)  PRIMARY KEY NOT NULL,
    year_id          NUMERIC(8),
    client_id        NUMERIC(7)   NOT NULL,
    jobdate          DATE,
    targetdate       DATE,
    job_nature       CHAR(1),
    work_desc        VARCHAR(100),
    worklocation     VARCHAR(15),
    act_man_min      NUMERIC(10),
    drivefolderpath  VARCHAR(100),
    drivefolderkey   VARCHAR(100),
    job_status       CHAR(1),
    source           CHAR(1) DEFAULT 'D',
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id)
);

COMMENT ON TABLE jobshead IS 'Job header information';

-- Job Tasks
CREATE TABLE jobtasks (
    org_id            NUMERIC(3)     NOT NULL,
    con_id            INTEGER        NOT NULL,
    loc_id            NUMERIC(3)     NOT NULL,
    job_id            NUMERIC(10)    NOT NULL,
    year_id           NUMERIC(8),
    client_id         NUMERIC(7)     NOT NULL,
    task_id           NUMERIC(7)     NOT NULL,
    taskorder         NUMERIC(10),
    task_desc         VARCHAR(40),
    jobdet_man_hrs    NUMERIC(8,2),
    actual_man_hrs    TIME WITHOUT TIME ZONE,
    actual_man_min    NUMERIC(10),
    checklistlinked   CHAR(1),
    createdby         VARCHAR(15),
    createddate       DATE,
    task_status       NUMERIC(1),
    source            CHAR(1) DEFAULT 'D',
    created_at        TIMESTAMPTZ DEFAULT NOW(),
    updated_at        TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (job_id, task_id),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (job_id) REFERENCES jobshead(job_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id),
    FOREIGN KEY (task_id) REFERENCES taskmaster(task_id)
);

COMMENT ON TABLE jobtasks IS 'Tasks associated with jobs';

-- Task Checklist
CREATE TABLE taskchecklist (
    org_id           NUMERIC(3)    NOT NULL,
    con_id           INTEGER       NOT NULL,
    loc_id           NUMERIC(3)    NOT NULL,
    job_id           NUMERIC(10)   NOT NULL,
    year_id          NUMERIC(8)    NOT NULL,
    client_id        NUMERIC(7)    NOT NULL,
    task_id          NUMERIC(7)    NOT NULL,
    checklistdesc    VARCHAR(100),
    applicable       VARCHAR(15),
    formatdoc        VARCHAR(15),
    completedby      VARCHAR(15),
    completeddate    DATE,
    comments         VARCHAR(100),
    checkliststatus  NUMERIC(1),
    source           CHAR(1) DEFAULT 'D',
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (job_id, task_id, checklistdesc),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (job_id) REFERENCES jobshead(job_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id),
    FOREIGN KEY (task_id) REFERENCES taskmaster(task_id)
);

COMMENT ON TABLE taskchecklist IS 'Checklists for job tasks';

-- Work Diary
CREATE TABLE workdiary (
    org_id        NUMERIC(3)   NOT NULL,
    con_id        INTEGER      NOT NULL,
    loc_id        NUMERIC(3)   NOT NULL,
    wd_id         NUMERIC(8)   PRIMARY KEY NOT NULL,
    staff_id      NUMERIC(8)   NOT NULL,
    job_id        NUMERIC(10)  NOT NULL,
    client_id     NUMERIC(7)   NOT NULL,
    cma_id        NUMERIC(5)   NOT NULL,
    task_id       NUMERIC(7)   NOT NULL,
    date          DATE,
    timefrom      TIMESTAMP,
    timeto        TIMESTAMP,
    minutes       NUMERIC(4),
    tasknotes     VARCHAR(50),
    attachment    CHAR(1),
    doc_ref       VARCHAR(15),
    source        CHAR(1) DEFAULT 'D',
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (staff_id) REFERENCES mbstaff(staff_id),
    FOREIGN KEY (job_id) REFERENCES jobshead(job_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id),
    FOREIGN KEY (task_id) REFERENCES taskmaster(task_id)
);

COMMENT ON TABLE workdiary IS 'Daily work diary entries by staff';

-- Reminder
CREATE TABLE reminder (
    rem_id         NUMERIC(8)   PRIMARY KEY NOT NULL,
    org_id         NUMERIC(3)   NOT NULL,
    loc_id         NUMERIC(3)   NOT NULL,
    year_id        NUMERIC(9)   NOT NULL,
    staff_id       NUMERIC(8)   NOT NULL,
    remdate        DATE,
    client_id      NUMERIC(7)   NOT NULL,
    client_name    VARCHAR(80),
    remtype        VARCHAR(30),
    remnotes       VARCHAR(100),
    remduedate     DATE,
    user_create    VARCHAR(15),
    user_modify    VARCHAR(15),
    user_create_dt DATE,
    user_modify_dt DATE,
    remtotype      CHAR(1),
    remstatus      NUMERIC(1),
    remtime        TIME WITHOUT TIME ZONE,
    remtitle       VARCHAR(100),
    color          INTEGER,
    source         CHAR(1) DEFAULT 'D',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (staff_id) REFERENCES mbstaff(staff_id),
    FOREIGN KEY (client_id) REFERENCES climaster(client_id)
);

COMMENT ON TABLE reminder IS 'Reminders and notifications';

-- Reminder Detail
CREATE TABLE remdetail (
    remdetid     NUMERIC(8) PRIMARY KEY NOT NULL,
    rem_id       NUMERIC(8) NOT NULL,
    staff_id     NUMERIC(8) NOT NULL,
    remresponse  VARCHAR(150),
    remresstatus CHAR(1),
    source       CHAR(1) DEFAULT 'D',
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (rem_id) REFERENCES reminder(rem_id),
    FOREIGN KEY (staff_id) REFERENCES mbstaff(staff_id)
);

COMMENT ON TABLE remdetail IS 'Reminder responses and status details';

-- Leave Request
CREATE TABLE learequest (
    org_id          NUMERIC(3) NOT NULL,
    con_id          INTEGER NOT NULL,
    loc_id          NUMERIC(3) NOT NULL,
    learequest_id   NUMERIC(5) PRIMARY KEY NOT NULL,
    staff_id        NUMERIC(8) NOT NULL,
    requestdate     DATE,
    fromdate        DATE,
    todate          DATE,
    fhvalue         CHAR(2),
    shvalue         CHAR(2),
    leavetype       CHAR(2),
    leaveremarks    VARCHAR(50),
    createdby       VARCHAR(15),
    createddate     DATE,
    approval_status CHAR(1),
    approvedby      VARCHAR(30),
    approveddate    DATE,
    source          CHAR(1) DEFAULT 'D',
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (org_id) REFERENCES orgmaster(org_id),
    FOREIGN KEY (con_id) REFERENCES conmaster(con_id),
    FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id),
    FOREIGN KEY (staff_id) REFERENCES mbstaff(staff_id)
);

COMMENT ON TABLE learequest IS 'Leave requests from staff';

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX idx_mbstaff_email ON mbstaff(email);
CREATE INDEX idx_mbstaff_active ON mbstaff(active_status);
CREATE INDEX idx_jobshead_client ON jobshead(client_id);
CREATE INDEX idx_jobshead_date ON jobshead(jobdate);
CREATE INDEX idx_jobshead_status ON jobshead(job_status);
CREATE INDEX idx_jobtasks_job ON jobtasks(job_id);
CREATE INDEX idx_jobtasks_task ON jobtasks(task_id);
CREATE INDEX idx_workdiary_staff ON workdiary(staff_id);
CREATE INDEX idx_workdiary_date ON workdiary(date);
CREATE INDEX idx_workdiary_job ON workdiary(job_id);
CREATE INDEX idx_reminder_staff ON reminder(staff_id);
CREATE INDEX idx_reminder_duedate ON reminder(remduedate);
CREATE INDEX idx_reminder_status ON reminder(remstatus);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER update_orgmaster_updated_at BEFORE UPDATE ON orgmaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_locmaster_updated_at BEFORE UPDATE ON locmaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conmaster_updated_at BEFORE UPDATE ON conmaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mbstaff_updated_at BEFORE UPDATE ON mbstaff FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_climaster_updated_at BEFORE UPDATE ON climaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cliunimaster_updated_at BEFORE UPDATE ON cliunimaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_taskmaster_updated_at BEFORE UPDATE ON taskmaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jobmaster_updated_at BEFORE UPDATE ON jobmaster FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jobshead_updated_at BEFORE UPDATE ON jobshead FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_jobtasks_updated_at BEFORE UPDATE ON jobtasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_taskchecklist_updated_at BEFORE UPDATE ON taskchecklist FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workdiary_updated_at BEFORE UPDATE ON workdiary FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_reminder_updated_at BEFORE UPDATE ON reminder FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_remdetail_updated_at BEFORE UPDATE ON remdetail FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_learequest_updated_at BEFORE UPDATE ON learequest FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SYNC METADATA TABLE
-- =====================================================

CREATE TABLE _sync_metadata (
    table_name VARCHAR(255) PRIMARY KEY,
    last_sync_timestamp TIMESTAMPTZ,
    last_sync_id BIGINT,
    sync_direction VARCHAR(10),
    sync_status VARCHAR(50),
    records_synced INTEGER DEFAULT 0,
    error_message TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE _sync_metadata IS 'Tracks sync status for each table';
COMMENT ON COLUMN _sync_metadata.sync_direction IS 'D→S (Desktop to Supabase) or S→D (Supabase to Desktop)';

-- =====================================================
-- SYNC LOG TABLE
-- =====================================================

CREATE TABLE _sync_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255),
    sync_direction VARCHAR(10),
    operation VARCHAR(10),
    record_id TEXT,
    records_affected INTEGER DEFAULT 0,
    sync_timestamp TIMESTAMPTZ DEFAULT NOW(),
    success BOOLEAN,
    error_message TEXT,
    duration_ms INTEGER
);

COMMENT ON TABLE _sync_log IS 'Detailed log of all sync operations';
COMMENT ON COLUMN _sync_log.sync_direction IS 'D→S (Desktop to Supabase) or S→D (Supabase to Desktop)';
COMMENT ON COLUMN _sync_log.operation IS 'insert, update, delete, upsert';
COMMENT ON COLUMN _sync_log.duration_ms IS 'Sync operation duration in milliseconds';

-- =====================================================
-- COMPLETE!
-- =====================================================

-- Grant permissions (if needed)
-- ALTER DEFAULT PRIVILEGES GRANT ALL ON TABLES TO authenticated;
-- ALTER DEFAULT PRIVILEGES GRANT ALL ON SEQUENCES TO authenticated;

SELECT 'Schema created successfully! ' || COUNT(*) || ' tables created.'
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
