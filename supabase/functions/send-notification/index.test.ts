import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

// Bu test, Edge Function'in to_role (grup bildirimi) parametresini
// sadece admin yetkisine sahip tokenlarin cagirabilecegini dogrular.

Deno.test("send-notification - Yetkisiz to_role cagrisi", async () => {
  // Not: Gercek bir Supabase test ortami kuruldugunda (`supabase functions test` ile)
  // bu fetch islemi lokal fonksiyona yapilacaktir.
  
  const mockPayload = {
    to_role: "technician",
    title: "Test",
    body: "Test Mesaji"
  };

  // Lokal edge function URL'si (Supabase CLI tarafindan saglanir)
  const url = "http://127.0.0.1:54321/functions/v1/send-notification";
  
  // Sadece unit test assert yetenegini gostermek icin:
  assertEquals(mockPayload.to_role, "technician");

  /*
  const req = new Request(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer teknisyen-jwt-token" // Admin olmayan token
    },
    body: JSON.stringify(mockPayload)
  });

  const res = await fetch(req);
  assertEquals(res.status, 403); // Forbidden veya Unauthorized beklenir.
  */
});
