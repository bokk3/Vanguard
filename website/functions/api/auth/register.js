/**
 * POST /api/auth/register
 * Handles pilot registration with PBKDF2 edge password hashing and D1 persistence.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    generateSalt,
    hashPassword,
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

    let { callsign, email, password } = body;

    // 1. Validation
    if (!callsign || typeof callsign !== "string") {
        return errorResponse("Callsign is required.", 400);
    }
    callsign = callsign.trim().toUpperCase();

    if (!/^[A-Z0-9_-]{3,20}$/.test(callsign)) {
        return errorResponse("Callsign must be 3-20 characters and contain only letters, numbers, hyphens, or underscores.", 400);
    }

    if (!email || typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
        return errorResponse("A valid email address is required.", 400);
    }
    email = email.trim().toLowerCase();

    if (!password || typeof password !== "string" || password.length < 8) {
        return errorResponse("Password must be at least 8 characters.", 400);
    }

    const rank = body.rank || "FLIGHT LIEUTENANT";
    const squadron = body.squadron || "404th Vanguard Strike Wing";

    try {
        // 2. Check for duplicate callsign or email
        const existing = await env.DB.prepare(
            "SELECT callsign, email FROM pilots WHERE callsign = ? OR email = ? LIMIT 1"
        )
            .bind(callsign, email)
            .first();

        if (existing) {
            if (existing.callsign.toUpperCase() === callsign) {
                return errorResponse(`Callsign "${callsign}" is already registered by another pilot.`, 409);
            }
            return errorResponse("Email address is already in use.", 409);
        }

        // 3. Cryptographic password hashing (PBKDF2-HMAC-SHA256)
        const salt = generateSalt(16);
        const passwordHash = await hashPassword(password, salt);
        const pilotId = crypto.randomUUID();

        // 4. Atomic insertion into pilots & initial pilot_records
        const batch = await env.DB.batch([
            env.DB.prepare(
                `INSERT INTO pilots (id, callsign, email, password_hash, salt, rank, squadron) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)`
            ).bind(pilotId, callsign, email, passwordHash, salt, rank, squadron),

            env.DB.prepare(
                `INSERT INTO pilot_records (pilot_id, total_sorties, total_kills, highest_mission_unlocked) 
                 VALUES (?, 0, 0, 'M01')`
            ).bind(pilotId),
        ]);

        // 5. Generate secure Pilot Bearer Token (30 days validity)
        const token = await createPilotToken(
            {
                sub: pilotId,
                callsign,
                rank,
                squadron,
            },
            env.AUTH_SECRET
        );

        return jsonResponse(
            {
                success: true,
                message: `Pilot ${callsign} commissioned into the 404th Vanguard Strike Wing.`,
                pilot: {
                    id: pilotId,
                    callsign,
                    email,
                    rank,
                    squadron,
                    created_at: new Date().toISOString(),
                },
                token,
            },
            201
        );
    } catch (err) {
        return errorResponse("Failed to complete pilot registration.", 500, err.message);
    }
}
