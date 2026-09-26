-- ============================================================================
-- Project Vanguard: Cloudflare D1 Serverless Database Schema
-- $0 Cost Tier: 5,000,000 reads/day, 100,000 writes/day, 5 GB storage
-- ============================================================================

-- 1. Pilot Registration & Authentication Table
CREATE TABLE IF NOT EXISTS pilots (
    id TEXT PRIMARY KEY,                             -- UUID v4
    callsign TEXT UNIQUE NOT NULL COLLATE NOCASE,    -- e.g. "VANGUARD-LEAD", "VIPER"
    email TEXT UNIQUE NOT NULL COLLATE NOCASE,
    password_hash TEXT NOT NULL,                     -- Hex string of PBKDF2-HMAC-SHA256
    salt TEXT NOT NULL,                              -- Hex string of random salt
    rank TEXT DEFAULT 'FLIGHT LIEUTENANT',           -- Military rank designation
    squadron TEXT DEFAULT '404th Vanguard Strike Wing',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Index for instant callsign / email lookup
CREATE INDEX IF NOT EXISTS idx_pilots_callsign ON pilots(callsign);
CREATE INDEX IF NOT EXISTS idx_pilots_email ON pilots(email);

-- 2. Pilot Service Records & Cloud Savegames
CREATE TABLE IF NOT EXISTS pilot_records (
    pilot_id TEXT PRIMARY KEY,
    total_sorties INTEGER DEFAULT 0,
    total_kills INTEGER DEFAULT 0,
    total_flight_time_sec REAL DEFAULT 0.0,
    highest_mission_unlocked TEXT DEFAULT 'M01',
    save_blob TEXT,                                  -- Serialized vanguard_savegame.json
    checksum_sha256 TEXT,                            -- Client-side HMAC seal
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(pilot_id) REFERENCES pilots(id) ON DELETE CASCADE
);

-- 3. Device Link Sessions (QR Code / 6-digit Codes)
CREATE TABLE IF NOT EXISTS device_links (
    link_code TEXT PRIMARY KEY,                      -- 6-character code (e.g. "ACE-782")
    pilot_id TEXT,                                   -- Null until approved by pilot
    station_ip TEXT,                                 -- Requesting station IP
    approved INTEGER DEFAULT 0,                      -- 0 = pending, 1 = approved
    token TEXT,                                      -- Generated pilot token upon approval
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(pilot_id) REFERENCES pilots(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_device_links_expires ON device_links(expires_at);

-- 4. Verified Mission Leaderboards
CREATE TABLE IF NOT EXISTS mission_leaderboards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mission_id TEXT NOT NULL,                        -- 'M01' through 'M08'
    pilot_id TEXT NOT NULL,
    callsign TEXT NOT NULL,
    completion_time_sec REAL NOT NULL,
    score INTEGER NOT NULL,
    accuracy_pct REAL NOT NULL,
    ghost_r2_key TEXT,                               -- Optional R2 object key for ghost flight replay
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(pilot_id) REFERENCES pilots(id) ON DELETE CASCADE
);

-- Fast leaderboard retrieval index ordered by mission and descending score
CREATE INDEX IF NOT EXISTS idx_leaderboards_mission_score ON mission_leaderboards(mission_id, score DESC, completion_time_sec ASC);

-- 5. Fleet Telemetry & Active Online Presence
CREATE TABLE IF NOT EXISTS active_sessions (
    session_id TEXT PRIMARY KEY,
    pilot_id TEXT,
    callsign TEXT NOT NULL,
    session_type TEXT DEFAULT 'PILOT',           -- 'PILOT' or 'LOBBY'
    metadata TEXT,                               -- JSON string: { "lobby_name": "...", "players": 1, "max_players": 2 }
    last_heartbeat DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_active_sessions_heartbeat ON active_sessions(last_heartbeat);
CREATE INDEX IF NOT EXISTS idx_active_sessions_type ON active_sessions(session_type);

