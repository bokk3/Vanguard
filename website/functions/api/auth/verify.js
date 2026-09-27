/**
 * GET /api/auth/verify?token=...
 * POST /api/auth/verify
 * 
 * Verifies pilot email clearance either via one-click link token (GET)
 * or in-game 6-digit tactical clearance code (POST).
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    verifyPilotToken,
    createPilotToken,
} from "../_utils.js";
import { ensureVerificationSchema } from "../_db_utils.js";
import { verifyVerificationToken } from "../_email.js";

export async function onRequestOptions() {
    return handleOptions();
}

/**
 * One-click email link verification
 */
export async function onRequestGet({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured in this environment.", 500);
    }

    await ensureVerificationSchema(env.DB);

    const url = new URL(request.url);
    const token = url.searchParams.get("token");

    if (!token) {
        return errorResponse("Verification token is required.", 400);
    }

    const payload = await verifyVerificationToken(token, env.AUTH_SECRET);
    if (!payload || !payload.sub) {
        // Redirect to verify page with error
        return Response.redirect(`${url.origin}/verify.html?error=expired_or_invalid`, 302);
    }

    try {
        const pilot = await env.DB.prepare(
            `SELECT id, callsign, email, rank, squadron, email_verified 
             FROM pilots 
             WHERE id = ? LIMIT 1`
        )
            .bind(payload.sub)
            .first();

        if (!pilot) {
            return Response.redirect(`${url.origin}/verify.html?error=pilot_not_found`, 302);
        }

        // Mark as verified and clear temporary code
        await env.DB.prepare(
            `UPDATE pilots 
             SET email_verified = 1, verification_code = NULL, verification_expires_at = NULL 
             WHERE id = ?`
        )
            .bind(pilot.id)
            .run();

        // Issue fresh auth bearer token so pilot is immediately logged in on mobile/web
        const authToken = await createPilotToken(
            {
                sub: pilot.id,
                callsign: pilot.callsign,
                rank: pilot.rank,
                squadron: pilot.squadron,
                email_verified: true,
            },
            env.AUTH_SECRET
        );

        // Redirect to successful clearance confirmation landing page with session token
        return Response.redirect(
            `${url.origin}/verify.html?status=verified&callsign=${encodeURIComponent(pilot.callsign)}&rank=${encodeURIComponent(pilot.rank)}&email=${encodeURIComponent(pilot.email || '')}&authtoken=${encodeURIComponent(authToken)}`,
            302
        );
    } catch (err) {
        console.error("[Verify GET Error]", err);
        return Response.redirect(`${url.origin}/verify.html?error=database_error`, 302);
    }
}

/**
 * In-game or web modal 6-digit code verification
 */
export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured in this environment.", 500);
    }

    await ensureVerificationSchema(env.DB);

    let body = {};
    try {
        body = await request.json();
    } catch {}

    const code = (body.code || "").toString().trim();
    if (!code || code.length !== 6) {
        return errorResponse("A valid 6-digit clearance code is required.", 400);
    }

    // Identify pilot either via Authorization header or email in body
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
        return errorResponse("Pilot authorization token or email is required to verify code.", 401);
    }

    try {
        let pilot;
        if (pilotId) {
            pilot = await env.DB.prepare(
                `SELECT id, callsign, email, rank, squadron, email_verified, verification_code, verification_expires_at 
                 FROM pilots WHERE id = ? LIMIT 1`
            ).bind(pilotId).first();
        } else {
            pilot = await env.DB.prepare(
                `SELECT id, callsign, email, rank, squadron, email_verified, verification_code, verification_expires_at 
                 FROM pilots WHERE email = ? LIMIT 1`
            ).bind(email).first();
        }

        if (!pilot) {
            return errorResponse("Pilot record not found.", 404);
        }

        if (pilot.email_verified === 1) {
            return jsonResponse({
                success: true,
                message: "Flight clearance has already been verified.",
                pilot: {
                    id: pilot.id,
                    callsign: pilot.callsign,
                    email: pilot.email,
                    rank: pilot.rank,
                    squadron: pilot.squadron,
                    email_verified: 1,
                },
            });
        }

        // Verify code match
        if (!pilot.verification_code || pilot.verification_code !== code) {
            return errorResponse("Invalid clearance code. Please re-check your dispatch email.", 400);
        }

        // Verify expiration
        if (pilot.verification_expires_at) {
            const expires = new Date(pilot.verification_expires_at).getTime();
            if (Date.now() > expires) {
                return errorResponse("Clearance code has expired. Please request a new code.", 400, { expired: true });
            }
        }

        // Mark as verified
        await env.DB.prepare(
            `UPDATE pilots 
             SET email_verified = 1, verification_code = NULL, verification_expires_at = NULL 
             WHERE id = ?`
        ).bind(pilot.id).run();

        // Issue fresh token with email_verified: true
        const freshToken = await createPilotToken(
            {
                sub: pilot.id,
                callsign: pilot.callsign,
                rank: pilot.rank,
                squadron: pilot.squadron,
                email_verified: true,
            },
            env.AUTH_SECRET
        );

        return jsonResponse({
            success: true,
            message: `Flight clearance approved for Pilot ${pilot.callsign}. Global Radar and Leaderboard features unlocked.`,
            pilot: {
                id: pilot.id,
                callsign: pilot.callsign,
                email: pilot.email,
                rank: pilot.rank,
                squadron: pilot.squadron,
                email_verified: 1,
            },
            token: freshToken,
        });
    } catch (err) {
        console.error("[Verify POST Error]", err);
        return errorResponse("Failed to verify clearance code.", 500, err.message);
    }
}
