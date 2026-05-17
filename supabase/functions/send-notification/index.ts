/**
 * Supabase Edge Function: send-notification
 *
 * Sends a Firebase Cloud Messaging (FCM) push notification using the modern HTTP v1 API.
 * 
 * Supports two payload formats:
 * 1. Direct App Call:
 * {
 *   "to_user_id": "<supabase auth uuid>",
 *   "title":      "Notification title",
 *   "body":       "Notification body text",
 *   "data":       { "route": "/home", "elevator_id": "..." }
 * }
 *
 * 2. Database Webhook (fault_reports):
 * {
 *   "type": "INSERT",
 *   "table": "fault_reports",
 *   "record": { ... }
 * }
 *
 * Required environment variables:
 *   SUPABASE_URL              – your project URL
 *   SUPABASE_SERVICE_ROLE_KEY – service-role key (bypasses RLS to read fcm_token)
 *   FIREBASE_SERVICE_ACCOUNT  – Firebase Service Account JSON string
 *                               (e.g., supabase secrets set FIREBASE_SERVICE_ACCOUNT='{ "type": "service_account", ... }')
 *
 * Deploy:
 *   supabase functions deploy send-notification --no-verify-jwt
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { JWT } from "npm:google-auth-library@9";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS pre-flight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const reqBody = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    let targets: { fcm_token: string }[] = [];
    let title = "";
    let bodyText = "";
    let notificationData: Record<string, string> = {};

    // ── 1. Check Payload Type & Extract Targets ─────────────────────────────
    if (reqBody.type === "INSERT" && reqBody.table === "fault_reports" && reqBody.record) {
      // It's a Database Webhook trigger
      const record = reqBody.record;
      title = "Yeni Arıza Bildirimi";
      bodyText = record.description || "Yeni bir arıza bildirildi.";
      notificationData = { route: `/fault/${record.id}` };

      // Broadcast to all admins
      const { data: admins, error } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("role", "admin")
        .not("fcm_token", "is", null);

      if (error) {
        console.error("Admin profile lookup failed:", error.message);
        throw error;
      }
      targets = admins || [];
      console.log(`[Webhook] Broadcasting to ${targets.length} admins.`);
    } 
    else if (reqBody.to_user_id && reqBody.title && reqBody.body) {
      // It's a direct API call from the app
      title = reqBody.title;
      bodyText = reqBody.body;
      const rawData = reqBody.data || {};
      
      // Ensure data is all strings (FCM requirement)
      notificationData = Object.fromEntries(
        Object.entries(rawData).map(([k, v]) => [k, String(v)])
      );

      const { data: profile, error } = await supabase
        .from("profiles")
        .select("fcm_token")
        .eq("id", reqBody.to_user_id)
        .maybeSingle();

      if (error) {
        console.error("Profile lookup failed:", error.message);
        throw error;
      }

      if (profile?.fcm_token) {
        targets.push({ fcm_token: profile.fcm_token });
      }
      console.log(`[Direct Call] Target User ${reqBody.to_user_id}. Found token: ${!!profile?.fcm_token}`);
    } 
    else {
      return new Response(
        JSON.stringify({ error: "Invalid payload format." }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    if (targets.length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "No valid FCM tokens found." }),
        { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // ── 2. Generate Google OAuth2 Token for FCM HTTP v1 ─────────────────────
    const saKeyStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!saKeyStr) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing from Supabase environment.");
    }
    
    const serviceAccount = JSON.parse(saKeyStr);

    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    
    const tokens = await jwtClient.getAccessToken();
    const accessToken = tokens.token;
    const projectId = serviceAccount.project_id;

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const results = [];

    // ── 3. Send Notification to Each Target via HTTP v1 ─────────────────────
    for (const target of targets) {
      if (!target.fcm_token) continue;

      const fcmPayload = {
        message: {
          token: target.fcm_token,
          notification: {
            title,
            body: bodyText,
          },
          data: notificationData,
          android: {
            priority: "high",
            notification: {
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "default"
              }
            }
          }
        }
      };

      const fcmResponse = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmPayload),
      });

      const result = await fcmResponse.json();
      results.push(result);
      
      if (!fcmResponse.ok) {
        console.warn(`FCM v1 failed for token ${target.fcm_token}:`, JSON.stringify(result));
      }
    }

    return new Response(JSON.stringify({ success: true, results }), {
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
