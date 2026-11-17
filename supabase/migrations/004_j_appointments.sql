-- =====================================================
-- j_appointments: client / contact meetings booked from the mobile app
--
-- Written by the "Add meeting" screen (Appointment tab) and updated by the
-- Outcome tab. Rescheduling marks the old row appo_status = 'R' and inserts
-- a new row with the new meeting date/time.
--
-- Deviations from the original spec:
--   * The spec listed con_id twice. con_id keeps the logged-in staff's
--     con_id; the contact picked for a "New" meeting goes in appo_con_id
--     (= contactperson.con_id, see 005_contactperson.sql).
--   * currect_date typo -> CURRENT_DATE.
--   * source / created_at / updated_at added to match the other mobile
--     tables (source = 'M' for mobile rows) so reverse sync can pick it up.
-- =====================================================

CREATE SEQUENCE IF NOT EXISTS public.j_appointments_appo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 99999          -- appo_id is numeric(5,0)
    NO CYCLE;

CREATE TABLE IF NOT EXISTS public.j_appointments
(
    appo_id             numeric(5,0) NOT NULL
                        DEFAULT nextval('public.j_appointments_appo_id_seq'::regclass)
                        PRIMARY KEY,
    org_id              numeric(3,0) NOT NULL,                    -- from login
    loc_id              numeric(3,0) NOT NULL,                    -- from login
    con_id              integer      NOT NULL,                    -- from login (staff con_id)
    appmeetmode         character(1) NOT NULL DEFAULT 'D',        -- D = Direct, V = Virtual
    year_id             numeric(8,0) NOT NULL,                    -- financial year, e.g. 20262027
    appo_isclientexist  character(1) NOT NULL DEFAULT 'E',        -- E = existing client, N = new contact
    client_id           numeric(7,0),                             -- set when appo_isclientexist = 'E'
    appo_con_id         numeric(5,0),                             -- contactperson.con_id when appo_isclientexist = 'N'
    appo_rdate          date         NOT NULL DEFAULT CURRENT_DATE, -- record date
    sporgid             numeric(8,0),                             -- logged-in staff_id
    appo_mdate          date         NOT NULL,                    -- meeting date
    appo_time           time without time zone,                   -- meeting time
    appo_duration       integer,                                  -- planned duration, minutes
    appo_remarks        text,                                     -- purpose of the appointment

    -- Outcome
    appacttimespent     time without time zone,                   -- actual time spent (HH:MM)
    appclikeyperson     character varying(60),                    -- key person met
    appisreschedule     character(1) NOT NULL DEFAULT 'N',        -- Y when this meeting was rescheduled
    appreschdate        date,                                     -- the new meeting date
    appo_status         character(1) NOT NULL DEFAULT 'A',        -- A = Active, R = Rescheduled, C = Cancelled
    apptype             character(1) NOT NULL DEFAULT 'A',
    appoactstatus       numeric(1,0) NOT NULL DEFAULT 0,          -- 0 = outcome pending, 1 = outcome recorded

    user_create         character varying(15),
    user_modify         character varying(15),
    user_create_dt      date,
    user_modify_dt      date,
    color               integer DEFAULT 2539510,

    source              character(1) DEFAULT 'M',
    created_at          timestamp with time zone DEFAULT now(),
    updated_at          timestamp with time zone DEFAULT now(),

    CONSTRAINT j_appointments_meetmode_chk  CHECK (appmeetmode IN ('D', 'V')),
    CONSTRAINT j_appointments_isclient_chk  CHECK (appo_isclientexist IN ('E', 'N')),
    CONSTRAINT j_appointments_status_chk    CHECK (appo_status IN ('A', 'R', 'C')),
    CONSTRAINT j_appointments_resched_chk   CHECK (appisreschedule IN ('Y', 'N'))
);

ALTER SEQUENCE public.j_appointments_appo_id_seq OWNED BY public.j_appointments.appo_id;

CREATE INDEX IF NOT EXISTS j_appointments_staff_date_idx
    ON public.j_appointments (sporgid, appo_mdate);

-- Keep updated_at current on every update
CREATE OR REPLACE FUNCTION public.j_appointments_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS j_appointments_updated_at ON public.j_appointments;
CREATE TRIGGER j_appointments_updated_at
    BEFORE UPDATE ON public.j_appointments
    FOR EACH ROW EXECUTE FUNCTION public.j_appointments_set_updated_at();

-- =====================================================
-- Row Level Security (same open policy as the other mobile tables; the app
-- uses its own mbstaff login, not Supabase Auth)
-- =====================================================
ALTER TABLE public.j_appointments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mobile app can manage appointments" ON public.j_appointments;
CREATE POLICY "Mobile app can manage appointments" ON public.j_appointments
    FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON public.j_appointments TO authenticated;
GRANT ALL ON public.j_appointments TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.j_appointments_appo_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.j_appointments_appo_id_seq TO anon;
