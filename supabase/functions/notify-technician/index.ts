/**
 * [DEPRECATED] notify-technician
 *
 * This function has been deprecated and its logic consolidated into the
 * standardized `send-notification` function.
 *
 * All database triggers now call `send-notification` directly with a unified
 * payload format.
 *
 * See: supabase/database_webhook_setup.sql
 */

// @ts-ignore: Deno URL import
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async () => {
  return new Response(
    JSON.stringify({
      error: "This function is deprecated. Please use 'send-notification' instead.",
    }),
    { status: 410, headers: { "Content-Type": "application/json" } },
  );
});
