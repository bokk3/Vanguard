/**
 * POST /api/network/leave
 * Removes an active pilot or lobby session when disconnecting or shutting down.
 */

import {
    jsonResponse,
    handleOptions,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestPost({ request, env }) {
    let sessionId = "";
    try {
        const payload = await request.json();
        sessionId = payload.session_id || "";
    } catch {
        const url = new URL(request.url);
        sessionId = url.searchParams.get("session_id") || "";
    }

    if (env.DB && sessionId) {
        try {
            await env.DB.prepare("DELETE FROM active_sessions WHERE session_id = ?").bind(sessionId).run();
        } catch {
            // Ignore error on teardown
        }
    }

    return jsonResponse({
        success: true,
        session_id: sessionId,
        status: "disconnected"
    });
}
