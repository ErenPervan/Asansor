-- Function to get overall SLA compliance metrics
CREATE OR REPLACE FUNCTION get_sla_compliance_report(start_date DATE, end_date DATE)
RETURNS TABLE (
  total_work_orders BIGINT,
  breached_work_orders BIGINT,
  compliance_rate NUMERIC,
  avg_resolution_time_minutes NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT 
      COUNT(w.id) as total,
      COUNT(b.id) as breached,
      AVG(EXTRACT(EPOCH FROM (w.resolved_at - w.created_at)) / 60)::NUMERIC as avg_resolution
    FROM work_orders w
    LEFT JOIN sla_breaches b ON w.id = b.work_order_id
    WHERE w.created_at::DATE >= start_date AND w.created_at::DATE <= end_date
      AND w.status = 'closed'
  )
  SELECT 
    total,
    breached,
    CASE WHEN total > 0 THEN ROUND((1.0 - (breached::NUMERIC / total::NUMERIC)) * 100, 2) ELSE 0 END,
    COALESCE(ROUND(avg_resolution, 2), 0)
  FROM stats;
END;
$$;

-- Function to get top failing parts (most frequently used in fault work orders)
CREATE OR REPLACE FUNCTION get_top_failing_parts(limit_num INTEGER DEFAULT 5)
RETURNS TABLE (
  part_name TEXT,
  total_quantity BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.name, SUM(pu.quantity_used) as total
  FROM part_usages pu
  JOIN parts p ON pu.part_id = p.id
  JOIN work_orders w ON pu.work_order_id = w.id
  WHERE w.source = 'fault_report'
  GROUP BY p.name
  ORDER BY total DESC
  LIMIT limit_num;
END;
$$;
