-- Migration: add_analytics_rpcs
-- Replaces the client-side keyword classification (C5 fix).
--
-- Two stable RPC functions are exposed to the Flutter client:
--   • get_fault_category_counts()  – returns (category, count) rows
--   • get_monthly_fault_counts(months_back) – returns (year, month, count) rows
--
-- Classification precedence inside get_fault_category_counts:
--   1. If fault_type is non-null and non-empty → use it directly.
--   2. Otherwise fall back to Türkçe keyword matching on description.
--   3. Anything unmatched → 'Diğer'.
--
-- SECURITY INVOKER means the function runs as the calling role, so
-- existing RLS policies on fault_reports are fully honoured.

-- ── 1. Fault category distribution ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_fault_category_counts()
RETURNS TABLE(category text, count int)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    CASE
      WHEN fault_type IS NOT NULL AND fault_type <> '' THEN fault_type
      WHEN lower(description) LIKE '%kapı%'                       THEN 'Kapı Motoru'
      WHEN lower(description) LIKE '%kart%'
        OR lower(description) LIKE '%elektronik%'
        OR lower(description) LIKE '%beyin%'                     THEN 'Anakart / Elektronik'
      WHEN lower(description) LIKE '%halat%'
        OR lower(description) LIKE '%kablo%'                     THEN 'Halat / Kablo'
      WHEN lower(description) LIKE '%kabin%'
        OR lower(description) LIKE '%ışık%'
        OR lower(description) LIKE '%buton%'                     THEN 'Kabin / Buton'
      ELSE 'Diğer'
    END AS category,
    COUNT(*)::int AS count
  FROM fault_reports
  GROUP BY 1
  ORDER BY count DESC;
$$;

-- ── 2. Monthly fault trend (last N months) ───────────────────────────────────

CREATE OR REPLACE FUNCTION get_monthly_fault_counts(months_back int DEFAULT 5)
RETURNS TABLE(year int, month int, count int)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    EXTRACT(YEAR  FROM reported_at)::int AS year,
    EXTRACT(MONTH FROM reported_at)::int AS month,
    COUNT(*)::int                        AS count
  FROM fault_reports
  WHERE reported_at >= date_trunc('month', now()) - (months_back || ' months')::interval
  GROUP BY 1, 2
  ORDER BY 1, 2;
$$;
