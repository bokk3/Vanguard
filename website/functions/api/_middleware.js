/**
 * Runs in front of every /api/* function. Handlers catch their own errors, but
 * some auth calls sit outside those try blocks, so a missing or invalid
 * AUTH_SECRET would otherwise surface as an opaque Cloudflare error page.
 */

import { AuthConfigError, errorResponse } from "./_utils.js";

export async function onRequest(context) {
    try {
        return await context.next();
    } catch (err) {
        if (err instanceof AuthConfigError) {
            console.error("[Auth config]", err.message);
            return errorResponse("Authentication is not configured on this server.", 503);
        }
        throw err;
    }
}
