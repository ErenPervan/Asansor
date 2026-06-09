-- Create webhook to trigger email-sender on new ticket messages
CREATE OR REPLACE FUNCTION trigger_email_sender()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/email-sender',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := row_to_json(NEW)::jsonb
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_email_sender_after_insert
AFTER INSERT ON ticket_messages
FOR EACH ROW
EXECUTE FUNCTION trigger_email_sender();
