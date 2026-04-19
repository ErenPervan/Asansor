/**
 * Supabase Edge Function: send-notification
 *
 * Sends a Firebase Cloud Messaging (FCM) push notification to a single user.
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
 *   SUPABASE_URL              – your project URL
 *   SUPABASE_SERVICE_ROLE_KEY – service-role key (bypasses RLS to read fcm_token)
 *   FCM_SERVER_KEY            – Firebase Cloud Messaging server key
 *                               (Firebase Console → Project Settings → Cloud Messaging
 *                                → Cloud Messaging API (Legacy) → Server key)
 *
 * Deploy:
 *   supabase functions deploy send-notification --no-verify-jwt
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { to_user_id, title, body, data } = await req.json();

    if (!to_user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "to_user_id, title and body are required" }),
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
      .eq("id", to_user_id)
      .maybeSingle();

    if (profileError) {
      console.error("Profile lookup failed:", profileError.message);
      return new Response(
        JSON.stringify({ error: "Profile lookup failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!profile?.fcm_token) {
      // User has not granted notification permission or hasn't logged in yet.
      return new Response(
        JSON.stringify({ skipped: true, reason: "No FCM token for user" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 2. Send via FCM Legacy HTTP API ───────────────────────────────────
    const fcmKey = Deno.env.get("FCM_SERVER_KEY")!;

    const fcmPayload = {
      to: profile.fcm_token,
      priority: "high",
      notification: {
        title,
        body,
        sound: "default",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      data: {
        ...(data ?? {}),
        // Ensure all values are strings (FCM data payload requirement).
        ...Object.fromEntries(
          Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
        ),
      },
    };

    const fcmResponse = await fetch(
      "https://fcm.googleapis.com/fcm/send",
      {
        method: "POST",
        headers: {
          Authorization: `key=${fcmKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmResponse.json();

    // FCM returns success:1 on success; log failures for debugging.
    if (fcmResult.failure > 0) {
      console.warn("FCM reported failure:", JSON.stringify(fcmResult));
    }

    return new Response(JSON.stringify(fcmResult), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
