-- Fix notification trigger to not rely on extensions.settings which does not exist
-- and fix the anon_key string formatting (remove < >)

CREATE OR REPLACE FUNCTION notify_technician_on_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _edge_function_url TEXT;
  _anon_key          TEXT;
  _payload           JSONB;
BEGIN
  IF NEW.technician_id IS NULL THEN
    RETURN NEW;
  END IF;
  _edge_function_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  _anon_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ1d21yaGFod3Zzb3VoY3h5Y3lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NTEzMjQsImV4cCI6MjA5MTMyNzMyNH0.ylkeV283PxJhF8C_683njSN7SyONrB-WJrC9xs1c-dA';

  -- ── Build a standard notification record payload ──────────────────────────
  _payload := jsonb_build_object(
    'user_id', NEW.technician_id,
    'title',   'Yeni Görev Atandı 🚀',
    'body',    'Bugünkü iş planınıza yeni bir asansör eklendi.',
    'data',    jsonb_build_object(
      'type', 'task_assigned',
      'route', '/home',
      'schedule_id', NEW.id,
      'elevator_id', NEW.elevator_id
    )
  );

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
