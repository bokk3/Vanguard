/**
 * POST /api/network/heartbeat
 * Presence ping for game clients, website visitors and internet lobbies.
 *
 * A session belongs to the public IP that created it. Later heartbeats for the
 * same session_id from a different IP are refused (409) until the session has
 * expired, so a session_id read from the public lobby list can't be used to
 * redirect or overwrite someone else's lobby.
 *
 * pilot_id comes from the Bearer token if one is sent. A pilot_id in the body
 * is ignored.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    getAuthenticatedPilot,
    clientIpOf,
} from "../_utils.js";

const SESSION_ID_RE = /^[A-Za-z0-9_-]{8,64}$/;
const MAX_CALLSIGN = 24;
const MAX_TEXT = 48;
const SESSION_EXPIRY = "-300 seconds";

function cleanText(value, maxLen, fallback = "") {
    if (typeof value !== "string") return fallback;
    // Strip control characters and trim to length.
    const s = value.replace(/[\u0000-\u001f\u007f]/g, "").trim();
    return s ? s.slice(0, maxLen) : fallback;
}

function clampInt(value, min, max, fallback) {
    const n = parseInt(value, 10);
    if (!Number.isFinite(n)) return fallback;
    return Math.min(max, Math.max(min, n));
}

function parseMetadata(raw) {
    if (raw && typeof raw === "object" && !Array.isArray(raw)) return raw;
    if (typeof raw === "string" && raw.length <= 4096) {
        try {
            const parsed = JSON.parse(raw);
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed;
        } catch {
            // fall through
        }
    }
    return {};
}

async function pilotIdFrom(request, env) {
    try {
        const auth = await getAuthenticatedPilot(request, env);
        return auth ? String(auth.sub) : null;
    } catch {
        // A misconfigured AUTH_SECRET shouldn't take presence down with it.
        return null;
    }
}

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
    if (!payload || typeof payload !== "object") payload = {};

    let sessionId = typeof payload.session_id === "string" ? payload.session_id.trim() : "";
    if (!sessionId) {
        sessionId = "sess-" + crypto.randomUUID();
    } else if (!SESSION_ID_RE.test(sessionId)) {
        return errorResponse("Invalid session_id.", 400);
    }

    const callsign = cleanText(payload.callsign, MAX_CALLSIGN, "PILOT").toUpperCase();
    const sessionType = payload.session_type === "LOBBY" ? "LOBBY" : "PILOT";
    const pilotId = await pilotIdFrom(request, env);

    const clientIp = clientIpOf(request);
    const country = request.cf?.country || "GLOBAL";
    const city = request.cf?.city || "";
    const colo = request.cf?.colo || "";

    // Only keep the metadata fields the lobby list actually uses.
    const rawMeta = parseMetadata(payload.metadata);
    const pick = (key) => (payload[key] !== undefined ? payload[key] : rawMeta[key]);
    const isPublic = pick("is_public");
    const meta = {
        lobby_name: cleanText(rawMeta.lobby_name, MAX_TEXT),
        map: cleanText(rawMeta.map, MAX_TEXT),
        client: cleanText(rawMeta.client, MAX_TEXT),
        players: clampInt(rawMeta.players, 1, 16, 1),
        max_players: clampInt(rawMeta.max_players, 1, 16, 2),
        game_port: clampInt(payload.port ?? rawMeta.game_port ?? rawMeta.port, 1, 65535, 7777),
        ping_port: clampInt(payload.ping_port ?? rawMeta.ping_port, 1, 65535, 7778),
        is_public: isPublic === undefined ? true : Boolean(isPublic),
        upnp_active: Boolean(pick("upnp_active")),
        // Set by the server, never by the client.
        host_ip: clientIp,
        country,
        city,
        colo,
    };
    for (const key of ["lobby_name", "map", "client"]) {
        if (!meta[key]) delete meta[key];
    }
    const metadataStr = JSON.stringify(meta);

    const reply = (status) => jsonResponse({
        success: true,
        session_id: sessionId,
        session_type: sessionType,
        host_ip: clientIp,
        country,
        colo,
        status,
    });

    if (!env.DB) {
        return reply("alive_mock");
    }

    try {
        // The WHERE clause on DO UPDATE only lets the session's own IP refresh
        // it, unless the existing row has already expired.
        const result = await env.DB.prepare(`
            INSERT INTO active_sessions (
                session_id, pilot_id, callsign, session_type, metadata, last_heartbeat
            ) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(session_id) DO UPDATE SET
                pilot_id = excluded.pilot_id,
                callsign = excluded.callsign,
                session_type = excluded.session_type,
                metadata = excluded.metadata,
                last_heartbeat = CURRENT_TIMESTAMP
            WHERE json_extract(active_sessions.metadata, '$.host_ip') = ?
               OR active_sessions.last_heartbeat < datetime('now', '${SESSION_EXPIRY}')
        `)
            .bind(sessionId, pilotId, callsign, sessionType, metadataStr, clientIp)
            .run();

        if ((result?.meta?.changes ?? 1) === 0) {
            return errorResponse("This session_id belongs to another client.", 409);
        }

        // Occasionally sweep sessions that stopped sending heartbeats.
        if (Math.random() < 0.2) {
            await env.DB.prepare(
                `DELETE FROM active_sessions WHERE last_heartbeat < datetime('now', '${SESSION_EXPIRY}')`
            ).run();
        }

        return reply("alive");
    } catch (err) {
        return errorResponse("Failed to register heartbeat.", 500, err.message);
    }
}
