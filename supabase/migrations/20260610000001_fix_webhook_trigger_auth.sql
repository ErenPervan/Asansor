-- Fix webhook trigger functions: enforce secrets, remove fallbacks, ensure Authorization headers

CREATE OR REPLACE FUNCTION public.notify_technician_on_assignment()
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
  
  SELECT value INTO _anon_key FROM public.app_settings WHERE key = 'anon_key';
  IF _anon_key IS NULL THEN
    RAISE EXCEPTION 'Missing anon_key in app_settings';
  END IF;

  SELECT value INTO _webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  IF _webhook_secret IS NULL THEN
    RAISE EXCEPTION 'Missing webhook_secret in app_settings';
  END IF;

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
  v_anon_key text;
BEGIN
  SELECT value INTO v_webhook_secret FROM public.app_settings WHERE key = 'webhook_secret';
  IF v_webhook_secret IS NULL THEN
    RAISE EXCEPTION 'Missing webhook_secret in app_settings';
  END IF;
  
  SELECT value INTO v_anon_key FROM public.app_settings WHERE key = 'anon_key';
  IF v_anon_key IS NULL THEN
    RAISE EXCEPTION 'Missing anon_key in app_settings';
  END IF;

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
    'Authorization', 'Bearer ' || v_anon_key,
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
