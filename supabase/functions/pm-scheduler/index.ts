import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1";

const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req) => {
  try {
    console.log("PM Scheduler tick started.");
    
    // We want to find active schedules whose next_maintenance_date is today or in the past
    // and for which we haven't created a work order yet (we can use idempotency_key or just check open orders).
    
    const today = new Date().toISOString().split('T')[0];

    const { data: schedules, error: schedError } = await supabase
      .from('pm_schedules')
      .select('*, pm_templates(name, description, interval_months)')
      .eq('is_active', true)
      .lte('next_maintenance_date', today);

    if (schedError) throw schedError;

    if (!schedules || schedules.length === 0) {
      return new Response(JSON.stringify({ message: "No PM schedules due." }), { headers: { "Content-Type": "application/json" } });
    }

    const workOrdersToCreate = [];
    const schedulesToUpdate = [];

    for (const schedule of schedules) {
      const template = schedule.pm_templates;
      const idempotencyKey = `PM-${schedule.id}-${schedule.next_maintenance_date}`;
      
      workOrdersToCreate.push({
        elevator_id: schedule.elevator_id,
        assigned_to: schedule.assigned_to,
        title: `Periyodik Bakım: ${template.name}`,
        description: template.description,
        priority: 'medium',
        source: 'schedule',
        source_id: schedule.id,
        idempotency_key: idempotencyKey, // Prevents duplicate creation
      });

      // Calculate next date
      const nextDate = new Date(schedule.next_maintenance_date);
      nextDate.setMonth(nextDate.getMonth() + template.interval_months);

      schedulesToUpdate.push({
        id: schedule.id,
        last_maintenance_date: schedule.next_maintenance_date,
        next_maintenance_date: nextDate.toISOString().split('T')[0],
      });
    }

    // 1. Insert Work Orders
    const { error: insertError } = await supabase.from('work_orders').upsert(workOrdersToCreate, { onConflict: 'idempotency_key' });
    if (insertError) throw insertError;

    // 2. Update Schedules
    for (const update of schedulesToUpdate) {
      await supabase.from('pm_schedules').update(update).eq('id', update.id);
    }

    console.log(`Created ${workOrdersToCreate.length} preventive maintenance work orders.`);

    return new Response(JSON.stringify({ success: true, processed: workOrdersToCreate.length }), { headers: { "Content-Type": "application/json" } });
  } catch (error) {
    console.error("PM Scheduler Error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
