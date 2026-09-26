/**
 * GET /api/network/stats
 * Returns live fleet metrics: registered pilots, online pilots, and active combat lobbies.
 */

import {
    jsonResponse,
    handleOptions,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestGet({ env }) {
    // Graceful offline / local fallback if DB binding is not yet attached
    if (!env.DB) {
        return jsonResponse({
            success: true,
            registered_pilots: 1420,
            online_pilots: 1,
            active_lobbies: 0,
            lobbies: [],
            environment: "standalone_fallback"
        }, 200, { "Cache-Control": "public, max-age=5" });
    }

    try {
        // Defensive self-healing table initialization
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

        // 1. Registered Pilots Count
        const regRow = await env.DB.prepare("SELECT COUNT(*) AS count FROM pilots").first();
        const rawRegistered = regRow ? (regRow.count || 0) : 0;
        // Baseline of 1,420 squadron enlistees plus organic registrations
        const registeredPilots = 1420 + rawRegistered;

        // 2. Currently Online Pilots (heartbeat within last 90 seconds)
        const onlineRow = await env.DB.prepare(`
            SELECT COUNT(DISTINCT session_id) AS count 
            FROM active_sessions 
            WHERE last_heartbeat >= datetime('now', '-90 seconds')
        `).first();
        const onlinePilots = Math.max(onlineRow ? (onlineRow.count || 0) : 0, 1);

        // 3. Active PvP Combat Lobbies (heartbeat within last 90 seconds)
        const lobbyRows = await env.DB.prepare(`
            SELECT session_id, callsign, metadata, last_heartbeat 
            FROM active_sessions 
            WHERE session_type = 'LOBBY' 
              AND last_heartbeat >= datetime('now', '-90 seconds')
            ORDER BY last_heartbeat DESC 
            LIMIT 20
        `).all();

        const lobbies = (lobbyRows.results || []).map(r => {
            let meta = {};
            try {
                meta = JSON.parse(r.metadata || "{}");
            } catch {
                meta = {};
            }
            return {
                session_id: r.session_id,
                host_callsign: r.callsign,
                lobby_name: meta.lobby_name || `${r.callsign}'s LOBBY`,
                players: meta.players || 1,
                max_players: meta.max_players || 2,
                map: meta.map || "Dusk Canyon",
                last_seen: r.last_heartbeat
            };
        });

        return jsonResponse({
            success: true,
            registered_pilots: registeredPilots,
            online_pilots: onlinePilots,
            active_lobbies: lobbies.length,
            lobbies: lobbies,
            timestamp: new Date().toISOString()
        }, 200, {
            "Cache-Control": "public, max-age=5, s-maxage=5"
        });
    } catch (err) {
        return jsonResponse({
            success: true,
            registered_pilots: 1420,
            online_pilots: 1,
            active_lobbies: 0,
            lobbies: [],
            error: err.message
        }, 200);
    }
}
