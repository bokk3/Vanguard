/**
 * /api/auth/link
 * Manages 6-character Device Link Codes & QR Station Pairing.
 * Allows game stations (PC / TV) to link pilot accounts without typing passwords in-game.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    getAuthenticatedPilot,
    createPilotToken,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

function generateCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // Removed ambiguous I, O, 0, 1
    let code = "ACE-";
    for (let i = 0; i < 3; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

export async function onRequestGet({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    const url = new URL(request.url);
    const code = (url.searchParams.get("code") || "").trim().toUpperCase();

    if (!code) {
        return errorResponse("Link code parameter is required.", 400);
    }

    try {
        const link = await env.DB.prepare(
            `SELECT link_code, pilot_id, approved, token, expires_at 
             FROM device_links 
             WHERE link_code = ? 
             LIMIT 1`
        )
            .bind(code)
            .first();

        if (!link) {
            return errorResponse("Link session not found or expired.", 404);
        }

        const now = new Date();
        const expiresAt = new Date(link.expires_at);

        if (now > expiresAt) {
            await env.DB.prepare("DELETE FROM device_links WHERE link_code = ?").bind(code).run();
            return jsonResponse({ success: false, status: "expired" }, 410);
        }

        if (link.approved === 1 && link.token) {
            // Retrieve pilot callsign & rank
            const pilot = await env.DB.prepare("SELECT callsign, rank FROM pilots WHERE id = ?").bind(link.pilot_id).first();

            // Clean up session once retrieved
            await env.DB.prepare("DELETE FROM device_links WHERE link_code = ?").bind(code).run();

            return jsonResponse({
                success: true,
                status: "approved",
                pilot: pilot || null,
                token: link.token,
            });
        }

        return jsonResponse({
            success: true,
            status: "pending",
            expires_at: link.expires_at,
        });
    } catch (err) {
        return errorResponse("Failed to inspect link session.", 500, err.message);
    }
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    const url = new URL(request.url);
    const action = url.searchParams.get("action") || "request";

    // 1. Station requests a new link code
    if (action === "request") {
        try {
            const linkCode = generateCode();
            const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

            await env.DB.prepare(
                `INSERT INTO device_links (link_code, approved, expires_at) 
                 VALUES (?, 0, ?)`
            )
                .bind(linkCode, expiresAt)
                .run();

            return jsonResponse(
                {
                    success: true,
                    link_code: linkCode,
                    qr_url: `https://project-vanguard.pages.dev/link?code=${linkCode}`,
                    expires_in_sec: 600,
                },
                201
            );
        } catch (err) {
            return errorResponse("Failed to initiate device link session.", 500, err.message);
        }
    }

    // 2. Logged-in pilot on phone/web approves the link code
    if (action === "approve") {
        const auth = await getAuthenticatedPilot(request, env);
        if (!auth) {
            return errorResponse("Unauthorized: Pilot must be logged in to approve station link.", 401);
        }

        let body;
        try {
            body = await request.json();
        } catch {
            return errorResponse("Invalid JSON payload.", 400);
        }

        const code = (body.link_code || "").trim().toUpperCase();
        if (!code) {
            return errorResponse("Link code is required.", 400);
        }

        try {
            const existing = await env.DB.prepare(
                "SELECT link_code, expires_at FROM device_links WHERE link_code = ? LIMIT 1"
            )
                .bind(code)
                .first();

            if (!existing) {
                return errorResponse("Invalid or expired link code.", 404);
            }

            if (new Date() > new Date(existing.expires_at)) {
                await env.DB.prepare("DELETE FROM device_links WHERE link_code = ?").bind(code).run();
                return errorResponse("This link code has expired.", 410);
            }

            // Issue station token for the authenticated pilot
            const stationToken = await createPilotToken(
                {
                    sub: auth.sub,
                    callsign: auth.callsign,
                    rank: auth.rank,
                    device: "game_station",
                },
                env.AUTH_SECRET,
                86400 * 90 // 90 days validity on game station
            );

            await env.DB.prepare(
                `UPDATE device_links 
                 SET approved = 1, pilot_id = ?, token = ? 
                 WHERE link_code = ?`
            )
                .bind(auth.sub, stationToken, code)
                .run();

            return jsonResponse({
                success: true,
                message: `Station approved for Flight Lieutenant ${auth.callsign}.`,
            });
        } catch (err) {
            return errorResponse("Failed to approve device link.", 500, err.message);
        }
    }

    return errorResponse(`Unknown action '${action}'. Valid actions are 'request' or 'approve'.`, 400);
}
