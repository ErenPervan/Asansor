-- Schedule the PM scheduler cron job to run every day at 00:00
CREATE OR REPLACE FUNCTION call_pm_scheduler()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/pm-scheduler',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
END;
$$;

SELECT cron.schedule(
  'pm-scheduler-job',
  '0 0 * * *',
  'SELECT call_pm_scheduler()'
);
