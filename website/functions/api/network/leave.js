/**
 * POST /api/network/leave
 * Removes a pilot or lobby session when the client disconnects. Only the IP
 * that owns the session can remove it (see heartbeat.js).
 */

import {
    jsonResponse,
    handleOptions,
    clientIpOf,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestPost({ request, env }) {
    let sessionId = "";
    try {
        // sendBeacon posts text/plain, so parse the body rather than relying on the content type.
        const payload = JSON.parse(await request.text());
        sessionId = typeof payload?.session_id === "string" ? payload.session_id : "";
    } catch {
        const url = new URL(request.url);
        sessionId = url.searchParams.get("session_id") || "";
    }
    sessionId = sessionId.trim().slice(0, 64);

    if (env.DB && sessionId) {
        try {
            await env.DB.prepare(
                "DELETE FROM active_sessions WHERE session_id = ? AND json_extract(metadata, '$.host_ip') = ?"
            ).bind(sessionId, clientIpOf(request)).run();
        } catch {
            // Ignore errors on teardown.
        }
    }

    return jsonResponse({
        success: true,
        session_id: sessionId,
        status: "disconnected",
    });
}
