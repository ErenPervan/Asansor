/**
 * Supabase Edge Function: send-notification (v2 — FCM HTTP v1 API)
 *
 * Sends a Firebase Cloud Messaging push notification to a single user.
 * Migrated from the deprecated FCM Legacy HTTP API to the modern HTTP v1 API
 * using OAuth2 service-account authentication.
 *
 * Expected request body (JSON):
 * {
 *   "to_user_id": "<supabase auth uuid>",
 *   "title":      "Notification title",
 *   "body":       "Notification body text",
 *   "data":       { "route": "/home", "elevator_id": "..." }   // optional
 * }
 *
 * Required environment variables (set via Supabase Dashboard → Settings → Edge Functions):
 *   SUPABASE_URL                   – your project URL (auto-injected)
 *   SUPABASE_SERVICE_ROLE_KEY      – service-role key (auto-injected, bypasses RLS)
 *   FIREBASE_SERVICE_ACCOUNT_KEY   – full JSON from Firebase Console →
 *                                    Project Settings → Service Accounts →
 *                                    Generate new private key
 *
 * Deploy:
 *   supabase functions deploy send-notification --no-verify-jwt
 */

/**
 * Manually declare Deno namespace for IDE compatibility.
 */
declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
}

// @ts-ignore: Deno URL import
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
// @ts-ignore: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  loadServiceAccount,
  sendFcmV1Message,
} from "../_shared/fcm_v1.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const bodyPayload = await req.json();
    
    // ── Handle both Direct RPC and Supabase Webhook envelopes ─────────────
    // Webhook shape: { type: "INSERT", table: "notifications", record: { ... } }
    // Direct shape : { to_user_id, title, body, data }
    const isWebhook = !!bodyPayload.record;
    const record = isWebhook ? bodyPayload.record : bodyPayload;

    const toUserId = record.user_id || record.to_user_id;
    const title = record.title;
    const body = record.body;
    const data = record.data_payload || record.data;

    if (!toUserId || !title || !body) {
      console.error("[send-notification] Missing required fields:", { toUserId, title, body });
      return new Response(
        JSON.stringify({ error: "user_id, title and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 1. Look up the target user's FCM token ────────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", toUserId)
      .maybeSingle();

    if (profileError) {
      console.error("[send-notification] Profile lookup failed:", profileError.message);
      return new Response(
        JSON.stringify({ error: "Profile lookup failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!profile?.fcm_token) {
      console.log(`[send-notification] No FCM token for user ${toUserId} — skipping push.`);
      return new Response(
        JSON.stringify({ skipped: true, reason: "No FCM token for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 2. Save notification to database (only if NOT coming from a notifications table webhook) ──
    // If isWebhook is true, we should check if the table is 'notifications'.
    // If it is, we don't need to re-insert.
    if (!isWebhook || bodyPayload.table !== "notifications") {
      const { error: insertError } = await supabase
        .from("notifications")
        .insert({
          user_id: toUserId,
          title,
          body,
          data_payload: data || null,
        });

      if (insertError) {
        console.error("[send-notification] Failed to save notification:", insertError.message);
      }
    }

    // ── 3. Send via FCM HTTP v1 API ───────────────────────────────────────
    const serviceAccount = loadServiceAccount();

    // Ensure all data values are strings (FCM data payload requirement).
    const stringifiedData: Record<string, string> = {};
    if (data && typeof data === "object") {
      for (const [k, v] of Object.entries(data)) {
        stringifiedData[k] = String(v);
      }
    }

    const result = await sendFcmV1Message(
      serviceAccount,
      profile.fcm_token,
      { title, body },
      Object.keys(stringifiedData).length > 0 ? stringifiedData : undefined,
    );

    if (!result.ok) {
      console.error("[send-notification] FCM error:", JSON.stringify(result.body));
    } else {
      console.log("[send-notification] Notification sent to user", toUserId, "✅");
    }

    return new Response(JSON.stringify(result.body), {
      status: result.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[send-notification] Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
