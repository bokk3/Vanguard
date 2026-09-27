/**
 * Project Vanguard - Brevo (Sendinblue) Transactional Email Dispatcher
 * Sends military-themed pilot commissioning and clearance verification emails
 * using Brevo's REST API (v3/smtp/email).
 * 
 * Free tier: 300 emails/day (9,000/month) with zero credit card required.
 */

const BREVO_API_ENDPOINT = "https://api.brevo.com/v3/smtp/email";
const DEFAULT_SENDER_NAME = "Vanguard HQ";
const DEFAULT_SENDER_EMAIL = "vanguard@truyens.pro";

/**
 * Generates a random 6-digit alphanumeric clearance code (e.g. "749281")
 */
export function generateVerificationCode() {
    return String(Math.floor(100000 + Math.random() * 900000));
}

/**
 * Creates an HMAC-SHA256 signed stateless verification token (24-hour expiration)
 */
export async function createVerificationToken(pilotId, email, secret = "vanguard-strike-wing-404th-secret-key-2026") {
    const expiresAt = Math.floor(Date.now() / 1000) + 86400; // 24 hours
    const payload = JSON.stringify({ sub: pilotId, email, exp: expiresAt });
    const encodedPayload = btoa(payload).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw",
        enc.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );
    
    const sigBuf = await crypto.subtle.sign("HMAC", key, enc.encode(encodedPayload));
    const sigStr = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/, "");
        
    return `${encodedPayload}.${sigStr}`;
}

/**
 * Verifies an HMAC-SHA256 signed verification token
 */
export async function verifyVerificationToken(token, secret = "vanguard-strike-wing-404th-secret-key-2026") {
    if (!token || typeof token !== "string") return null;
    const parts = token.split(".");
    if (parts.length !== 2) return null;
    
    const [encodedPayload, sigStr] = parts;
    
    try {
        const enc = new TextEncoder();
        const key = await crypto.subtle.importKey(
            "raw",
            enc.encode(secret),
            { name: "HMAC", hash: "SHA-256" },
            false,
            ["sign"]
        );
        
        const expectedSigBuf = await crypto.subtle.sign("HMAC", key, enc.encode(encodedPayload));
        const expectedSigStr = btoa(String.fromCharCode(...new Uint8Array(expectedSigBuf)))
            .replace(/\+/g, "-")
            .replace(/\//g, "_")
            .replace(/=+$/, "");
            
        if (sigStr !== expectedSigStr) {
            return null; // Signature mismatch
        }
        
        // Decode payload
        let rawPayload = encodedPayload.replace(/-/g, "+").replace(/_/g, "/");
        while (rawPayload.length % 4) rawPayload += "=";
        const payload = JSON.parse(atob(rawPayload));
        
        const now = Math.floor(Date.now() / 1000);
        if (payload.exp && payload.exp < now) {
            return null; // Expired
        }
        
        return payload;
    } catch {
        return null;
    }
}

/**
 * Sends a clearance verification email via Brevo REST API.
 * If BREVO_API_KEY is not configured in env, logs cleanly and returns a simulated success.
 */
export async function sendVerificationEmail(env, { email, callsign, code, verifyUrl }) {
    const apiKey = env.BREVO_API_KEY;
    const senderEmail = env.BREVO_SENDER_EMAIL || DEFAULT_SENDER_EMAIL;
    const senderName = env.BREVO_SENDER_NAME || DEFAULT_SENDER_NAME;

    if (!apiKey) {
        console.warn("[Vanguard Auth] BREVO_API_KEY is not configured. Email delivery simulated for:", email, "Code:", code);
        return {
            success: true,
            simulated: true,
            code,
            reason: "BREVO_API_KEY environment variable not set. Code logged for testing.",
        };
    }

    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Vanguard Flight Clearance Verification</title>
</head>
<body style="margin: 0; padding: 0; background-color: #030712; font-family: 'Courier New', Courier, monospace; color: #f3f4f6;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #030712; padding: 40px 15px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px; background-color: #090e17; border: 1px solid #1f293d; border-radius: 8px; overflow: hidden; box-shadow: 0 0 30px rgba(0, 229, 255, 0.15);">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(90deg, #091322 0%, #0d233a 100%); padding: 24px 30px; border-bottom: 2px solid #00e5ff;">
              <table width="100%">
                <tr>
                  <td>
                    <div style="color: #ffd700; font-size: 11px; letter-spacing: 2px; font-weight: bold; margin-bottom: 4px;">// 404TH VANGUARD STRIKE WING //</div>
                    <div style="color: #ffffff; font-size: 22px; font-weight: bold; letter-spacing: 1px;">PROJECT VANGUARD</div>
                  </td>
                  <td align="right">
                    <span style="display: inline-block; background-color: rgba(0, 229, 255, 0.15); border: 1px solid #00e5ff; color: #00e5ff; font-size: 10px; padding: 4px 8px; border-radius: 4px; font-weight: bold; letter-spacing: 1px;">CLEARANCE PROTOCOL</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Tactical Body -->
          <tr>
            <td style="padding: 35px 30px;">
              <p style="color: #00e5ff; font-size: 13px; letter-spacing: 1px; margin: 0 0 16px 0; text-transform: uppercase;">
                ▶ DISPATCH: COMMISSION VERIFICATION // PILOT: ${callsign}
              </p>
              
              <p style="color: #d1d5db; font-size: 14px; line-height: 1.6; margin: 0 0 24px 0;">
                Greetings, Pilot <strong>${callsign}</strong>. Your commission into the 404th Vanguard Strike Wing has been provisioned. To unlock full access to the <strong>Global P2P Radar</strong> and submit verified records to the <strong>Global Fleet Leaderboard</strong>, verify your military frequency below.
              </p>

              <!-- 6-Digit In-Game & Web Code Card -->
              <div style="background-color: #030712; border: 1px solid #00e5ff; border-radius: 6px; padding: 20px; text-align: center; margin: 0 0 24px 0;">
                <div style="color: #9ca3af; font-size: 11px; letter-spacing: 2px; margin-bottom: 8px;">6-DIGIT CLEARANCE CODE (WEB PORTAL &amp; CLIENT)</div>
                <div style="color: #ffd700; font-size: 34px; font-weight: bold; letter-spacing: 8px; font-family: monospace;">${code}</div>
                <div style="color: #6b7280; font-size: 10px; margin-top: 6px;">CODE VALID FOR 30 MINUTES</div>
              </div>

              <!-- Direct Copyable Clearance URL Box (No a-href to avoid Brevo tracking domain SSL rewrite) -->
              <div style="background-color: #030712; border: 1px solid #1f293d; border-radius: 6px; padding: 16px 20px; margin: 0 0 24px 0; text-align: left;">
                <div style="color: #00e5ff; font-size: 11px; font-weight: bold; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 8px;">
                  ▶ DIRECT CLEARANCE URL (COPY &amp; PASTE INTO BROWSER):
                </div>
                <div style="background-color: #091322; border: 1px solid rgba(0, 229, 255, 0.25); border-radius: 4px; padding: 12px; font-family: monospace; font-size: 12px; color: #38bdf8; word-break: break-all; user-select: all; -webkit-user-select: all;">
                  ${verifyUrl}
                </div>
                <div style="color: #6b7280; font-size: 10px; margin-top: 8px; line-height: 1.4;">
                  Copy and paste the URL above into your browser address bar to verify instantly, or enter the 6-digit clearance code directly at <span style="color: #9ca3af; font-family: monospace;">project-vanguard.pages.dev/verify.html</span>.
                </div>
              </div>

              <div style="border-top: 1px solid #1f293d; padding-top: 18px; margin-top: 24px;">
                <p style="color: #9ca3af; font-size: 11px; line-height: 1.5; margin: 0;">
                  This is an automated transactional verification message for your Project Vanguard account (${email}). If you did not initiate this registration, please disregard.
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #050a12; padding: 16px 30px; border-top: 1px solid #1f293d; text-align: center; color: #6b7280; font-size: 10px; letter-spacing: 0.5px;">
              Project Vanguard &bull; Sol Orbital Operations &bull; Vanguard HQ (vanguard@truyens.pro)
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
    `;

    const textContent = `
[ PROJECT VANGUARD - 404TH STRIKE WING ]
COMMISSION VERIFICATION FOR PILOT: ${callsign}

Your 6-digit clearance code is: ${code}
(Valid for 30 minutes in the Vanguard game client and web portal)

Or verify your flight clearance directly online:
${verifyUrl}

// PROJECT VANGUARD FLEET COMMAND //
    `.trim();

    try {
        const res = await fetch(BREVO_API_ENDPOINT, {
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
                replyTo: {
                    name: senderName,
                    email: senderEmail,
                },
                to: [
                    {
                        email: email,
                        name: callsign,
                    },
                ],
                subject: `Project Vanguard - Verification Code: ${code} [${callsign}]`,
                htmlContent: htmlContent,
                textContent: textContent,
            }),
        });

        if (!res.ok) {
            const errBody = await res.text();
            console.error("[Brevo API Error]", res.status, errBody);
            return {
                success: false,
                status: res.status,
                error: errBody,
            };
        }

        const data = await res.json();
        return {
            success: true,
            messageId: data.messageId,
        };
    } catch (err) {
        console.error("[Brevo Fetch Exception]", err);
        return {
            success: false,
            error: err.message,
        };
    }
}
