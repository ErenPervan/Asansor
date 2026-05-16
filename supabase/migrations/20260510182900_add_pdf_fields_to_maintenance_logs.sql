-- =============================================================================
-- Migration: Add PDF & Customer Signature fields to maintenance_logs
-- Date: 2026-05-10
-- =============================================================================
-- Adds two new nullable URL columns to store the generated PDF report
-- and the building representative's signature image in Supabase Storage.
-- =============================================================================

ALTER TABLE public.maintenance_logs
  ADD COLUMN IF NOT EXISTS pdf_url TEXT,
  ADD COLUMN IF NOT EXISTS customer_signature_url TEXT;

COMMENT ON COLUMN public.maintenance_logs.pdf_url IS
  'Public URL of the generated PDF maintenance report in Supabase Storage (maintenance_reports bucket).';

COMMENT ON COLUMN public.maintenance_logs.customer_signature_url IS
  'Public URL of the building representative signature image in Supabase Storage.';
