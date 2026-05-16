/**
 * Manually declare Deno namespace for IDE compatibility in shared files.
 * This satisfies the TypeScript compiler when the Deno extension is not active.
 */
declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
  };
}

/**
 * Shared FCM HTTP v1 API helper module.
 *
 * Both `send-notification` and `notify-technician` edge functions import
 * from this file to eliminate duplication of OAuth2 / JWT / FCM logic.
 *
 * Required Supabase secret:
 *   FIREBASE_SERVICE_ACCOUNT_KEY — full JSON from Firebase Console →
 *     Project Settings → Service Accounts → Generate new private key.
 */

// ── Base64-URL Helpers ────────────────────────────────────────────────────────

/** Base64-URL encode an ArrayBuffer or Uint8Array (no padding). */
export function base64url(buf: ArrayBuffer | Uint8Array): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/** UTF-8 string → Base64-URL. */
export function base64urlStr(str: string): string {
  return base64url(new TextEncoder().encode(str));
}

// ── OAuth2 / JWT ──────────────────────────────────────────────────────────────

/**
 * Builds a signed RS256 JWT suitable for the Google OAuth2 token endpoint.
 *
 * Asserts the `https://www.googleapis.com/auth/firebase.messaging` scope
 * so the resulting access token can call the FCM HTTP v1 API.
 */
export async function buildSignedJwt(
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
export async function fetchAccessToken(
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

// ── Service Account ───────────────────────────────────────────────────────────

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/**
 * Loads and parses the `FIREBASE_SERVICE_ACCOUNT_KEY` secret.
 * Throws a descriptive error if the secret is missing.
 */
export function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");
  if (!raw) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_KEY secret is not configured. " +
        "Go to Supabase Dashboard → Settings → Edge Functions → Add secret.",
    );
  }
  return JSON.parse(raw) as ServiceAccount;
}

// ── FCM v1 Send ───────────────────────────────────────────────────────────────

export interface FcmSendResult {
  ok: boolean;
  status: number;
  body: unknown;
}

/**
 * Sends a single push notification via the FCM HTTP v1 API.
 *
 * Handles OAuth2 token acquisition, Android/iOS platform config,
 * and returns the raw FCM response.
 */
export async function sendFcmV1Message(
  sa: ServiceAccount,
  fcmToken: string,
  notification: { title: string; body: string },
  data?: Record<string, string>,
): Promise<FcmSendResult> {
  const accessToken = await fetchAccessToken(sa.client_email, sa.private_key);

  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const payload = {
    message: {
      token: fcmToken,
      notification,
      // Android-specific overrides
      android: {
        priority: "high" as const,
        notification: {
          sound: "default",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          channel_id: "asansor_notifications",
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
      ...(data && Object.keys(data).length > 0 ? { data } : {}),
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const body = await res.json();
  return { ok: res.ok, status: res.status, body };
}
