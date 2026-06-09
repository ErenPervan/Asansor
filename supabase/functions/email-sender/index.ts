import { serve } from "https://deno.land/std@0.192.0/http/server.ts";

// Resend API URL
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

serve(async (req) => {
  try {
    const payload = await req.json();
    
    // Check if it's a webhook payload from Supabase
    // e.g. payload.record for the new message or ticket
    const record = payload.record;
    
    if (!record) {
      return new Response(JSON.stringify({ message: "No record found in payload" }), { status: 400 });
    }

    const emailHtml = `
      <h2>Yeni Bir Bildiriminiz Var!</h2>
      <p>Destek talebinizle ilgili yeni bir gelişme var.</p>
      <p><strong>Detay:</strong> ${record.message || record.subject || 'Sistem tarafından güncellendi.'}</p>
      <br/>
      <p>Teşekkürler,<br/>Asansör Bakım Ekibi</p>
    `;

    // Send email using Resend
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "AsansorApp <onboarding@resend.dev>",
        to: "customer@example.com", // In a real app, query the customer profile to get their email
        subject: "Destek Talebi Güncellemesi",
        html: emailHtml,
      }),
    });

    const data = await res.json();

    if (res.ok) {
      console.log("Email sent successfully", data);
      return new Response(JSON.stringify({ success: true, data }), { headers: { "Content-Type": "application/json" } });
    } else {
      console.error("Failed to send email", data);
      return new Response(JSON.stringify({ error: data }), { status: 400, headers: { "Content-Type": "application/json" } });
    }
  } catch (error) {
    console.error("Function error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
