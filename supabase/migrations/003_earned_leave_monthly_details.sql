-- Month-wise Earned Leave Details (Financial Year: Apr -> Mar)
-- Creates:
-- 1) helper function: calculate_leave_working_days(...)
-- 2) RPC function: get_staff_earned_leave_monthly(...)

-- =====================================================
-- Helper: count leave days excluding Sundays and applying half-day tags
-- Tags supported (same pattern as app logic):
-- [First Half], [Second Half], [Start: First Half], [Start: Second Half],
-- [End: First Half], [End: Second Half]
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_leave_working_days(
    p_from_date DATE,
    p_to_date DATE,
    p_remarks TEXT DEFAULT NULL
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_days NUMERIC := 0;
    v_adjustment NUMERIC := 0;
BEGIN
    IF p_from_date IS NULL OR p_to_date IS NULL THEN
        RETURN 0;
    END IF;

    -- Count working days (exclude Sunday = ISO day 7)
    SELECT COUNT(*)::NUMERIC
      INTO v_days
      FROM generate_series(p_from_date, p_to_date, INTERVAL '1 day') AS d
     WHERE EXTRACT(ISODOW FROM d) <> 7;

    IF p_remarks IS NULL OR p_remarks = '' THEN
        RETURN GREATEST(v_days, 0);
    END IF;

    -- Single-day half leave tags
    IF p_remarks LIKE '%[First Half]%' OR p_remarks LIKE '%[Second Half]%' THEN
        IF EXTRACT(ISODOW FROM p_from_date) <> 7 THEN
            v_adjustment := 0.5;
        END IF;
        RETURN GREATEST(v_days - v_adjustment, 0);
    END IF;

    -- Multi-day start/end half tags
    IF p_remarks LIKE '%[Start: First Half]%' OR p_remarks LIKE '%[Start: Second Half]%' THEN
        IF EXTRACT(ISODOW FROM p_from_date) <> 7 THEN
            v_adjustment := v_adjustment + 0.5;
        END IF;
    END IF;

    IF p_remarks LIKE '%[End: First Half]%' OR p_remarks LIKE '%[End: Second Half]%' THEN
        IF EXTRACT(ISODOW FROM p_to_date) <> 7 THEN
            v_adjustment := v_adjustment + 0.5;
        END IF;
    END IF;

    RETURN GREATEST(v_days - v_adjustment, 0);
END;
$$;

-- =====================================================
-- RPC: get month-wise EL details for one staff in a financial year
--
-- Output columns:
-- month_start               DATE
-- month_label               TEXT
-- month_index               INT     -- 1..12 from FY start
-- earned_el_till_month      NUMERIC -- 1 EL earned per month
-- approved_leave_days_month NUMERIC -- approved leave days in that month
-- approved_leave_days_till  NUMERIC -- cumulative approved leave days
-- used_el_month             NUMERIC -- EL consumed in that month
-- lop_month                 NUMERIC -- LOP generated in that month
-- available_el_till_month   NUMERIC -- remaining EL after cumulative usage
-- pending_requests_month    INT
-- approved_requests_month   INT
-- rejected_requests_month   INT
-- =====================================================
CREATE OR REPLACE FUNCTION get_staff_earned_leave_monthly(
    p_staff_id NUMERIC,
    p_fin_year_start DATE DEFAULT NULL
)
RETURNS TABLE (
    month_start DATE,
    month_label TEXT,
    month_index INT,
    earned_el_till_month NUMERIC,
    approved_leave_days_month NUMERIC,
    approved_leave_days_till NUMERIC,
    used_el_month NUMERIC,
    lop_month NUMERIC,
    available_el_till_month NUMERIC,
    pending_requests_month INT,
    approved_requests_month INT,
    rejected_requests_month INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fy_start DATE;
    v_fy_end DATE;
BEGIN
    -- Default FY start (Apr 1): current FY
    IF p_fin_year_start IS NOT NULL THEN
        v_fy_start := p_fin_year_start;
    ELSE
        IF EXTRACT(MONTH FROM CURRENT_DATE) >= 4 THEN
            v_fy_start := make_date(EXTRACT(YEAR FROM CURRENT_DATE)::INT, 4, 1);
        ELSE
            v_fy_start := make_date((EXTRACT(YEAR FROM CURRENT_DATE)::INT - 1), 4, 1);
        END IF;
    END IF;

    v_fy_end := (v_fy_start + INTERVAL '1 year' - INTERVAL '1 day')::DATE;

    RETURN QUERY
    WITH months AS (
        SELECT
            (date_trunc('month', v_fy_start::timestamp) + (g.i * INTERVAL '1 month'))::DATE AS m_start,
            (g.i + 1)::INT AS m_index
        FROM generate_series(0, 11) AS g(i)
    ),
    leave_base AS (
        SELECT
            l.learequest_id,
            l.staff_id,
            l.fromdate::DATE AS from_date,
            l.approval_status,
            calculate_leave_working_days(
                l.fromdate::DATE,
                l.todate::DATE,
                COALESCE(l.leaveremarks, '')
            ) AS leave_days
        FROM learequest l
        WHERE l.staff_id = p_staff_id
          AND l.fromdate::DATE >= v_fy_start
          AND l.fromdate::DATE <= v_fy_end
    ),
    per_month AS (
        SELECT
            date_trunc('month', from_date)::DATE AS m_start,
            COALESCE(SUM(CASE WHEN approval_status = 'A' THEN leave_days ELSE 0 END), 0)::NUMERIC AS approved_days_month,
            COUNT(*) FILTER (WHERE approval_status = 'P')::INT AS pending_count_month,
            COUNT(*) FILTER (WHERE approval_status = 'A')::INT AS approved_count_month,
            COUNT(*) FILTER (WHERE approval_status = 'R')::INT AS rejected_count_month
        FROM leave_base
        GROUP BY date_trunc('month', from_date)::DATE
    ),
    monthly_raw AS (
        SELECT
            m.m_start,
            m.m_index,
            m.m_index::NUMERIC AS earned_till,
            COALESCE(pm.approved_days_month, 0)::NUMERIC AS approved_days_month,
            COALESCE(pm.pending_count_month, 0)::INT AS pending_count_month,
            COALESCE(pm.approved_count_month, 0)::INT AS approved_count_month,
            COALESCE(pm.rejected_count_month, 0)::INT AS rejected_count_month
        FROM months m
        LEFT JOIN per_month pm ON pm.m_start = m.m_start
    ),
    monthly_calc AS (
        SELECT
            mr.*,
            SUM(mr.approved_days_month) OVER (ORDER BY mr.m_start)::NUMERIC AS approved_till
        FROM monthly_raw mr
    )
    SELECT
        mc.m_start AS month_start,
        to_char(mc.m_start, 'Mon YYYY') AS month_label,
        mc.m_index AS month_index,
        mc.earned_till AS earned_el_till_month,
        mc.approved_days_month AS approved_leave_days_month,
        mc.approved_till AS approved_leave_days_till,
        LEAST(
            mc.approved_days_month,
            GREATEST(
                mc.earned_till - (mc.approved_till - mc.approved_days_month),
                0
            )
        )::NUMERIC AS used_el_month,
        GREATEST(
            mc.approved_days_month - LEAST(
                mc.approved_days_month,
                GREATEST(
                    mc.earned_till - (mc.approved_till - mc.approved_days_month),
                    0
                )
            ),
            0
        )::NUMERIC AS lop_month,
        GREATEST(mc.earned_till - mc.approved_till, 0)::NUMERIC AS available_el_till_month,
        mc.pending_count_month AS pending_requests_month,
        mc.approved_count_month AS approved_requests_month,
        mc.rejected_count_month AS rejected_requests_month
    FROM monthly_calc mc
    ORDER BY mc.m_start;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_leave_working_days(DATE, DATE, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_staff_earned_leave_monthly(NUMERIC, DATE) TO authenticated;
