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

export const handler = async (req: Request) => {
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
    if (reqBody.type === "INSERT" && reqBody.record) {
      // It's a Database Webhook trigger
      
      // Verify Webhook Secret
      const secretHeader = req.headers.get("x-webhook-secret");
      const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
      if (!expectedSecret) {
        console.error("WEBHOOK_SECRET environment variable is not configured.");
        return new Response(
          JSON.stringify({ error: "Server misconfiguration: webhook secret not set." }),
          { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
      if (secretHeader !== expectedSecret) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Invalid webhook secret." }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      if (reqBody.table === "fault_reports") {
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
      } else if (reqBody.table === "maintenance_schedules") {
        const record = reqBody.record;
        title = "Yeni Bakım Görevi";
        bodyText = "Size yeni bir asansör bakım görevi atandı.";
        notificationData = { route: `/home` };

        const { data: tech, error } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("id", record.technician_id)
          .maybeSingle();
        
        if (error) {
          console.error("Technician lookup failed:", error.message);
          throw error;
        }
        
        if (tech?.fcm_token) {
          targets.push({ fcm_token: tech.fcm_token });
        }
        console.log(`[Webhook] Sending to technician ${record.technician_id}. Found: ${!!tech?.fcm_token}`);
      } else {
        return new Response(
          JSON.stringify({ error: `Unsupported webhook table: ${reqBody.table}` }),
          { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }
    }
    else if ((reqBody.to_user_id || reqBody.to_role) && reqBody.title && reqBody.body) {
      // Direct App Call — MUST verify the caller is an authenticated Supabase user
      const authHeader = req.headers.get("Authorization");
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Missing or invalid Authorization header." }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      // Verify the JWT using Supabase auth
      const callerToken = authHeader.replace("Bearer ", "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(callerToken);
      if (authError || !user) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Invalid token." }),
          { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      // ── Caller Role Check ─────────────────────────────────────────────────
      const { data: callerProfile, error: profileError } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();

      if (profileError || !callerProfile) {
        return new Response(
          JSON.stringify({ error: "Unauthorized: Caller profile not found." }),
          { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      const callerRole = callerProfile.role;

      // to_role ile toplu bildirim sadece admin gönderebilir
      if (reqBody.to_role && callerRole !== "admin") {
        return new Response(
          JSON.stringify({ error: "Forbidden: Only admins can send role-targeted notifications." }),
          { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      // to_user_id ile bireysel bildirim: admin her zaman gönderebilir,
      // teknisyen sadece kendi müşterilerine (veya adminlere) gönderebilir
      if (reqBody.to_user_id && callerRole === "customer") {
        return new Response(
          JSON.stringify({ error: "Forbidden: Customers cannot send direct notifications." }),
          { status: 403, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
        );
      }

      // It's a direct API call from the app
      title = reqBody.title;
      bodyText = reqBody.body;
      const rawData = reqBody.data || {};

      // Ensure data is all strings (FCM requirement)
      notificationData = Object.fromEntries(
        Object.entries(rawData).map(([k, v]) => [k, String(v)])
      );

      if (reqBody.to_role) {
        const { data: profiles, error } = await supabase
          .from("profiles")
          .select("fcm_token")
          .eq("role", reqBody.to_role)
          .not("fcm_token", "is", null);

        if (error) {
          console.error("Profile lookup by role failed:", error.message);
          throw error;
        }

        targets = profiles || [];
        console.log(`[Direct Call] Target Role ${reqBody.to_role}. Found tokens: ${targets.length}`);
      } else if (reqBody.to_user_id) {
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
    if (Deno.env.get("IS_TEST") === "true") {
      return new Response(JSON.stringify({ success: true, results: [{ mocked: true }] }), {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

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

        // Evict stale/unregistered tokens so they don't accumulate in the DB.
        // FCM HTTP v1 uses nested error details with an errorCode field.
        const errorCode: string =
          result?.error?.details?.[0]?.errorCode ??
          result?.error?.status ??
          "";
        const isStaleToken =
          errorCode === "UNREGISTERED" ||
          errorCode === "NOT_FOUND" ||
          (result?.error?.message ?? "").includes("not a valid FCM registration token");

        if (isStaleToken) {
          console.log(`[FCM] Evicting stale token: ${target.fcm_token.substring(0, 20)}...`);
          await supabase
            .from("profiles")
            .update({ fcm_token: null })
            .eq("fcm_token", target.fcm_token);
        }
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
};

serve(handler);
