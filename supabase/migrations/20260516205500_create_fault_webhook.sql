-- Create the pg_net extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create the trigger function
CREATE OR REPLACE FUNCTION notify_fault_report()
RETURNS TRIGGER AS $$
DECLARE
  v_url text;
  v_payload jsonb;
  v_headers jsonb;
BEGIN
  -- Construct the webhook payload exactly as Supabase Native Webhooks would
  v_payload := json_build_object(
    'type', 'INSERT',
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', null
  )::jsonb;

  -- Use your project's Edge Function URL.
  -- Update this URL if the project ID changes.
  v_url := 'https://fuwmrhahwvsouhcxycyr.supabase.co/functions/v1/send-notification';
  
  -- The Edge Function `send-notification` is deployed with --no-verify-jwt
  -- and manages its own security via the service_role key to access profiles.
  v_headers := '{"Content-Type": "application/json"}'::jsonb;

  PERFORM net.http_post(
    url := v_url,
    headers := v_headers,
    body := v_payload
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS fault_reports_webhook ON public.fault_reports;

-- Create the trigger on the fault_reports table
CREATE TRIGGER fault_reports_webhook
AFTER INSERT ON public.fault_reports
FOR EACH ROW
EXECUTE FUNCTION notify_fault_report();
