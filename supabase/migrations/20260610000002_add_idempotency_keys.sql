-- Migration: Add idempotency_key to maintenance_logs and fault_reports
-- This prevents duplicate offline records from being inserted on retry

ALTER TABLE public.maintenance_logs 
ADD COLUMN IF NOT EXISTS idempotency_key UUID UNIQUE;

ALTER TABLE public.fault_reports 
ADD COLUMN IF NOT EXISTS idempotency_key UUID UNIQUE;
