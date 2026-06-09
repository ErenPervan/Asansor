-- Add idempotency_key to prevent duplicate writes during offline sync
ALTER TABLE public.fault_reports ADD COLUMN IF NOT EXISTS idempotency_key text UNIQUE;
ALTER TABLE public.maintenance_logs ADD COLUMN IF NOT EXISTS idempotency_key text UNIQUE;
