-- =====================================================
-- contactperson: contact person master (prospects / non-client contacts)
--
-- Created from the "New contact" option of the Add meeting screen.
-- mbappointments.appo_con_id holds contactperson.con_id for meetings with
-- appo_isclientexist = 'N'.
--
-- Additions to the original spec (same as the other mobile tables):
--   * PRIMARY KEY on con_id with its own sequence
--   * source / created_at / updated_at for reverse sync
-- =====================================================

CREATE SEQUENCE IF NOT EXISTS public.contactperson_con_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    MAXVALUE 99999          -- con_id is numeric(5,0)
    NO CYCLE;

CREATE TABLE IF NOT EXISTS public.contactperson
(
    con_id      numeric(5,0) NOT NULL
                DEFAULT nextval('public.contactperson_con_id_seq'::regclass)
                PRIMARY KEY,
    org_id      numeric(3,0) NOT NULL,                  -- from login
    loc_id      numeric(3,0) NOT NULL,                  -- from login
    congroup    character varying(20) NOT NULL,         -- from input
    conname     character varying(50) NOT NULL,         -- from input
    contype     character(1) NOT NULL DEFAULT 'I',
    conmobno    numeric(10,0),                          -- from input
    conemail    character varying(40),                  -- from input
    constatus   numeric(1,0) NOT NULL DEFAULT 0,

    source      character(1) DEFAULT 'M',
    created_at  timestamp with time zone DEFAULT now(),
    updated_at  timestamp with time zone DEFAULT now()
);

ALTER SEQUENCE public.contactperson_con_id_seq OWNED BY public.contactperson.con_id;

CREATE INDEX IF NOT EXISTS contactperson_org_name_idx
    ON public.contactperson (org_id, conname);

CREATE OR REPLACE FUNCTION public.contactperson_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS contactperson_updated_at ON public.contactperson;
CREATE TRIGGER contactperson_updated_at
    BEFORE UPDATE ON public.contactperson
    FOR EACH ROW EXECUTE FUNCTION public.contactperson_set_updated_at();

-- Same open policy as the other mobile tables (app uses its own mbstaff login)
ALTER TABLE public.contactperson ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mobile app can manage contact persons" ON public.contactperson;
CREATE POLICY "Mobile app can manage contact persons" ON public.contactperson
    FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON public.contactperson TO authenticated;
GRANT ALL ON public.contactperson TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.contactperson_con_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.contactperson_con_id_seq TO anon;

NOTIFY pgrst, 'reload schema';
