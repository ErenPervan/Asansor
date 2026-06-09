-- Set up pg_net and pg_cron for SLA Monitoring
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a wrapper function to call the edge function
CREATE OR REPLACE FUNCTION call_sla_monitor()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- We use pg_net to make an HTTP POST request to our edge function
  -- In production, the URL should be your project's Edge Function URL.
  -- For local, it typically runs on host.docker.internal:54321
  -- We'll just construct a generic call. It fails gracefully if unreachable.
  PERFORM net.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/sla-monitor',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
END;
$$;

-- Schedule the cron job to run every 5 minutes
SELECT cron.schedule(
  'sla-monitor-job',
  '*/5 * * * *',
  'SELECT call_sla_monitor()'
);
