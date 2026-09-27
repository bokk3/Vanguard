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
import { ensureRewardSchema } from "../_db_utils.js";

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
        await ensureRewardSchema(env.DB);

        const record = await env.DB.prepare(
            `SELECT pilot_id, total_sorties, total_kills, total_flight_time_sec, 
                    highest_mission_unlocked, COALESCE(stars, 0) as stars, save_blob, checksum_sha256, updated_at 
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

        const rewards = (parsedSave && parsedSave.rewards) ? parsedSave.rewards : {
            stars: record ? (record.stars || 0) : 0,
            streak: 1,
            badges: ["FIRST_SORTIE"],
            unlocked_skins: ["CLASSIC_CYAN"],
            active_skin: "CLASSIC_CYAN",
            upgrades: { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 }
        };
        if (record && record.stars !== undefined) {
            rewards.stars = Math.max(rewards.stars || 0, record.stars || 0);
        }

        return jsonResponse({
            success: true,
            pilot: {
                id: auth.sub,
                callsign: auth.callsign,
                rank: auth.rank,
            },
            record: record || null,
            stars: rewards.stars,
            rewards: rewards,
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

    try {
        await ensureRewardSchema(env.DB);

        // Fetch existing record first to merge rewards & stars safely
        const existing = await env.DB.prepare(
            `SELECT COALESCE(stars, 0) as stars, save_blob 
             FROM pilot_records 
             WHERE pilot_id = ? 
             LIMIT 1`
        ).bind(auth.sub).first();

        let existingSave = {};
        if (existing && existing.save_blob) {
            try {
                existingSave = JSON.parse(existing.save_blob);
            } catch {}
        }

        let saveObj = (payload.save_data && typeof payload.save_data === "object") ? payload.save_data : existingSave;

        // Extract client and server rewards
        let clientRewards = payload.rewards || payload.save_data?.rewards || null;
        let serverRewards = existingSave.rewards || null;

        let mergedRewards = {
            stars: 0,
            streak: 1,
            last_login_date: "",
            last_wheel_date: "",
            badges: ["FIRST_SORTIE"],
            unlocked_skins: ["CLASSIC_CYAN"],
            active_skin: "CLASSIC_CYAN",
            upgrades: { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 }
        };

        // Merge stars: never drop stars earned on either platform!
        const payloadStars = parseInt(payload.stars ?? clientRewards?.stars ?? 0, 10);
        const serverStars = parseInt(existing?.stars || serverRewards?.stars || 0, 10);
        const finalStars = Math.max(payloadStars, serverStars, clientRewards?.stars || 0);
        mergedRewards.stars = finalStars;

        // Merge streaks and dates
        mergedRewards.streak = Math.max(clientRewards?.streak || 1, serverRewards?.streak || 1);
        mergedRewards.last_login_date = clientRewards?.last_login_date || serverRewards?.last_login_date || "";
        mergedRewards.last_wheel_date = clientRewards?.last_wheel_date || serverRewards?.last_wheel_date || "";

        // Merge badges & skins
        var allBadges = ["FIRST_SORTIE"];
        if (clientRewards?.badges) allBadges = allBadges.concat(clientRewards.badges);
        if (serverRewards?.badges) allBadges = allBadges.concat(serverRewards.badges);
        mergedRewards.badges = Array.from(new Set(allBadges));

        var allSkins = ["CLASSIC_CYAN"];
        if (clientRewards?.unlocked_skins) allSkins = allSkins.concat(clientRewards.unlocked_skins);
        if (serverRewards?.unlocked_skins) allSkins = allSkins.concat(serverRewards.unlocked_skins);
        mergedRewards.unlocked_skins = Array.from(new Set(allSkins));

        mergedRewards.active_skin = clientRewards?.active_skin || serverRewards?.active_skin || "CLASSIC_CYAN";

        // Merge upgrade tiers
        mergedRewards.upgrades = {
            PULSE_CANNON: Math.max(clientRewards?.upgrades?.PULSE_CANNON || 1, serverRewards?.upgrades?.PULSE_CANNON || 1),
            HYDRA_MISSILES: Math.max(clientRewards?.upgrades?.HYDRA_MISSILES || 1, serverRewards?.upgrades?.HYDRA_MISSILES || 1),
            DEFLECTOR_SHIELD: Math.max(clientRewards?.upgrades?.DEFLECTOR_SHIELD || 1, serverRewards?.upgrades?.DEFLECTOR_SHIELD || 1),
            AFTERBURNER_TURBO: Math.max(clientRewards?.upgrades?.AFTERBURNER_TURBO || 1, serverRewards?.upgrades?.AFTERBURNER_TURBO || 1),
        };

        saveObj.rewards = mergedRewards;
        const saveBlob = JSON.stringify(saveObj);
        const checksum = payload.checksum_sha256 || "";
        const sorties = parseInt(payload.total_sorties, 10) || 0;
        const kills = parseInt(payload.total_kills, 10) || 0;
        const flightTime = parseFloat(payload.total_flight_time_sec) || 0.0;
        const highestMission = (payload.highest_mission_unlocked || "M01").trim();

        await env.DB.prepare(
            `INSERT INTO pilot_records (
                pilot_id, total_sorties, total_kills, total_flight_time_sec, 
                highest_mission_unlocked, stars, save_blob, checksum_sha256, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(pilot_id) DO UPDATE SET
                total_sorties = MAX(total_sorties, excluded.total_sorties),
                total_kills = MAX(total_kills, excluded.total_kills),
                total_flight_time_sec = total_flight_time_sec + excluded.total_flight_time_sec,
                highest_mission_unlocked = excluded.highest_mission_unlocked,
                stars = excluded.stars,
                save_blob = excluded.save_blob,
                checksum_sha256 = COALESCE(excluded.checksum_sha256, checksum_sha256),
                updated_at = CURRENT_TIMESTAMP`
        )
            .bind(auth.sub, sorties, kills, flightTime, highestMission, finalStars, saveBlob, checksum)
            .run();

        return jsonResponse({
            success: true,
            message: `Cloud save synchronized for Pilot ${auth.callsign}.`,
            stars: finalStars,
            rewards: mergedRewards,
            save_data: saveObj,
            synced_at: new Date().toISOString(),
        });
    } catch (err) {
        return errorResponse("Failed to update cloud save record.", 500, err.message);
    }
}
