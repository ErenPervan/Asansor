-- Migration: Remove overly permissive elevator SELECT policy
-- The policy "Elevators are viewable by authenticated users" (qual = true) 
-- overrides the customer-scoped policy "Elevators: Customers view own".
-- Technicians already have their own SELECT policy.
-- Admins have full access via "Elevators: Admins full access".

DROP POLICY IF EXISTS "Elevators are viewable by authenticated users" ON public.elevators;

-- Verify remaining policies cover all roles:
-- ✅ Admins:      "Elevators: Admins full access"       → ALL (is_admin())
-- ✅ Technicians: "Elevators: Technicians can view all" → SELECT (is_technician())
-- ✅ Customers:   "Elevators: Customers view own"       → SELECT (elevator_id IN profile)
