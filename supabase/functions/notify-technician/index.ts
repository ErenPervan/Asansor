/**
 * Supabase Edge Function: notify-technician
 *
 * Automatically fires whenever a new row is inserted into `maintenance_schedules`.
 * It looks up the assigned technician's FCM token and sends a push notification
 * via the FCM HTTP v1 API (OAuth 2.0 — NOT the deprecated legacy key).
 *
 * ── How to set the required secret ──────────────────────────────────────────
 *
 *   FIREBASE_SERVICE_ACCOUNT_KEY
 *   ┌─────────────────────────────────────────────────────────────────────┐
 *   │ 1. Open Firebase Console → Project Settings → Service Accounts tab. │
 *   │ 2. Click "Generate new private key" → confirm → download the JSON.  │
 *   │ 3. Supabase Dashboard → Settings → Edge Functions → Add secret:     │
 *   │      Name : FIREBASE_SERVICE_ACCOUNT_KEY                            │
 *   │      Value: (paste the entire contents of the downloaded JSON file) │
 *   └─────────────────────────────────────────────────────────────────────┘
 *
 *   SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically
 *   by the Supabase runtime — do NOT set them manually.
 *
 * ── Deploy ───────────────────────────────────────────────────────────────────
 *   supabase functions deploy notify-technician --no-verify-jwt
 *
 * ── Webhook payload shape ────────────────────────────────────────────────────
 *   Supabase Database Webhooks POST:
 *     { "type": "INSERT", "table": "maintenance_schedules", "record": { … } }
 *   pg_net can be configured to send just the NEW row directly.
 *   This function handles both shapes.
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Notification copy ─────────────────────────────────────────────────────────

const NOTIFICATION_TITLE = "Yeni Görev Atandı 🚀";
const NOTIFICATION_BODY = "Bugünkü iş planınıza yeni bir asansör eklendi.";

// ── CORS (required if the function is ever invoked from a browser) ────────────

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── OAuth 2.0 / JWT helpers ───────────────────────────────────────────────────

/** Base64-URL encode an ArrayBuffer. */
function base64url(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** UTF-8 string → Base64-URL. */
function base64urlStr(str: string): string {
  return base64url(new TextEncoder().encode(str));
}

/**
 * Builds a signed RS256 JWT suitable for the Google OAuth2 token endpoint.
 *
 * The JWT asserts that the service account is requesting the
 * `https://www.googleapis.com/auth/firebase.messaging` scope.
 */
async function buildSignedJwt(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = base64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64urlStr(
    JSON.stringify({
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${payload}`;

  // Strip PEM armor and decode the PKCS#8 DER bytes.
  const pemBody = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const keyDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64url(signature)}`;
}

/**
 * Exchanges a signed service-account JWT for a short-lived Google OAuth2
 * access token that authorises FCM HTTP v1 API calls.
 */
async function fetchAccessToken(
  clientEmail: string,
  privateKeyPem: string,
): Promise<string> {
  const jwt = await buildSignedJwt(clientEmail, privateKeyPem);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`OAuth2 token exchange failed (${res.status}): ${detail}`);
  }

  const json = await res.json();
  return json.access_token as string;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // ── Step 1: Parse the incoming webhook payload ────────────────────────────
    //
    // Supabase Database Webhooks wrap the row:
    //   { type, table, record: { id, technician_id, elevator_id, … } }
    //
    // pg_net can be configured to send just the NEW row directly.
    // We handle both shapes transparently.
    const body = await req.json();
    const record: Record<string, unknown> = body.record ?? body;

    const technicianId = record.technician_id as string | undefined;
    const elevatorId = record.elevator_id as string | undefined;
    const scheduleId = record.id as string | undefined;

    if (!technicianId) {
      console.warn("[notify-technician] No technician_id in payload — skipping.");
      return new Response(
        JSON.stringify({ skipped: true, reason: "no technician_id" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // ── Step 2: Retrieve the technician's FCM token from `profiles` ───────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // bypasses RLS
    );

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", technicianId)
      .maybeSingle();

    if (profileError) {
      console.error("[notify-technician] Profile lookup error:", profileError.message);
      return new Response(
        JSON.stringify({ error: "Profile lookup failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!profile?.fcm_token) {
      // The technician hasn't granted notification permission or hasn't
      // logged in on a device yet — silently skip.
      console.log(
        `[notify-technician] No FCM token for technician ${technicianId} — skipping.`,
      );
      return new Response(
        JSON.stringify({ skipped: true, reason: "no fcm_token" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // ── Step 3: Get an OAuth2 access token via the service account ────────────
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
    if (!serviceAccountJson) {
      // Fail loudly so the missing secret is easy to diagnose in function logs.
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_KEY secret is not configured. " +
          "Go to Supabase Dashboard → Settings → Edge Functions → Add secret.",
      );
    }

    const serviceAccount = JSON.parse(serviceAccountJson) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };

    const accessToken = await fetchAccessToken(
      serviceAccount.client_email,
      serviceAccount.private_key,
    );

    // ── Step 4: Send the push notification via FCM HTTP v1 API ───────────────
    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const fcmPayload = {
      message: {
        token: profile.fcm_token,
        notification: {
          title: NOTIFICATION_TITLE,
          body: NOTIFICATION_BODY,
        },
        // Android-specific overrides
        android: {
          priority: "high",
          notification: {
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            channel_id: "asansor_notifications", // must match the channel in NotificationService
          },
        },
        // iOS-specific overrides
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        // Custom data payload — available in Flutter via message.data
        data: {
          type: "task_assigned",
          route: "/home",
          ...(scheduleId ? { schedule_id: String(scheduleId) } : {}),
          ...(elevatorId ? { elevator_id: String(elevatorId) } : {}),
        },
      },
    };

    const fcmResponse = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmPayload),
    });

    const fcmResult = await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error("[notify-technician] FCM error:", JSON.stringify(fcmResult));
      return new Response(JSON.stringify(fcmResult), {
        status: fcmResponse.status,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    console.log(
      `[notify-technician] Notification sent for schedule ${scheduleId} ✅`,
    );

    return new Response(JSON.stringify(fcmResult), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("[notify-technician] Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      },
    );
  }
});
