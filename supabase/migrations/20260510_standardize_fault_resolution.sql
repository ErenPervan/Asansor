-- =============================================================================
-- Migration: Standardize fault_reports resolution tracking columns
-- =============================================================================
-- Ensures `resolved_at` and `resolution_notes` columns exist on ALL
-- environments.  This eliminates the need for defensive fallback logic
-- in FaultRepository.resolveFault() / reopenFault().
--
-- Idempotent: safe to run multiple times thanks to IF NOT EXISTS.
--
-- How to apply
-- ─────────────────────────────────────────────────────────────────────────────
--   Option A — Supabase Dashboard → SQL Editor: paste and execute.
--   Option B — CLI:
--     supabase db push
-- =============================================================================

-- ── 1. Add resolved_at column ─────────────────────────────────────────────────
-- Stores the UTC timestamp of when a fault was marked as resolved.
-- NULL when the fault is open.

ALTER TABLE fault_reports
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- ── 2. Add resolution_notes column ───────────────────────────────────────────
-- Free-text field for the technician to describe what was fixed.

ALTER TABLE fault_reports
  ADD COLUMN IF NOT EXISTS resolution_notes TEXT;

-- ── 3. Backfill existing resolved records ─────────────────────────────────────
-- For any faults that were already marked is_resolved = TRUE but have no
-- resolved_at timestamp, we use reported_at as a best-effort fallback.
-- This ensures historical data is consistent for admin dashboard KPIs.

UPDATE fault_reports
SET resolved_at = reported_at
WHERE is_resolved = TRUE
  AND resolved_at IS NULL;

-- ── 4. Create partial index for resolution queries ───────────────────────────
-- Speeds up dashboard queries that filter on resolved faults (e.g.
-- "average resolution time", "resolved in last 30 days").

CREATE INDEX IF NOT EXISTS idx_fault_reports_resolved_at
  ON fault_reports (resolved_at)
  WHERE resolved_at IS NOT NULL;

-- ── 5. Verification (uncomment to confirm) ───────────────────────────────────
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'fault_reports'
--   AND column_name IN ('resolved_at', 'resolution_notes')
-- ORDER BY column_name;
