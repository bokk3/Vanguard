extends Node

## RewardManager: Centralized Economy, Badges, Daily Login Streaks & Reward Wheel Controller
## Handles in-game currency (Stars ⭐), cosmetics (Liveries/Skins), combat systems upgrades,
## military achievement badges, and daily reward distribution across Vanguard.

signal stars_changed(new_amount: int)
signal badge_unlocked(badge_id: String, badge_info: Dictionary)
signal livery_equipped(skin_id: String)
signal upgrade_applied(upgrade_id: String, new_tier: int)
signal rewards_updated()

const BADGES_DEF: Dictionary = {
	"FIRST_SORTIE": { "icon": "🎖️", "name": "First Sortie", "desc": "Complete initial flight qualification or combat sortie.", "condition": "Commissioned pilot." },
	"ACE_INTERCEPTOR": { "icon": "⚡", "name": "Ace Interceptor", "desc": "Confirm 25 or more hostile targets destroyed in combat.", "condition": "Destroy 25 enemies." },
	"WAR_GOD_OF_SOL": { "icon": "👑", "name": "War God of Sol", "desc": "Legendary combat standing: 100 confirmed career kills.", "condition": "Confirm 100 kills." },
	"GHOST_PROTOCOL": { "icon": "🛡️", "name": "Ghost Protocol", "desc": "Flawless sortie execution: Survive an engagement taking zero hull damage.", "condition": "Flawless mission outcome." },
	"CAMPAIGN_HERO": { "icon": "🌌", "name": "Campaign Hero", "desc": "Unlock and conquer Chapter / Mission 05: Silent Orbit.", "condition": "Complete Mission 05." },
	"FLEET_DEDICATION": { "icon": "📅", "name": "Fleet Dedication", "desc": "Demonstrate relentless discipline: Maintain a 7-day login streak.", "condition": "Reach Day 7 streak." },
	"LUCKY_STRIKE": { "icon": "🎯", "name": "Lucky Strike", "desc": "Hit the Grand Prize Jackpot (1,000★) on the Daily Tactical Wheel.", "condition": "Wheel Jackpot hit." },
	"PVP_GLADIATOR": { "icon": "⚔️", "name": "PVP Gladiator", "desc": "Score victory against a rival pilot in local or online dogfight arena.", "condition": "Win a PvP match." },
	"ARSENAL_OVERLORD": { "icon": "🛠️", "name": "Arsenal Overlord", "desc": "Upgrade any weapon or kinetic defense system to Tier III.", "condition": "Upgrade system to Tier 3." },
	"SOLAR_FASHION": { "icon": "🎨", "name": "Solar Fashion", "desc": "Acquire and equip a custom aerospace livery from the Hangar.", "condition": "Equip custom livery." },
}

const SKINS_DEF: Dictionary = {
	"CLASSIC_CYAN": { "id": "CLASSIC_CYAN", "name": "Interceptor Classic", "cost": 0, "color": Color(0.0, 0.9, 1.0), "desc": "Standard Vanguard titanium-composite hull with cyan avionics." },
	"SOLAR_FLARE": { "id": "SOLAR_FLARE", "name": "Solar Flare", "cost": 250, "color": Color(1.0, 0.84, 0.0), "desc": "Radiant high-albedo gold plating reflecting intense coronal bursts." },
	"VOID_STEALTH": { "id": "VOID_STEALTH", "name": "Void Stealth", "cost": 500, "color": Color(0.66, 0.33, 0.97), "desc": "Radar-absorbent matte carbon black finish with violet impulse glow." },
	"CRIMSON_FURY": { "id": "CRIMSON_FURY", "name": "Crimson Fury", "cost": 750, "color": Color(0.94, 0.27, 0.27), "desc": "Aggressive blood-red aerofoil livery with scorched titanium trim." },
	"CYBER_NEON": { "id": "CYBER_NEON", "name": "Cyberpunk Neon", "cost": 1000, "color": Color(0.92, 0.28, 0.6), "desc": "Overclocked holographic dual-tone synthwave neon coating." },
}

const UPGRADES_DEF: Dictionary = {
	"PULSE_CANNON": { "name": "Pulse Laser Cannons", "tiers": ["Tier I (Base)", "Tier II (+20% Dmg)", "Tier III (Plasma Punch)"], "costs": [100, 250, 600] },
	"HYDRA_MISSILES": { "name": "Hydra Missile Pods", "tiers": ["Tier I (4 Racks)", "Tier II (-25% Lock)", "Tier III (-35% Reload)"], "costs": [150, 300, 700] },
	"DEFLECTOR_SHIELD": { "name": "Deflector Kinetic Shields", "tiers": ["Tier I (100 HP)", "Tier II (+35% Recharge)", "Tier III (50% Divert)"], "costs": [120, 280, 650] },
	"AFTERBURNER_TURBO": { "name": "Afterburner Turbo Capacitor", "tiers": ["Tier I (120 m/s)", "Tier II (+25 Nitro)", "Tier III (-30% Drain)"], "costs": [100, 220, 500] },
}

const STREAK_REWARDS: Array[int] = [50, 75, 100, 150, 200, 300, 500]

const WHEEL_PRIZES: Array[Dictionary] = [
	{ "id": "50_STARS", "label": "50 STARS", "type": "stars", "amount": 50, "weight": 32 },
	{ "id": "100_STARS", "label": "100 STARS", "type": "stars", "amount": 100, "weight": 26 },
	{ "id": "250_STARS", "label": "250 STARS", "type": "stars", "amount": 250, "weight": 18 },
	{ "id": "500_STARS", "label": "500 STARS", "type": "stars", "amount": 500, "weight": 10 },
	{ "id": "JACKPOT_1000", "label": "1,000 STARS JACKPOT", "type": "stars", "amount": 1000, "badge": "LUCKY_STRIKE", "weight": 4 },
	{ "id": "SKIN_SOLAR_FLARE", "label": "SOLAR FLARE LIVERY", "type": "skin", "skin": "SOLAR_FLARE", "weight": 4 },
	{ "id": "UPGRADE_CANNON", "label": "PULSE CANNON UPGRADE", "type": "upgrade", "upgrade": "PULSE_CANNON", "weight": 3 },
	{ "id": "UPGRADE_SHIELD", "label": "DEFLECTOR SHIELD UPGRADE", "type": "upgrade", "upgrade": "DEFLECTOR_SHIELD", "weight": 3 },
]

# State Variables
var stars: int = 0
var streak: int = 1
var last_login_date: String = ""
var last_wheel_date: String = ""
var unlocked_badges: Array[String] = ["FIRST_SORTIE"]
var unlocked_skins: Array[String] = ["CLASSIC_CYAN"]
var active_skin: String = "CLASSIC_CYAN"
var upgrades: Dictionary = {
	"PULSE_CANNON": 1,
	"HYDRA_MISSILES": 1,
	"DEFLECTOR_SHIELD": 1,
	"AFTERBURNER_TURBO": 1
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local_cache()

func _load_local_cache() -> void:
	const SAVE_PATH = "user://pilot_profile.json"
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("rewards") and typeof(parsed["rewards"]) == TYPE_DICTIONARY:
		load_save_data(parsed["rewards"])
	elif parsed.has("stars"):
		stars = max(stars, int(parsed["stars"]))
		stars_changed.emit(stars)
		rewards_updated.emit()

## Adds Stars currency to pilot wallet and persists
func add_stars(amount: int) -> void:
	if amount <= 0: return
	stars += amount
	print(">>> [RewardManager] Earned +%d ⭐ Stars! Balance: %d" % [amount, stars])
	stars_changed.emit(stars)
	rewards_updated.emit()
	_persist_and_sync()

## Spends Stars currency if balance allows
func spend_stars(amount: int) -> bool:
	if amount <= 0: return true
	if stars < amount:
		return false
	stars -= amount
	print(">>> [RewardManager] Spent %d ⭐ Stars! Remaining: %d" % [amount, stars])
	stars_changed.emit(stars)
	rewards_updated.emit()
	_persist_and_sync()
	return true

## Grants an achievement badge
func unlock_badge(badge_id: String) -> void:
	if not unlocked_badges.has(badge_id):
		unlocked_badges.append(badge_id)
		var b_info = BADGES_DEF.get(badge_id, { "name": badge_id, "icon": "🎖️" })
		print(">>> [RewardManager] BADGE UNLOCKED: %s [%s]!" % [b_info.get("name"), b_info.get("icon")])
		badge_unlocked.emit(badge_id, b_info)
		rewards_updated.emit()
		_persist_and_sync()

func is_badge_unlocked(badge_id: String) -> bool:
	return unlocked_badges.has(badge_id)

func can_claim_daily_streak() -> bool:
	var today = Time.get_date_string_from_system()
	return last_login_date != today

## Claims daily login bonus and advances streak
func claim_daily_streak() -> Dictionary:
	var today = Time.get_date_string_from_system()
	if not can_claim_daily_streak():
		return { "success": false, "error": "Already claimed today." }
		
	# Check if yesterday for streak continuation
	var d_now = Time.get_unix_time_from_system()
	var d_yesterday = Time.get_date_string_from_unix_time(d_now - 86400)
	
	if last_login_date == d_yesterday:
		streak = min(streak + 1, 7)
	else:
		streak = 1
		
	last_login_date = today
	var bonus = STREAK_REWARDS[streak - 1]
	add_stars(bonus)
	
	if streak == 7:
		unlock_badge("FLEET_DEDICATION")
		
	return {
		"success": true,
		"streak": streak,
		"bonus_stars": bonus,
		"message": "Day %d login bonus claimed: +%d Stars!" % [streak, bonus]
	}

func can_spin_wheel() -> bool:
	var today = Time.get_date_string_from_system()
	return last_wheel_date != today

## Deploys Daily Reward Wheel and picks weighted prize
func spin_reward_wheel() -> Dictionary:
	var today = Time.get_date_string_from_system()
	if not can_spin_wheel():
		return { "success": false, "error": "Already deployed daily wheel today." }
		
	last_wheel_date = today
	
	# Weighted random choice
	var total_w = 0
	for p in WHEEL_PRIZES:
		total_w += p.get("weight", 1)
		
	var r = randi() % total_w
	var chosen_idx = 0
	for i in range(WHEEL_PRIZES.size()):
		var p = WHEEL_PRIZES[i]
		if r < p.get("weight", 1):
			chosen_idx = i
			break
		r -= p.get("weight", 1)
		
	var prize = WHEEL_PRIZES[chosen_idx]
	var p_type = prize.get("type", "stars")
	
	if p_type == "stars":
		var amt = int(prize.get("amount", 50))
		add_stars(amt)
		if prize.has("badge"):
			unlock_badge(prize["badge"])
	elif p_type == "skin":
		var s_id = prize.get("skin", "SOLAR_FLARE")
		if not unlocked_skins.has(s_id):
			unlocked_skins.append(s_id)
			unlock_badge("SOLAR_FASHION")
		else:
			add_stars(300) # Duplicate compensation
	elif p_type == "upgrade":
		var u_id = prize.get("upgrade", "PULSE_CANNON")
		var cur_t = upgrades.get(u_id, 1)
		if cur_t < 3:
			upgrades[u_id] = cur_t + 1
			if upgrades[u_id] >= 3:
				unlock_badge("ARSENAL_OVERLORD")
		else:
			add_stars(250)
			
	_persist_and_sync()
	return {
		"success": true,
		"prize_index": chosen_idx,
		"prize": prize
	}

## Buys a custom livery skin
func buy_skin(skin_id: String) -> bool:
	if not SKINS_DEF.has(skin_id): return false
	if unlocked_skins.has(skin_id): return false
	var cost = SKINS_DEF[skin_id].get("cost", 0)
	if not spend_stars(cost): return false
	
	unlocked_skins.append(skin_id)
	active_skin = skin_id
	unlock_badge("SOLAR_FASHION")
	livery_equipped.emit(skin_id)
	rewards_updated.emit()
	_persist_and_sync()
	return true

## Equips an unlocked livery
func equip_skin(skin_id: String) -> bool:
	if not unlocked_skins.has(skin_id): return false
	active_skin = skin_id
	unlock_badge("SOLAR_FASHION")
	livery_equipped.emit(skin_id)
	rewards_updated.emit()
	_persist_and_sync()
	return true

func get_active_skin() -> String:
	return active_skin

## Purchases a weapon or system tier upgrade
func buy_upgrade(upgrade_id: String) -> bool:
	if not UPGRADES_DEF.has(upgrade_id): return false
	var cur_tier = upgrades.get(upgrade_id, 1)
	if cur_tier >= 3: return false
	
	var costs: Array = UPGRADES_DEF[upgrade_id].get("costs", [100, 250, 600])
	var cost = costs[cur_tier - 1]
	if not spend_stars(cost): return false
	
	upgrades[upgrade_id] = cur_tier + 1
	if upgrades[upgrade_id] >= 3:
		unlock_badge("ARSENAL_OVERLORD")
		
	upgrade_applied.emit(upgrade_id, upgrades[upgrade_id])
	rewards_updated.emit()
	_persist_and_sync()
	return true

func get_upgrade_tier(upgrade_id: String) -> int:
	return upgrades.get(upgrade_id, 1)

## Returns structured dictionary for local and cloud saves
func get_save_data() -> Dictionary:
	return {
		"stars": stars,
		"streak": streak,
		"last_login_date": last_login_date,
		"last_wheel_date": last_wheel_date,
		"badges": unlocked_badges,
		"unlocked_skins": unlocked_skins,
		"active_skin": active_skin,
		"upgrades": upgrades
	}

## Restores saved rewards data
func load_save_data(data: Dictionary) -> void:
	if data.is_empty(): return
	stars = max(stars, int(data.get("stars", stars)))
	streak = int(data.get("streak", streak))
	last_login_date = str(data.get("last_login_date", last_login_date))
	last_wheel_date = str(data.get("last_wheel_date", last_wheel_date))
	
	if data.has("badges") and typeof(data["badges"]) == TYPE_ARRAY:
		for b in data["badges"]:
			if not unlocked_badges.has(str(b)):
				unlocked_badges.append(str(b))
				
	if data.has("unlocked_skins") and typeof(data["unlocked_skins"]) == TYPE_ARRAY:
		for s in data["unlocked_skins"]:
			if not unlocked_skins.has(str(s)):
				unlocked_skins.append(str(s))
				
	active_skin = str(data.get("active_skin", active_skin))
	
	if data.has("upgrades") and typeof(data["upgrades"]) == TYPE_DICTIONARY:
		for k in data["upgrades"]:
			upgrades[str(k)] = int(data["upgrades"][k])
			
	stars_changed.emit(stars)
	rewards_updated.emit()

## Merges rewards from cloud response non-destructively
func merge_cloud_rewards(cloud_data: Dictionary) -> void:
	if cloud_data.is_empty():
		return
		
	var c_stars = int(cloud_data.get("stars", 0))
	stars = max(stars, c_stars)
	
	var c_streak = int(cloud_data.get("streak", 1))
	streak = max(streak, c_streak)
	
	var c_login_date = str(cloud_data.get("last_login_date", ""))
	if not c_login_date.is_empty():
		last_login_date = c_login_date
		
	var c_wheel_date = str(cloud_data.get("last_wheel_date", ""))
	if not c_wheel_date.is_empty():
		last_wheel_date = c_wheel_date
		
	if cloud_data.has("badges") and typeof(cloud_data["badges"]) == TYPE_ARRAY:
		for b in cloud_data["badges"]:
			var b_str = str(b)
			if not unlocked_badges.has(b_str):
				unlocked_badges.append(b_str)
				
	if cloud_data.has("unlocked_skins") and typeof(cloud_data["unlocked_skins"]) == TYPE_ARRAY:
		for s in cloud_data["unlocked_skins"]:
			var s_str = str(s)
			if not unlocked_skins.has(s_str):
				unlocked_skins.append(s_str)
				
	var c_skin = str(cloud_data.get("active_skin", ""))
	if not c_skin.is_empty() and unlocked_skins.has(c_skin):
		active_skin = c_skin
		
	if cloud_data.has("upgrades") and typeof(cloud_data["upgrades"]) == TYPE_DICTIONARY:
		for k in cloud_data["upgrades"]:
			var key = str(k)
			var tier = int(cloud_data["upgrades"][k])
			upgrades[key] = max(upgrades.get(key, 1), tier)
			
	print(">>> [RewardManager] Cloud rewards merged. Total Stars: ⭐ %d | Streak: %d | Badges: %d" % [
		stars, streak, unlocked_badges.size()
	])
	
	stars_changed.emit(stars)
	rewards_updated.emit()
	_persist_local_only()

func _persist_local_only() -> void:
	var auth = get_node_or_null("/root/AuthManager")
	if auth and auth.has_method("_save_profile"):
		auth._save_profile()

func _persist_and_sync() -> void:
	var auth = get_node_or_null("/root/AuthManager")
	if auth and auth.has_method("_save_profile"):
		auth._save_profile()
		if not auth.token.is_empty() and auth.has_method("sync_cloud_save"):
			auth.sync_cloud_save()
