/**
 * POST /api/network/heartbeat
 * Heartbeat presence ping for active game clients, mobile HOTAS controllers, and lobbies.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestPost({ request, env }) {
    let payload = {};
    try {
        payload = await request.json();
    } catch {
        payload = {};
    }

    const sessionId = (payload.session_id || "").trim() || ("sess-" + crypto.randomUUID());
    const callsign = (payload.callsign || "PILOT").trim().toUpperCase();
    const pilotId = payload.pilot_id || null;
    const sessionType = payload.session_type === "LOBBY" ? "LOBBY" : "PILOT";
    const metadataStr = typeof payload.metadata === "object" ? JSON.stringify(payload.metadata) : (payload.metadata || "{}");

    if (!env.DB) {
        return jsonResponse({
            success: true,
            session_id: sessionId,
            session_type: sessionType,
            status: "alive_mock"
        });
    }

    try {
        await env.DB.prepare(`
            INSERT INTO active_sessions (
                session_id, pilot_id, callsign, session_type, metadata, last_heartbeat
            ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(session_id) DO UPDATE SET
                pilot_id = COALESCE(excluded.pilot_id, active_sessions.pilot_id),
                callsign = excluded.callsign,
                session_type = excluded.session_type,
                metadata = excluded.metadata,
                last_heartbeat = CURRENT_TIMESTAMP
        `)
            .bind(sessionId, pilotId, callsign, sessionType, metadataStr)
            .run();

        // 20% probabilistic sweep of expired sessions (> 5 minutes without ping)
        if (Math.random() < 0.2) {
            await env.DB.prepare(`
                DELETE FROM active_sessions 
                WHERE last_heartbeat < datetime('now', '-300 seconds')
            `).run();
        }

        return jsonResponse({
            success: true,
            session_id: sessionId,
            session_type: sessionType,
            status: "alive"
        });
    } catch (err) {
        return errorResponse("Failed to register heartbeat.", 500, err.message);
    }
}
