-- Create settings table to store webhook secret securely without requiring superuser database parameters
CREATE TABLE IF NOT EXISTS public.app_settings (
    key text PRIMARY KEY,
    value text NOT NULL
);

-- Enable RLS to prevent unauthorized access
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Note: We define NO policies on this table, which means only superusers/postgres/service_role can read or write to it.
-- The trigger functions run with SECURITY DEFINER (as creator/postgres) so they can read this table successfully.

-- Update notify_technician_on_assignment to read from public.app_settings
CREATE OR REPLACE FUNCTION notify_technician_on_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  _edge_function_url TEXT;
  _anon_key          TEXT;
  _webhook_secret    TEXT;
  _payload           JSONB;
BEGIN
  _edge_function_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  _anon_key := COALESCE(current_setting('app.settings.anon_key', true), '<YOUR_ANON_KEY>');
  
  SELECT value INTO _webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  _webhook_secret := COALESCE(_webhook_secret, 'local-dev-secret-key');

  _payload := jsonb_build_object(
    'type',   'INSERT',
    'table',  TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW)::jsonb
  );

  PERFORM net.http_post(
    url     := _edge_function_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _anon_key,
      'x-webhook-secret', _webhook_secret
    ),
    body    := _payload
  );

  RETURN NEW;
END;
$$;

-- Update notify_fault_report to read from public.app_settings
CREATE OR REPLACE FUNCTION public.notify_fault_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net
AS $$
DECLARE
  v_url text;
  v_payload jsonb;
  v_headers jsonb;
  v_webhook_secret text;
BEGIN
  SELECT value INTO v_webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  v_webhook_secret := COALESCE(v_webhook_secret, 'local-dev-secret-key');
  
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', null
  )::jsonb;

  v_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  
  v_headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'x-webhook-secret', v_webhook_secret
  );

  PERFORM net.http_post(
    url := v_url,
    headers := v_headers,
    body := v_payload
  );

  RETURN NEW;
END;
$$;
