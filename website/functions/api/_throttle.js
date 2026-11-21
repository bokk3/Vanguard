/**
 * Fixed-window failure counter in D1, used to slow down password and
 * verification-code guessing. Keys look like "login:ip:1.2.3.4".
 */

import { jsonResponse } from "./_utils.js";

let tableEnsured = false;

async function ensureTable(db) {
    if (tableEnsured) return;
    await db.prepare(`
        CREATE TABLE IF NOT EXISTS auth_throttle (
            key TEXT PRIMARY KEY,
            failures INTEGER NOT NULL DEFAULT 0,
            window_start DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    `).run();
    tableEnsured = true;
}

/**
 * Returns the number of seconds until `key` may try again, or 0 if it isn't
 * blocked. A key is blocked once it has `limit` failures inside `windowSec`.
 */
export async function throttleRetryAfter(db, key, limit, windowSec) {
    await ensureTable(db);
    const row = await db.prepare(`
        SELECT failures,
               CAST(strftime('%s', window_start) AS INTEGER) + ? - CAST(strftime('%s', 'now') AS INTEGER) AS remaining
        FROM auth_throttle WHERE key = ?
    `).bind(windowSec, key).first();
    if (!row || row.remaining <= 0 || row.failures < limit) return 0;
    return row.remaining;
}

/** Records one failure for each key, starting a new window if the old one has passed. */
export async function recordFailure(db, keys, windowSec) {
    await ensureTable(db);
    const window = `-${Math.floor(windowSec)} seconds`;
    const stmt = db.prepare(`
        INSERT INTO auth_throttle (key, failures, window_start) VALUES (?, 1, CURRENT_TIMESTAMP)
        ON CONFLICT(key) DO UPDATE SET
            failures = CASE WHEN auth_throttle.window_start < datetime('now', ?) THEN 1 ELSE auth_throttle.failures + 1 END,
            window_start = CASE WHEN auth_throttle.window_start < datetime('now', ?) THEN CURRENT_TIMESTAMP ELSE auth_throttle.window_start END
    `);
    await db.batch(keys.map((key) => stmt.bind(key, window, window)));
    // Keep the table small.
    if (Math.random() < 0.05) {
        await db.prepare("DELETE FROM auth_throttle WHERE window_start < datetime('now', '-1 day')").run();
    }
}

export async function clearFailures(db, key) {
    await ensureTable(db);
    await db.prepare("DELETE FROM auth_throttle WHERE key = ?").bind(key).run();
}

export function tooManyAttempts(retryAfterSec) {
    const minutes = Math.max(1, Math.ceil(retryAfterSec / 60));
    return jsonResponse({
        success: false,
        error: `Too many attempts. Try again in ${minutes} minute${minutes === 1 ? "" : "s"}.`,
        retry_after_sec: retryAfterSec,
    }, 429, { "Retry-After": String(retryAfterSec) });
}
