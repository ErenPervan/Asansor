-- 1. Secure the notify_technician_on_assignment trigger
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
  
  -- Add a fallback for local development if the secret isn't set
  _webhook_secret := COALESCE(current_setting('app.settings.webhook_secret', true), 'local-dev-secret-key');

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

-- 2. Secure the notify_fault_report trigger
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
  v_webhook_secret := COALESCE(current_setting('app.settings.webhook_secret', true), 'local-dev-secret-key');
  
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

-- 3. Fix the RLS bypass on the conflicts logic
DROP POLICY IF EXISTS "Technicians can insert their own conflict reports" ON public.conflict_reports;
DROP POLICY IF EXISTS "Technicians can view their own conflict reports" ON public.conflict_reports;

CREATE POLICY "Technicians can insert their own conflict reports"
    ON public.conflict_reports FOR INSERT
    WITH CHECK (
      auth.uid() = technician_id 
      AND public.current_user_role() = 'technician'
    );

CREATE POLICY "Technicians can view their own conflict reports"
    ON public.conflict_reports FOR SELECT
    USING (
      auth.uid() = technician_id
      AND public.current_user_role() = 'technician'
    );
