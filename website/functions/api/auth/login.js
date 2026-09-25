/**
 * POST /api/auth/login
 * Authenticates pilot by callsign or email, verifies PBKDF2 hash, and issues token.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    verifyPassword,
    createPilotToken,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured in this environment.", 500);
    }

    let body;
    try {
        body = await request.json();
    } catch {
        return errorResponse("Invalid JSON payload.", 400);
    }

    const identifier = (body.callsign_or_email || body.callsign || body.email || "").trim();
    const password = body.password || "";

    if (!identifier) {
        return errorResponse("Callsign or email is required.", 400);
    }

    if (!password) {
        return errorResponse("Password is required.", 400);
    }

    try {
        // Find pilot by callsign (case-insensitive) or email
        const pilot = await env.DB.prepare(
            `SELECT id, callsign, email, password_hash, salt, rank, squadron, created_at 
             FROM pilots 
             WHERE callsign = ? OR email = ? 
             LIMIT 1`
        )
            .bind(identifier.toUpperCase(), identifier.toLowerCase())
            .first();

        if (!pilot) {
            return errorResponse("Invalid flight callsign or password.", 401);
        }

        // Verify password hash
        const isMatch = await verifyPassword(password, pilot.salt, pilot.password_hash);
        if (!isMatch) {
            return errorResponse("Invalid flight callsign or password.", 401);
        }

        // Fetch pilot combat records
        const record = await env.DB.prepare(
            `SELECT total_sorties, total_kills, total_flight_time_sec, highest_mission_unlocked, updated_at 
             FROM pilot_records 
             WHERE pilot_id = ? 
             LIMIT 1`
        )
            .bind(pilot.id)
            .first();

        // Issue signed Bearer token
        const token = await createPilotToken(
            {
                sub: pilot.id,
                callsign: pilot.callsign,
                rank: pilot.rank,
                squadron: pilot.squadron,
            },
            env.AUTH_SECRET
        );

        return jsonResponse({
            success: true,
            message: `Welcome back, ${pilot.rank} ${pilot.callsign}.`,
            pilot: {
                id: pilot.id,
                callsign: pilot.callsign,
                email: pilot.email,
                rank: pilot.rank,
                squadron: pilot.squadron,
                created_at: pilot.created_at,
                stats: record || {
                    total_sorties: 0,
                    total_kills: 0,
                    total_flight_time_sec: 0,
                    highest_mission_unlocked: "M01",
                },
            },
            token,
        });
    } catch (err) {
        return errorResponse("Authentication error occurred.", 500, err.message);
    }
}
