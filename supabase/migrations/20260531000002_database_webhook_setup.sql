-- =============================================================================
-- Supabase Database Webhook: notify-technician
-- =============================================================================
-- This script wires the `maintenance_schedules` table to the
-- `notify-technician` Edge Function so that every new task assignment
-- automatically triggers a push notification — with zero client-side code.
--
-- Prerequisites
-- ─────────────────────────────────────────────────────────────────────────────
--   1. The `pg_net` extension must be enabled (it is ON by default on all
--      Supabase projects).  If not, run:
--         CREATE EXTENSION IF NOT EXISTS pg_net;
--
--   2. The `notify-technician` Edge Function must be deployed:
--         supabase functions deploy notify-technician --no-verify-jwt
--
--   3. Replace the two placeholder values below before running:
--        <YOUR_PROJECT_REF>  → your Supabase project reference ID
--                              (found in Settings → General → Reference ID)
--        <YOUR_ANON_KEY>     → your project's anon/public key
--                              (found in Settings → API → Project API keys)
--
-- How to run
-- ─────────────────────────────────────────────────────────────────────────────
--   Option A — Supabase Dashboard SQL Editor:
--     Paste and execute the entire script.
--
--   Option B — Supabase CLI (recommended for version control):
--     supabase db push
--     (place this file in supabase/migrations/ with a timestamp prefix)
--
-- =============================================================================

-- ── 0. Enable the HTTP extension (no-op if already enabled) ──────────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ── 1. Trigger function ───────────────────────────────────────────────────────
--
-- Called AFTER every INSERT on `maintenance_schedules`.
-- Sends the full new row as JSON to the Edge Function via an async HTTP POST.
-- The call is fire-and-forget: pg_net queues the request in the background,
-- so the INSERT itself is never blocked or delayed.
-- =============================================================================

CREATE OR REPLACE FUNCTION notify_technician_on_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- runs with the privileges of the function owner
SET search_path = public  -- prevents search-path injection attacks
AS $$
DECLARE
  _edge_function_url TEXT;
  _anon_key          TEXT;
  _payload           JSONB;
BEGIN
  -- ── Build the Edge Function URL ──────────────────────────────────────────
  -- Replace <YOUR_PROJECT_REF> with your actual Supabase project reference ID.
  _edge_function_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';

  -- ── Authorisation header value ────────────────────────────────────────────
  -- The function is deployed with --no-verify-jwt, but passing the anon key
  -- keeps the call consistent with Supabase conventions and allows you to
  -- re-enable JWT verification later without changing the trigger.
  _anon_key := COALESCE(current_setting('app.settings.anon_key', true), '<eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ1d21yaGFod3Zzb3VoY3h5Y3lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NTEzMjQsImV4cCI6MjA5MTMyNzMyNH0.ylkeV283PxJhF8C_683njSN7SyONrB-WJrC9xs1c-dA>');

  -- ── Wrap the new row in the standard Supabase webhook envelope ────────────
  -- This matches what Supabase native Database Webhooks send, so the Edge
  -- Function can be reused by both this trigger and any future webhook.
  _payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  -- ── Fire the async HTTP POST via pg_net ───────────────────────────────────
  PERFORM net.http_post(
    url     := _edge_function_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _anon_key
    ),
    body    := _payload
  );

  RETURN NEW;
END;
$$;

-- ── 2. Attach the trigger to `maintenance_schedules` ─────────────────────────
--
-- Drop-and-recreate pattern makes this script idempotent (safe to re-run).
-- =============================================================================

DROP TRIGGER IF EXISTS notify_on_schedule_insert ON maintenance_schedules;

CREATE TRIGGER notify_on_schedule_insert
  AFTER INSERT
  ON maintenance_schedules
  FOR EACH ROW
  EXECUTE FUNCTION notify_technician_on_assignment();

-- ── 3. Verification query (optional) ─────────────────────────────────────────
--
-- Run this after applying the script to confirm the trigger is registered:
--
--   SELECT trigger_name, event_manipulation, event_object_table, action_timing
--   FROM information_schema.triggers
--   WHERE event_object_table = 'maintenance_schedules';
--
-- You should see a row for `notify_on_schedule_insert`.
-- =============================================================================
