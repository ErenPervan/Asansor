import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req) => {
  try {
    // We expect this to run periodically.
    console.log("SLA Monitor tick started.");

    // 1. Fetch all open/in_progress work orders
    const { data: workOrders, error: fetchError } = await supabase
      .from('work_orders')
      .select('id, priority, status, created_at')
      .in('status', ['open', 'in_progress']);

    if (fetchError) throw fetchError;

    if (!workOrders || workOrders.length === 0) {
      return new Response(JSON.stringify({ message: "No active work orders." }), { headers: { "Content-Type": "application/json" } });
    }

    // 2. Fetch SLA policies
    const { data: policies, error: polError } = await supabase
      .from('sla_policies')
      .select('*');

    if (polError) throw polError;

    const policyMap = new Map();
    for (const p of policies) {
      policyMap.set(p.priority_level, p);
    }

    const now = new Date();
    const breachesToInsert = [];

    // 3. Evaluate each work order
    for (const wo of workOrders) {
      const policy = policyMap.get(wo.priority);
      if (!policy) continue;

      const createdAt = new Date(wo.created_at);
      const minutesElapsed = (now.getTime() - createdAt.getTime()) / (1000 * 60);

      // Check response breach (if still 'open', it means it hasn't been responded to / assigned / in_progress)
      if (wo.status === 'open' && minutesElapsed > policy.max_response_time_minutes) {
        breachesToInsert.push({
          work_order_id: wo.id,
          policy_id: policy.id,
          breach_type: 'response',
        });
      }

      // Check resolution breach
      if (minutesElapsed > policy.max_resolution_time_minutes) {
        breachesToInsert.push({
          work_order_id: wo.id,
          policy_id: policy.id,
          breach_type: 'resolution',
        });
      }
    }

    if (breachesToInsert.length > 0) {
      // Note: In a real app we would check if a breach already exists to avoid duplicate inserts.
      // We can use an upsert or just insert and let unique constraints handle it, but for simplicity:
      // First find existing breaches for these work orders
      const woIds = breachesToInsert.map(b => b.work_order_id);
      const { data: existingBreaches } = await supabase
        .from('sla_breaches')
        .select('work_order_id, breach_type')
        .in('work_order_id', woIds);

      const newBreaches = breachesToInsert.filter(newB => {
        return !existingBreaches?.some(eb => eb.work_order_id === newB.work_order_id && eb.breach_type === newB.breach_type);
      });

      if (newBreaches.length > 0) {
        const { error: insertError } = await supabase.from('sla_breaches').insert(newBreaches);
        if (insertError) throw insertError;
        console.log(`Inserted ${newBreaches.length} new SLA breaches.`);
        
        // FUTURE: Here we can trigger push notifications or emails for escalation.
      }
    }

    return new Response(JSON.stringify({ success: true, checked: workOrders.length }), { headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("SLA Monitor Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
