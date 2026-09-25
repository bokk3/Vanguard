/**
 * POST /api/pilot/sync
 * Synchronizes local campaign savegame and flight telemetry to Cloudflare D1.
 * Requires Bearer Token authentication.
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

    const auth = await getAuthenticatedPilot(request, env);
    if (!auth) {
        return errorResponse("Unauthorized: Missing or invalid Pilot Bearer Token.", 401);
    }

    try {
        const record = await env.DB.prepare(
            `SELECT pilot_id, total_sorties, total_kills, total_flight_time_sec, 
                    highest_mission_unlocked, save_blob, checksum_sha256, updated_at 
             FROM pilot_records 
             WHERE pilot_id = ? 
             LIMIT 1`
        )
            .bind(auth.sub)
            .first();

        let parsedSave = null;
        if (record && record.save_blob) {
            try {
                parsedSave = JSON.parse(record.save_blob);
            } catch {
                parsedSave = null;
            }
        }

        return jsonResponse({
            success: true,
            pilot: {
                id: auth.sub,
                callsign: auth.callsign,
                rank: auth.rank,
            },
            record: record || null,
            save_data: parsedSave,
        });
    } catch (err) {
        return errorResponse("Failed to retrieve pilot cloud save.", 500, err.message);
    }
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    const auth = await getAuthenticatedPilot(request, env);
    if (!auth) {
        return errorResponse("Unauthorized: Missing or invalid Pilot Bearer Token.", 401);
    }

    let payload;
    try {
        payload = await request.json();
    } catch {
        return errorResponse("Invalid JSON payload.", 400);
    }

    const saveBlob = typeof payload.save_data === "object" ? JSON.stringify(payload.save_data) : (payload.save_blob || null);
    const checksum = payload.checksum_sha256 || "";
    const sorties = parseInt(payload.total_sorties, 10) || 0;
    const kills = parseInt(payload.total_kills, 10) || 0;
    const flightTime = parseFloat(payload.total_flight_time_sec) || 0.0;
    const highestMission = (payload.highest_mission_unlocked || "M01").trim();

    try {
        await env.DB.prepare(
            `INSERT INTO pilot_records (
                pilot_id, total_sorties, total_kills, total_flight_time_sec, 
                highest_mission_unlocked, save_blob, checksum_sha256, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(pilot_id) DO UPDATE SET
                total_sorties = MAX(total_sorties, excluded.total_sorties),
                total_kills = MAX(total_kills, excluded.total_kills),
                total_flight_time_sec = total_flight_time_sec + excluded.total_flight_time_sec,
                highest_mission_unlocked = excluded.highest_mission_unlocked,
                save_blob = COALESCE(excluded.save_blob, save_blob),
                checksum_sha256 = COALESCE(excluded.checksum_sha256, checksum_sha256),
                updated_at = CURRENT_TIMESTAMP`
        )
            .bind(auth.sub, sorties, kills, flightTime, highestMission, saveBlob, checksum)
            .run();

        return jsonResponse({
            success: true,
            message: `Cloud save synchronized for Pilot ${auth.callsign}.`,
            synced_at: new Date().toISOString(),
        });
    } catch (err) {
        return errorResponse("Failed to update cloud save record.", 500, err.message);
    }
}
