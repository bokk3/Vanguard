/**
 * GET & POST /api/leaderboard
 * Global mission leaderboards and sortie debrief score submissions.
 */

import {
    jsonResponse,
    errorResponse,
    handleOptions,
    getAuthenticatedPilot,
} from "../_utils.js";

export async function onRequestOptions() {
    return handleOptions();
}

export async function onRequestGet({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    const url = new URL(request.url);
    const missionId = (url.searchParams.get("mission") || "M01").toUpperCase();
    const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit"), 10) || 50, 1), 100);

    try {
        const { results } = await env.DB.prepare(
            `SELECT id, mission_id, callsign, score, completion_time_sec, accuracy_pct, submitted_at 
             FROM mission_leaderboards 
             WHERE mission_id = ? 
             ORDER BY score DESC, completion_time_sec ASC 
             LIMIT ?`
        )
            .bind(missionId, limit)
            .all();

        // Assign ordinal flight rank
        const leaderboard = (results || []).map((entry, index) => ({
            rank: index + 1,
            ...entry,
        }));

        return jsonResponse({
            success: true,
            mission_id: missionId,
            total_entries: leaderboard.length,
            leaderboard,
        });
    } catch (err) {
        return errorResponse("Failed to query leaderboard.", 500, err.message);
    }
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    // Optional authentication: authenticated pilots link directly to their profile
    const auth = await getAuthenticatedPilot(request, env);

    let body;
    try {
        body = await request.json();
    } catch {
        return errorResponse("Invalid JSON payload.", 400);
    }

    const missionId = (body.mission_id || "M01").toUpperCase();
    const callsign = (auth ? auth.callsign : (body.callsign || "VANGUARD-PILOT")).trim().toUpperCase();
    const pilotId = auth ? auth.sub : "guest";
    const score = parseInt(body.score, 10);
    const completionTime = parseFloat(body.completion_time_sec || body.completion_time);
    const accuracy = Math.min(Math.max(parseFloat(body.accuracy_pct || 0.0), 0.0), 100.0);
    const ghostKey = body.ghost_r2_key || null;

    // Sanity / Heuristic Checks (Anti-Cheat baseline)
    if (isNaN(score) || score <= 0 || score > 2000000) {
        return errorResponse("Invalid score value.", 400);
    }
    if (isNaN(completionTime) || completionTime < 5.0) {
        return errorResponse("Sortie completion time is impossibly low.", 400);
    }

    try {
        const insertResult = await env.DB.prepare(
            `INSERT INTO mission_leaderboards (
                mission_id, pilot_id, callsign, completion_time_sec, score, accuracy_pct, ghost_r2_key
            ) VALUES (?, ?, ?, ?, ?, ?, ?)`
        )
            .bind(missionId, pilotId, callsign, completionTime, score, accuracy, ghostKey)
            .run();

        // Calculate rank for this score
        const rankQuery = await env.DB.prepare(
            `SELECT COUNT(*) as better_count 
             FROM mission_leaderboards 
             WHERE mission_id = ? AND (score > ? OR (score = ? AND completion_time_sec < ?))`
        )
            .bind(missionId, score, score, completionTime)
            .first();

        const currentRank = (rankQuery ? rankQuery.better_count : 0) + 1;

        // If authenticated, also bump their total sorties
        if (auth) {
            await env.DB.prepare(
                `UPDATE pilot_records 
                 SET total_sorties = total_sorties + 1, updated_at = CURRENT_TIMESTAMP 
                 WHERE pilot_id = ?`
            )
                .bind(auth.sub)
                .run();
        }

        return jsonResponse(
            {
                success: true,
                message: `Sortie debrief accepted for ${callsign}. Standing: #${currentRank}`,
                entry: {
                    id: insertResult.meta ? insertResult.meta.last_row_id : null,
                    mission_id: missionId,
                    callsign,
                    score,
                    completion_time_sec: completionTime,
                    accuracy_pct: accuracy,
                    rank: currentRank,
                },
            },
            201
        );
    } catch (err) {
        return errorResponse("Failed to submit sortie to leaderboard.", 500, err.message);
    }
}
