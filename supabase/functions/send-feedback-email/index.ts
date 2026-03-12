// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts"
import { Resend } from "npm:resend"

const resend = new Resend(Deno.env.get("RESEND_API_KEY"))

Deno.serve(async (req) => {
  try {
    const { message, user_id, device, app_version, created_at } = await req.json()

    await resend.emails.send({
      from: "onboarding@resend.dev",
      to: "smilesnfaces@gmail.com",
      subject: "New Travel Adventure Finder Feedback",
      html: `
        <h2>New Feedback Received</h2>
        <p><strong>Message:</strong></p>
        <p>${message}</p>
        <hr />
        <p><strong>User ID:</strong> ${user_id}</p>
        <p><strong>Device:</strong> ${device}</p>
        <p><strong>App Version:</strong> ${app_version}</p>
        <p><strong>Submitted At:</strong> ${created_at}</p>
      `,
    })

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    )

  } catch (error) {
    console.error("Email send failed:", error)

    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 400 }
    )
  }
})

/*
  After editing:
  1. supabase secrets set RESEND_API_KEY=your_real_key
  2. supabase functions deploy send-feedback-email
*/
