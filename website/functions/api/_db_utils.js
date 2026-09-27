/**
 * Project Vanguard - Database Migration and Schema Helper
 * Ensures required table columns exist in Cloudflare D1 with automatic self-healing.
 */

let schemaEnsured = false;

export async function ensureVerificationSchema(db) {
    if (schemaEnsured || !db) return;
    
    try {
        // Quick probe to see if email_verified column exists
        await db.prepare("SELECT email_verified FROM pilots LIMIT 1").first();
        schemaEnsured = true;
    } catch {
        // Column missing: perform safe non-destructive ALTER TABLE additions
        try {
            await db.prepare("ALTER TABLE pilots ADD COLUMN email_verified INTEGER DEFAULT 0").run();
        } catch {}
        try {
            await db.prepare("ALTER TABLE pilots ADD COLUMN verification_code TEXT").run();
        } catch {}
        try {
            await db.prepare("ALTER TABLE pilots ADD COLUMN verification_expires_at DATETIME").run();
        } catch {}
        try {
            await db.prepare("CREATE INDEX IF NOT EXISTS idx_pilots_verified ON pilots(email_verified)").run();
        } catch {}
        schemaEnsured = true;
    }
}
