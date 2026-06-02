-- Migration: 20260603000002_resolve_conflict_rpc.sql
-- Description: Creates an RPC to securely resolve elevator conflicts with OCC and dynamic updates.

CREATE OR REPLACE FUNCTION public.resolve_elevator_conflict(
  p_conflict_id UUID,
  p_elevator_id UUID,
  p_current_version INT,
  p_payload JSONB
)
RETURNS VOID AS $$
DECLARE
  v_updated_rows INT;
  v_sql TEXT;
  v_key TEXT;
  v_value TEXT;
  v_set_clauses TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- 1. Optimistic Concurrency Control Check
  -- Lock the row for update to ensure no race condition between check and dynamic update
  IF NOT EXISTS (SELECT 1 FROM public.elevators WHERE id = p_elevator_id AND version = p_current_version FOR UPDATE) THEN
    RAISE EXCEPTION 'Concurrency conflict. The elevator record was modified by another user. Please refresh and try again.';
  END IF;

  -- 2. Build dynamic update statement from JSONB payload
  FOR v_key, v_value IN SELECT key, value FROM jsonb_each_text(p_payload) LOOP
    v_set_clauses := array_append(v_set_clauses, format('%I = %L', v_key, v_value));
  END LOOP;

  IF array_length(v_set_clauses, 1) > 0 THEN
    v_set_clauses := array_append(v_set_clauses, format('updated_at = %L', NOW()));
    v_set_clauses := array_append(v_set_clauses, format('version = %s', p_current_version + 1));
    
    v_sql := format('UPDATE public.elevators SET %s WHERE id = %L AND version = %L', 
                    array_to_string(v_set_clauses, ', '), 
                    p_elevator_id, 
                    p_current_version);
    EXECUTE v_sql;
  ELSE
    UPDATE public.elevators 
    SET updated_at = NOW(), version = p_current_version + 1 
    WHERE id = p_elevator_id AND version = p_current_version;
  END IF;

  -- 3. Resolve conflict report
  UPDATE public.conflict_reports
  SET status = 'resolved_forced'
  WHERE id = p_conflict_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
