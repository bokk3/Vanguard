/**
 * POST /api/network/heartbeat
 * Heartbeat presence ping for active game clients, mobile HOTAS controllers, and global lobbies.
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

    // Extract real client public WAN IP and edge geolocation from Cloudflare headers
    const clientIp = request.headers.get("cf-connecting-ip") || 
                     request.headers.get("x-real-ip") || 
                     (request.headers.get("x-forwarded-for") || "").split(",")[0].trim() || 
                     "127.0.0.1";
    const country = request.cf?.country || "GLOBAL";
    const city = request.cf?.city || "";
    const colo = request.cf?.colo || "";

    // Parse and augment metadata
    let meta = {};
    if (typeof payload.metadata === "object" && payload.metadata !== null) {
        meta = { ...payload.metadata };
    } else if (typeof payload.metadata === "string") {
        try { meta = JSON.parse(payload.metadata); } catch { meta = {}; }
    }

    // Automatically inject verified WAN connection details
    meta.host_ip = clientIp;
    meta.country = country;
    meta.city = city;
    meta.colo = colo;
    meta.game_port = Number(payload.port || meta.game_port || meta.port || 7777);
    meta.ping_port = Number(payload.ping_port || meta.ping_port || 7778);
    meta.is_public = payload.is_public !== undefined ? Boolean(payload.is_public) : (meta.is_public !== undefined ? Boolean(meta.is_public) : true);
    meta.upnp_active = Boolean(payload.upnp_active !== undefined ? payload.upnp_active : meta.upnp_active);

    const metadataStr = JSON.stringify(meta);

    if (!env.DB) {
        return jsonResponse({
            success: true,
            session_id: sessionId,
            session_type: sessionType,
            host_ip: clientIp,
            country: country,
            colo: colo,
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
            host_ip: clientIp,
            country: country,
            colo: colo,
            status: "alive"
        });
    } catch (err) {
        return errorResponse("Failed to register heartbeat.", 500, err.message);
    }
}
