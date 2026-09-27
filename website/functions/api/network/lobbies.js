/**
 * GET /api/network/lobbies
 * Returns active public P2P lobbies registered on the global fleet radar.
 */

import {
    jsonResponse,
    handleOptions,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestGet({ env }) {
    if (!env.DB) {
        return jsonResponse({
            success: true,
            lobbies: [],
            total: 0,
            environment: "standalone_fallback"
        }, 200, { "Cache-Control": "public, max-age=4" });
    }

    try {
        // Defensive table check
        await env.DB.prepare(`
            CREATE TABLE IF NOT EXISTS active_sessions (
                session_id TEXT PRIMARY KEY,
                pilot_id TEXT,
                callsign TEXT NOT NULL,
                session_type TEXT DEFAULT 'PILOT',
                metadata TEXT,
                last_heartbeat DATETIME DEFAULT CURRENT_TIMESTAMP,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `).run();

        // Query active lobbies that sent a heartbeat within the last 90 seconds
        const lobbyRows = await env.DB.prepare(`
            SELECT s.session_id, s.pilot_id, s.callsign, s.metadata, s.last_heartbeat,
                   p.rank, p.squadron
            FROM active_sessions s
            LEFT JOIN pilots p ON s.pilot_id = p.id
            WHERE s.session_type = 'LOBBY'
              AND s.last_heartbeat >= datetime('now', '-90 seconds')
            ORDER BY s.last_heartbeat DESC
            LIMIT 30
        `).all();

        const lobbies = [];
        for (const r of (lobbyRows.results || [])) {
            let meta = {};
            try {
                meta = JSON.parse(r.metadata || "{}");
            } catch {
                meta = {};
            }

            // Exclude private lobbies if explicitly flagged
            if (meta.is_public === false) {
                continue;
            }

            lobbies.push({
                session_id: r.session_id,
                pilot_id: r.pilot_id || null,
                host_callsign: r.callsign,
                host_rank: r.rank || "FLIGHT CADET",
                squadron: r.squadron || "404th Vanguard Strike Wing",
                lobby_name: meta.lobby_name || `${r.callsign}'s LOBBY`,
                host_ip: meta.host_ip || "",
                game_port: Number(meta.game_port || meta.port || 7777),
                ping_port: Number(meta.ping_port || 7778),
                players: Number(meta.players || 1),
                max_players: Number(meta.max_players || 2),
                map: meta.map || "Dusk Canyon",
                country: meta.country || "GLOBAL",
                city: meta.city || "",
                colo: meta.colo || "",
                upnp_active: Boolean(meta.upnp_active),
                is_authenticated: Boolean(r.pilot_id),
                last_seen: r.last_heartbeat
            });
        }

        return jsonResponse({
            success: true,
            lobbies: lobbies,
            total: lobbies.length,
            timestamp: new Date().toISOString()
        }, 200, {
            "Cache-Control": "public, max-age=4, s-maxage=4"
        });
    } catch (err) {
        return jsonResponse({
            success: false,
            error: err.message,
            lobbies: [],
            total: 0
        }, 500);
    }
}
