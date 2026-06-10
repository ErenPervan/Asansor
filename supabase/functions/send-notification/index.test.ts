import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { handler } from "./index.ts";

const originalFetch = globalThis.fetch;

// A simple fetch mock for Supabase and FCM requests
function mockFetch(mockScenario: "admin" | "technician" | "customer" | "invalid_token" | "valid_webhook") {
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = input.toString();

    // 1. Mock Supabase Auth (getUser)
    if (url.includes("/auth/v1/user")) {
      if (mockScenario === "invalid_token") {
        return new Response(JSON.stringify({ code: 401, msg: "Invalid token" }), { status: 401 });
      }
      // Return a valid user
      return new Response(JSON.stringify({ id: "mock-user-id" }), { status: 200 });
    }

    // 2. Mock Supabase DB (profiles query)
    if (url.includes("/rest/v1/profiles")) {
      if (url.includes("id=eq.mock-user-id") && init?.method === "GET") {
        return new Response(JSON.stringify({ role: mockScenario, fcm_token: "mock-token" }), { status: 200 });
      }
      if (url.includes("role=eq.admin") && init?.method === "GET") {
        return new Response(JSON.stringify([{ fcm_token: "admin-token" }]), { status: 200 });
      }
      if (url.includes("id=eq.target-user-id") && init?.method === "GET") {
        return new Response(JSON.stringify({ fcm_token: "target-token" }), { status: 200 });
      }
      return new Response(JSON.stringify([]), { status: 200 });
    }

    // 3. Mock FCM HTTP v1 API
    if (url.includes("fcm.googleapis.com")) {
      return new Response(JSON.stringify({ name: "projects/mock/messages/123" }), { status: 200 });
    }

    // Google OAuth token fetch mock
    if (url.includes("oauth2/v4/token")) {
      return new Response(JSON.stringify({ access_token: "mock-google-token" }), { status: 200 });
    }

    return new Response("Not Found", { status: 404 });
  };
}

function restoreFetch() {
  globalThis.fetch = originalFetch;
}

// Setup Environment Variables
Deno.env.set("SUPABASE_URL", "https://mock.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-service-role");
Deno.env.set("FIREBASE_SERVICE_ACCOUNT", JSON.stringify({
  client_email: "mock@mock.com",
  private_key: "-----BEGIN PRIVATE KEY-----\nMOCK\n-----END PRIVATE KEY-----",
  project_id: "mock-project"
}));
Deno.env.set("WEBHOOK_SECRET", "secret123");

Deno.test("send-notification - to_role ile admin caller -> 200 OK", async () => {
  mockFetch("admin");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer valid-token", "Content-Type": "application/json" },
    body: JSON.stringify({ to_role: "technician", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 200);
  restoreFetch();
});

Deno.test("send-notification - to_role ile technician caller -> 403 Forbidden", async () => {
  mockFetch("technician");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer valid-token", "Content-Type": "application/json" },
    body: JSON.stringify({ to_role: "technician", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 403);
  restoreFetch();
});

Deno.test("send-notification - to_user_id ile authenticated caller (technician) -> 200 OK", async () => {
  mockFetch("technician");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer valid-token", "Content-Type": "application/json" },
    body: JSON.stringify({ to_user_id: "target-user-id", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 200);
  restoreFetch();
});

Deno.test("send-notification - to_user_id ile customer caller -> 403 Forbidden", async () => {
  mockFetch("customer");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer valid-token", "Content-Type": "application/json" },
    body: JSON.stringify({ to_user_id: "target-user-id", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 403);
  restoreFetch();
});

Deno.test("send-notification - Eksik Authorization header -> 401 Unauthorized", async () => {
  mockFetch("admin");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ to_role: "technician", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 401);
  restoreFetch();
});

Deno.test("send-notification - Geçersiz JWT token -> 401 Unauthorized", async () => {
  mockFetch("invalid_token");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer invalid-token", "Content-Type": "application/json" },
    body: JSON.stringify({ to_role: "technician", title: "Test", body: "Test body" })
  });
  const res = await handler(req);
  assertEquals(res.status, 401);
  restoreFetch();
});

Deno.test("send-notification - Boş body -> 400 Bad Request", async () => {
  mockFetch("admin");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "Authorization": "Bearer valid-token", "Content-Type": "application/json" },
    body: JSON.stringify({}) // missing required fields
  });
  const res = await handler(req);
  assertEquals(res.status, 400);
  restoreFetch();
});

Deno.test("send-notification - Webhook trigger valid secret -> 200 OK", async () => {
  mockFetch("admin"); // valid webhook will fetch admin targets
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "x-webhook-secret": "secret123", "Content-Type": "application/json" },
    body: JSON.stringify({
      type: "INSERT",
      table: "fault_reports",
      record: { id: "f1", description: "Test" }
    })
  });
  const res = await handler(req);
  assertEquals(res.status, 200);
  restoreFetch();
});

Deno.test("send-notification - Webhook trigger invalid secret -> 401 Unauthorized", async () => {
  mockFetch("admin");
  const req = new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "x-webhook-secret": "wrong_secret", "Content-Type": "application/json" },
    body: JSON.stringify({
      type: "INSERT",
      table: "fault_reports",
      record: { id: "f1", description: "Test" }
    })
  });
  const res = await handler(req);
  assertEquals(res.status, 401);
  restoreFetch();
});
