/**
 * Project Vanguard - Brevo & Cloudflare Environment Diagnostic Endpoint
 * GET /api/diag
 * GET /api/diag?test_to=your-email@domain.com
 * 
 * Safely inspects runtime environment variables and tests Brevo transactional API dispatch.
 */

export async function onRequestGet(context) {
    const { env, request } = context;
    const url = new URL(request.url);
    const testTo = url.searchParams.get("test_to");

    const apiKey = env.BREVO_API_KEY || "";
    const senderEmail = env.BREVO_SENDER_EMAIL || "vanguard@truyens.pro";
    const senderName = env.BREVO_SENDER_NAME || "Vanguard HQ";

    const report = {
        timestamp: new Date().toISOString(),
        cloudflare_env: {
            has_brevo_api_key: Boolean(apiKey),
            brevo_api_key_length: apiKey ? apiKey.length : 0,
            brevo_api_key_prefix: apiKey ? apiKey.substring(0, 10) + "..." : "NONE",
            brevo_sender_email: senderEmail,
            brevo_sender_name: senderName,
            has_db: Boolean(env.DB),
            has_auth_secret: Boolean(env.AUTH_SECRET),
        },
        brevo_test_dispatch: null,
    };

    // If test_to query param is provided, attempt a live transactional send via Brevo
    if (testTo) {
        if (!apiKey) {
            report.brevo_test_dispatch = {
                attempted: false,
                error: "BREVO_API_KEY is not defined in Cloudflare Pages environment variables. Check Pages Dashboard > Settings > Environment Variables > Production.",
            };
        } else {
            try {
                const brevoRes = await fetch("https://api.brevo.com/v3/smtp/email", {
                    method: "POST",
                    headers: {
                        "accept": "application/json",
                        "api-key": apiKey,
                        "content-type": "application/json",
                    },
                    body: JSON.stringify({
                        sender: {
                            name: senderName,
                            email: senderEmail,
                        },
                        to: [
                            {
                                email: testTo,
                                name: "Diagnostic Pilot",
                            },
                        ],
                        subject: `◈ VANGUARD SYSTEM DIAGNOSTIC PING // ${new Date().toISOString()}`,
                        htmlContent: `
                            <div style="font-family: monospace; background: #030712; color: #00e5ff; padding: 20px; border: 1px solid #00e5ff;">
                                <h2>[ PROJECT VANGUARD // BREVO DIAGNOSTIC PING ]</h2>
                                <p>If you are reading this, Brevo API integration and domain routing on <strong>${senderEmail}</strong> are operating successfully!</p>
                                <p>Timestamp: ${new Date().toISOString()}</p>
                            </div>
                        `,
                        textContent: `[ PROJECT VANGUARD // BREVO DIAGNOSTIC PING ]\nSuccessful test dispatch from ${senderEmail} to ${testTo} at ${new Date().toISOString()}`,
                    }),
                });

                const rawBody = await brevoRes.text();
                let parsedBody = null;
                try {
                    parsedBody = JSON.parse(rawBody);
                } catch {
                    parsedBody = rawBody;
                }

                report.brevo_test_dispatch = {
                    attempted: true,
                    target_email: testTo,
                    http_status: brevoRes.status,
                    http_status_text: brevoRes.statusText,
                    success: brevoRes.ok,
                    brevo_response: parsedBody,
                };
            } catch (err) {
                report.brevo_test_dispatch = {
                    attempted: true,
                    target_email: testTo,
                    success: false,
                    exception: err.message,
                };
            }
        }
    }

    return new Response(JSON.stringify(report, null, 2), {
        headers: {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
            "Access-Control-Allow-Origin": "*",
        },
    });
}
