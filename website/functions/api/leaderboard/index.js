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
    const missionParam = url.searchParams.get("mission");
    const type = (url.searchParams.get("type") || (missionParam ? "mission" : "global")).toLowerCase();
    const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit"), 10) || 50, 1), 100);
    const auth = await getAuthenticatedPilot(request, env);

    if (type === "global" || type === "aces" || !missionParam || missionParam === "ALL" || missionParam === "GLOBAL") {
        // Global Ace Pilots Leaderboard (Fleet-wide standings)
        try {
            const { results } = await env.DB.prepare(
                `SELECT 
                    p.id as pilot_id,
                    p.callsign,
                    p.rank,
                    p.squadron,
                    COALESCE(r.total_kills, 0) as total_kills,
                    COALESCE(r.total_sorties, 0) as total_sorties,
                    COALESCE(r.stars, 0) as stars,
                    COALESCE(r.total_flight_time_sec, 0.0) as total_flight_time_sec,
                    COALESCE(r.highest_mission_unlocked, 'M01') as highest_mission,
                    COALESCE(m.total_score, 0) as total_score,
                    COALESCE(m.mission_count, 0) as missions_completed,
                    COALESCE(m.avg_accuracy, 0.0) as avg_accuracy
                FROM pilots p
                LEFT JOIN pilot_records r ON p.id = r.pilot_id
                LEFT JOIN (
                    SELECT pilot_id, SUM(score) as total_score, COUNT(DISTINCT mission_id) as mission_count, ROUND(AVG(accuracy_pct), 1) as avg_accuracy
                    FROM mission_leaderboards
                    GROUP BY pilot_id
                ) m ON p.id = m.pilot_id
                ORDER BY 
                    (COALESCE(m.total_score, 0) + COALESCE(r.total_kills, 0) * 500 + COALESCE(r.total_sorties, 0) * 100) DESC,
                    r.total_kills DESC,
                    r.total_sorties DESC
                LIMIT ?`
            )
                .bind(limit)
                .all();

            const leaderboard = (results || []).map((entry, index) => {
                const compositeScore = entry.total_score + (entry.total_kills * 500) + (entry.total_sorties * 100);
                return {
                    rank: index + 1,
                    callsign: entry.callsign,
                    rank_title: entry.rank,
                    squadron: entry.squadron,
                    total_kills: entry.total_kills,
                    total_sorties: entry.total_sorties,
                    stars: entry.stars || 0,
                    flight_time_sec: entry.total_flight_time_sec,
                    highest_mission: entry.highest_mission,
                    mission_score: entry.total_score,
                    composite_score: compositeScore,
                    accuracy_pct: entry.avg_accuracy,
                };
            });

            // If requester is authenticated, find their personal rank
            let yourRank = null;
            if (auth) {
                const found = leaderboard.find(p => p.callsign.toUpperCase() === auth.callsign.toUpperCase());
                if (found) {
                    yourRank = found;
                } else {
                    yourRank = {
                        rank: "> " + limit,
                        callsign: auth.callsign,
                        rank_title: auth.rank,
                        squadron: auth.squadron || "404th Vanguard Strike Wing",
                    };
                }
            }

            return jsonResponse({
                success: true,
                type: "global",
                total_entries: leaderboard.length,
                leaderboard,
                your_rank: yourRank,
            });
        } catch (err) {
            return errorResponse("Failed to query global fleet leaderboard.", 500, err.message);
        }
    } else {
        // Mission-specific high scores & speedrun leaderboard
        const missionId = missionParam.toUpperCase();
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

            const leaderboard = (results || []).map((entry, index) => ({
                rank: index + 1,
                ...entry,
            }));

            let yourRank = null;
            if (auth) {
                const found = leaderboard.find(p => p.callsign.toUpperCase() === auth.callsign.toUpperCase());
                if (found) {
                    yourRank = found;
                }
            }

            return jsonResponse({
                success: true,
                type: "mission",
                mission_id: missionId,
                total_entries: leaderboard.length,
                leaderboard,
                your_rank: yourRank,
            });
        } catch (err) {
            return errorResponse("Failed to query mission leaderboard.", 500, err.message);
        }
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
