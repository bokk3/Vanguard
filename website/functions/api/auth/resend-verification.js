/**
 * POST /api/auth/resend-verification
 * Re-dispatches flight clearance verification email via Brevo.
 * Rate-limited to 1 dispatch per 90 seconds per pilot.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    verifyPilotToken,
} from "../_utils.js";
import { ensureVerificationSchema } from "../_db_utils.js";
import {
    generateVerificationCode,
    createVerificationToken,
    sendVerificationEmail,
} from "../_email.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured in this environment.", 500);
    }

    await ensureVerificationSchema(env.DB);

    let body = {};
    try {
        body = await request.json();
    } catch {}

    let pilotId = null;
    let email = (body.email || "").toString().trim().toLowerCase();

    const authHeader = request.headers.get("Authorization");
    if (authHeader && authHeader.startsWith("Bearer ")) {
        const token = authHeader.substring(7);
        const verifiedToken = await verifyPilotToken(token, env.AUTH_SECRET);
        if (verifiedToken && verifiedToken.sub) {
            pilotId = verifiedToken.sub;
        }
    }

    if (!pilotId && !email) {
        return errorResponse("Pilot authorization token or email is required.", 401);
    }

    try {
        let pilot;
        if (pilotId) {
            pilot = await env.DB.prepare(
                `SELECT id, callsign, email, rank, squadron, email_verified, verification_expires_at 
                 FROM pilots WHERE id = ? LIMIT 1`
            ).bind(pilotId).first();
        } else {
            pilot = await env.DB.prepare(
                `SELECT id, callsign, email, rank, squadron, email_verified, verification_expires_at 
                 FROM pilots WHERE email = ? LIMIT 1`
            ).bind(email).first();
        }

        if (!pilot) {
            return errorResponse("No pilot registered under this frequency.", 404);
        }

        if (pilot.email_verified === 1) {
            return errorResponse("This pilot account is already verified.", 400);
        }

        // Rate limit: check if a code was issued in the last 90 seconds
        if (pilot.verification_expires_at) {
            const expiresAtMs = new Date(pilot.verification_expires_at).getTime();
            // Default lifetime is 30 mins (1800s); if remaining time > 1710s (i.e. < 90s elapsed), rate limit
            const elapsedSinceIssueSec = (expiresAtMs - Date.now()) / 1000;
            if (elapsedSinceIssueSec > 1710) {
                const waitSec = Math.ceil(elapsedSinceIssueSec - 1710);
                return errorResponse(`Please wait ${waitSec}s before requesting another verification email.`, 429);
            }
        }

        // Generate new code and token
        const newCode = generateVerificationCode();
        const newExpiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
        const verificationToken = await createVerificationToken(pilot.id, pilot.email, env.AUTH_SECRET);

        await env.DB.prepare(
            `UPDATE pilots 
             SET verification_code = ?, verification_expires_at = ? 
             WHERE id = ?`
        ).bind(newCode, newExpiresAt, pilot.id).run();

        // Dispatch via Brevo
        const origin = new URL(request.url).origin;
        const verifyUrl = `${origin}/api/auth/verify?token=${verificationToken}`;
        const emailResult = await sendVerificationEmail(env, {
            email: pilot.email,
            callsign: pilot.callsign,
            code: newCode,
            verifyUrl,
        });

        if (!emailResult.success && !emailResult.simulated) {
            return jsonResponse({
                success: false,
                error: `Brevo dispatch failed: ${emailResult.error || 'Check sender verification in Brevo.'}`,
                verification: {
                    email_sent: false,
                    simulated: false,
                    brevo_error: emailResult.error,
                },
            }, 502);
        }

        return jsonResponse({
            success: true,
            message: emailResult.simulated 
                ? `[SIMULATED] Brevo key not active in environment. Clearance code: ${newCode}`
                : `Verification code dispatched to ${pilot.email}.`,
            verification: {
                email_sent: emailResult.success,
                simulated: Boolean(emailResult.simulated),
                dev_code: emailResult.simulated ? newCode : undefined,
                messageId: emailResult.messageId || undefined,
            },
        });
    } catch (err) {
        console.error("[Resend Error]", err);
        return errorResponse("Failed to re-dispatch verification email.", 500, err.message);
    }
}
