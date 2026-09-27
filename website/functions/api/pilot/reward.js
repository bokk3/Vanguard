/**
 * POST /api/pilot/reward
 * Handles server-authoritative daily login streaks, reward wheel spins,
 * skin unlocks, and weapon upgrades for authenticated pilots.
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

const WHEEL_PRIZES = [
    { id: "50_STARS", label: "50 STARS", type: "stars", amount: 50, weight: 32 },
    { id: "100_STARS", label: "100 STARS", type: "stars", amount: 100, weight: 26 },
    { id: "250_STARS", label: "250 STARS", type: "stars", amount: 250, weight: 18 },
    { id: "500_STARS", label: "500 STARS", type: "stars", amount: 500, weight: 10 },
    { id: "JACKPOT_1000", label: "1,000 STARS JACKPOT", type: "stars", amount: 1000, badge: "LUCKY_STRIKE", weight: 4 },
    { id: "SKIN_SOLAR_FLARE", label: "SOLAR FLARE LIVERY", type: "skin", skin: "SOLAR_FLARE", weight: 4 },
    { id: "UPGRADE_CANNON", label: "PULSE CANNON UPGRADE", type: "upgrade", upgrade: "PULSE_CANNON", weight: 3 },
    { id: "UPGRADE_SHIELD", label: "DEFLECTOR SHIELD UPGRADE", type: "upgrade", upgrade: "DEFLECTOR_SHIELD", weight: 3 },
];

const SKINS_CATALOG = {
    "CLASSIC_CYAN": { id: "CLASSIC_CYAN", name: "Interceptor Classic", cost: 0, rarity: "STANDARD" },
    "SOLAR_FLARE": { id: "SOLAR_FLARE", name: "Solar Flare", cost: 250, rarity: "RARE" },
    "VOID_STEALTH": { id: "VOID_STEALTH", name: "Void Stealth", cost: 500, rarity: "EPIC" },
    "CRIMSON_FURY": { id: "CRIMSON_FURY", name: "Crimson Fury", cost: 750, rarity: "LEGENDARY" },
    "CYBER_NEON": { id: "CYBER_NEON", name: "Cyberpunk Neon", cost: 1000, rarity: "EXOTIC" },
};

const UPGRADES_CATALOG = {
    "PULSE_CANNON": { name: "Pulse Laser Cannons", max_tier: 3, costs: [100, 250, 600] },
    "HYDRA_MISSILES": { name: "Hydra Missile Pods", max_tier: 3, costs: [150, 300, 700] },
    "DEFLECTOR_SHIELD": { name: "Deflector Kinetic Shields", max_tier: 3, costs: [120, 280, 650] },
    "AFTERBURNER_TURBO": { name: "Afterburner Turbo Capacitor", max_tier: 3, costs: [100, 220, 500] },
};

const STREAK_REWARDS = [50, 75, 100, 150, 200, 300, 500];

function getUtcDateString(d = new Date()) {
    return d.toISOString().split("T")[0];
}

function getYesterdayDateString() {
    const d = new Date();
    d.setUTCDate(d.getUTCDate() - 1);
    return getUtcDateString(d);
}

export async function onRequestPost({ request, env }) {
    if (!env.DB) {
        return errorResponse("Database binding (DB) is not configured.", 500);
    }

    const auth = await getAuthenticatedPilot(request, env);
    if (!auth) {
        return errorResponse("Unauthorized: Missing or invalid Pilot Bearer Token.", 401);
    }

    await ensureRewardSchema(env.DB);

    let body = {};
    try {
        body = await request.json();
    } catch {}

    const action = body.action || "get_status";

    try {
        // Fetch current record & save_blob
        const record = await env.DB.prepare(
            `SELECT pilot_id, total_sorties, total_kills, stars, save_blob 
             FROM pilot_records 
             WHERE pilot_id = ? 
             LIMIT 1`
        ).bind(auth.sub).first();

        let saveObj = {};
        if (record && record.save_blob) {
            try {
                saveObj = JSON.parse(record.save_blob);
            } catch {}
        }

        if (!saveObj.rewards) {
            saveObj.rewards = {
                stars: record?.stars || 0,
                streak: 0,
                last_login_date: "",
                last_wheel_date: "",
                badges: ["FIRST_SORTIE"],
                unlocked_skins: ["CLASSIC_CYAN"],
                active_skin: "CLASSIC_CYAN",
                upgrades: {
                    PULSE_CANNON: 1,
                    HYDRA_MISSILES: 1,
                    DEFLECTOR_SHIELD: 1,
                    AFTERBURNER_TURBO: 1,
                },
            };
        }

        const rewards = saveObj.rewards;
        if (!rewards.badges) rewards.badges = ["FIRST_SORTIE"];
        if (!rewards.unlocked_skins) rewards.unlocked_skins = ["CLASSIC_CYAN"];
        if (!rewards.active_skin) rewards.active_skin = "CLASSIC_CYAN";
        if (!rewards.upgrades) {
            rewards.upgrades = { PULSE_CANNON: 1, HYDRA_MISSILES: 1, DEFLECTOR_SHIELD: 1, AFTERBURNER_TURBO: 1 };
        }
        if (rewards.stars === undefined) rewards.stars = record?.stars || 0;

        const today = getUtcDateString();
        const yesterday = getYesterdayDateString();

        // Check streak status
        const canClaimStreak = rewards.last_login_date !== today;
        const canSpinWheel = rewards.last_wheel_date !== today;

        if (action === "get_status") {
            return jsonResponse({
                success: true,
                rewards,
                can_claim_streak: canClaimStreak,
                can_spin_wheel: canSpinWheel,
                server_date: today,
                wheel_prizes: WHEEL_PRIZES,
                skins_catalog: SKINS_CATALOG,
                upgrades_catalog: UPGRADES_CATALOG,
            });
        }

        // Action 1: Claim Daily Login Streak Bonus
        if (action === "claim_streak") {
            if (!canClaimStreak) {
                return jsonResponse({
                    success: false,
                    error: "Daily tactical bonus already claimed today. Returns at 00:00 UTC.",
                    rewards,
                    can_claim_streak: false,
                }, 400);
            }

            if (rewards.last_login_date === yesterday) {
                rewards.streak = Math.min((rewards.streak || 0) + 1, 7);
            } else {
                rewards.streak = 1;
            }

            rewards.last_login_date = today;
            const streakIdx = Math.max(0, Math.min(rewards.streak - 1, STREAK_REWARDS.length - 1));
            const bonusStars = STREAK_REWARDS[streakIdx];
            rewards.stars = (rewards.stars || 0) + bonusStars;

            // Day 7 badge unlock
            if (rewards.streak === 7 && !rewards.badges.includes("FLEET_DEDICATION")) {
                rewards.badges.push("FLEET_DEDICATION");
            }

            await saveRewardsToDb(env.DB, auth.sub, rewards, saveObj);

            return jsonResponse({
                success: true,
                message: `Daily Login Day ${rewards.streak} claimed! Received +${bonusStars} Stars.`,
                reward_granted: { stars: bonusStars, streak: rewards.streak },
                rewards,
                can_claim_streak: false,
                can_spin_wheel: rewards.last_wheel_date !== today,
            });
        }

        // Action 2: Spin the Daily Reward Wheel
        if (action === "spin_wheel") {
            if (!canSpinWheel) {
                return jsonResponse({
                    success: false,
                    error: "Daily tactical wheel spin already deployed today. Next spin at 00:00 UTC.",
                    rewards,
                    can_spin_wheel: false,
                }, 400);
            }

            // Weighted random selection
            const totalWeight = WHEEL_PRIZES.reduce((sum, p) => sum + p.weight, 0);
            let rnd = Math.random() * totalWeight;
            let selectedIdx = 0;

            for (let i = 0; i < WHEEL_PRIZES.length; i++) {
                if (rnd < WHEEL_PRIZES[i].weight) {
                    selectedIdx = i;
                    break;
                }
                rnd -= WHEEL_PRIZES[i].weight;
            }

            const prize = WHEEL_PRIZES[selectedIdx];
            rewards.last_wheel_date = today;

            if (prize.type === "stars") {
                rewards.stars = (rewards.stars || 0) + prize.amount;
                if (prize.badge && !rewards.badges.includes(prize.badge)) {
                    rewards.badges.push(prize.badge);
                }
            } else if (prize.type === "skin") {
                if (!rewards.unlocked_skins.includes(prize.skin)) {
                    rewards.unlocked_skins.push(prize.skin);
                } else {
                    // Fallback duplicate compensation: 300 stars
                    rewards.stars = (rewards.stars || 0) + 300;
                    prize.compensation_stars = 300;
                }
            } else if (prize.type === "upgrade") {
                const curTier = rewards.upgrades[prize.upgrade] || 1;
                if (curTier < 3) {
                    rewards.upgrades[prize.upgrade] = curTier + 1;
                } else {
                    // Fallback duplicate compensation: 250 stars
                    rewards.stars = (rewards.stars || 0) + 250;
                    prize.compensation_stars = 250;
                }
            }

            await saveRewardsToDb(env.DB, auth.sub, rewards, saveObj);

            return jsonResponse({
                success: true,
                prize_index: selectedIdx,
                prize,
                message: `Wheel Deploy Result: ${prize.label}!`,
                rewards,
                can_spin_wheel: false,
            });
        }

        // Action 3: Purchase Skin or Weapon Upgrade
        if (action === "buy_skin") {
            const skinId = body.skin_id;
            const skinDef = SKINS_CATALOG[skinId];
            if (!skinDef) {
                return errorResponse("Invalid skin livery identifier.", 400);
            }
            if (rewards.unlocked_skins.includes(skinId)) {
                return errorResponse("Skin livery is already unlocked in your hangar.", 400);
            }
            if (rewards.stars < skinDef.cost) {
                return errorResponse(`Insufficient Stars. Requires ${skinDef.cost}★ (You have ${rewards.stars}★).`, 400);
            }

            rewards.stars -= skinDef.cost;
            rewards.unlocked_skins.push(skinId);
            rewards.active_skin = skinId;

            if (!rewards.badges.includes("SOLAR_FASHION")) {
                rewards.badges.push("SOLAR_FASHION");
            }

            await saveRewardsToDb(env.DB, auth.sub, rewards, saveObj);

            return jsonResponse({
                success: true,
                message: `Hangar acquisition confirmed: ${skinDef.name} equipped.`,
                rewards,
            });
        }

        // Action 4: Upgrade Weapon System
        if (action === "buy_upgrade") {
            const upId = body.upgrade_id;
            const upDef = UPGRADES_CATALOG[upId];
            if (!upDef) {
                return errorResponse("Invalid weapon upgrade identifier.", 400);
            }

            const curTier = rewards.upgrades[upId] || 1;
            if (curTier >= upDef.max_tier) {
                return errorResponse(`${upDef.name} is already at maximum combat tier (${upDef.max_tier}).`, 400);
            }

            const cost = upDef.costs[curTier - 1];
            if (rewards.stars < cost) {
                return errorResponse(`Insufficient Stars for Tier ${curTier + 1}. Requires ${cost}★ (You have ${rewards.stars}★).`, 400);
            }

            rewards.stars -= cost;
            rewards.upgrades[upId] = curTier + 1;

            if (rewards.upgrades[upId] >= 3 && !rewards.badges.includes("ARSENAL_OVERLORD")) {
                rewards.badges.push("ARSENAL_OVERLORD");
            }

            await saveRewardsToDb(env.DB, auth.sub, rewards, saveObj);

            return jsonResponse({
                success: true,
                message: `${upDef.name} upgraded to Tier ${rewards.upgrades[upId]}!`,
                rewards,
            });
        }

        // Action 5: Equip Livery Skin
        if (action === "equip_skin") {
            const skinId = body.skin_id;
            if (!rewards.unlocked_skins.includes(skinId)) {
                return errorResponse("You do not own this livery skin.", 400);
            }
            rewards.active_skin = skinId;
            await saveRewardsToDb(env.DB, auth.sub, rewards, saveObj);

            return jsonResponse({
                success: true,
                message: `Active livery set to ${SKINS_CATALOG[skinId]?.name || skinId}.`,
                rewards,
            });
        }

        return errorResponse("Unknown action.", 400);

    } catch (err) {
        console.error("[Reward API Error]", err);
        return errorResponse("Failed to process reward transaction.", 500, err.message);
    }
}

async function saveRewardsToDb(db, pilotId, rewards, saveObj) {
    saveObj.rewards = rewards;
    const saveBlob = JSON.stringify(saveObj);

    await db.prepare(
        `INSERT INTO pilot_records (pilot_id, stars, save_blob, updated_at) 
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(pilot_id) DO UPDATE SET
             stars = excluded.stars,
             save_blob = excluded.save_blob,
             updated_at = CURRENT_TIMESTAMP`
    )
        .bind(pilotId, rewards.stars, saveBlob)
        .run();
}
