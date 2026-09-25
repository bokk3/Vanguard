/**
 * Project Vanguard - Cloudflare Edge API Utilities
 * Pure Web Crypto PBKDF2 password hashing & HMAC-SHA256 token verification.
 * Zero external npm dependencies — runs natively in Cloudflare Workers / Pages runtime.
 */

const DEFAULT_AUTH_SECRET = "vanguard-strike-wing-404th-secret-key-2026";
const PBKDF2_ITERATIONS = 100000;

// ============================================================================
// 1. CORS & Response Helpers
// ============================================================================

export function corsHeaders() {
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
        "Access-Control-Max-Age": "86400",
    };
}

export function handleOptions() {
    return new Response(null, {
        status: 204,
        headers: corsHeaders(),
    });
}

export function jsonResponse(data, status = 200, extraHeaders = {}) {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            "Content-Type": "application/json; charset=utf-8",
            ...corsHeaders(),
            ...extraHeaders,
        },
    });
}

export function errorResponse(message, status = 400, details = null) {
    return jsonResponse(
        {
            success: false,
            error: message,
            ...(details ? { details } : {}),
        },
        status
    );
}

// ============================================================================
// 2. Cryptographic Helpers (PBKDF2 Password Hashing)
// ============================================================================

function bufferToHex(buffer) {
    return Array.from(new Uint8Array(buffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}

function hexToBuffer(hexString) {
    const bytes = new Uint8Array(Math.ceil(hexString.length / 2));
    for (let i = 0; i < bytes.length; i++) {
        bytes[i] = parseInt(hexString.substr(i * 2, 2), 16);
    }
    return bytes.buffer;
}

export function generateSalt(length = 16) {
    const saltBytes = new Uint8Array(length);
    crypto.getRandomValues(saltBytes);
    return bufferToHex(saltBytes);
}

export async function hashPassword(password, saltHex) {
    const enc = new TextEncoder();
    const keyMaterial = await crypto.subtle.importKey(
        "raw",
        enc.encode(password),
        { name: "PBKDF2" },
        false,
        ["deriveBits"]
    );

    const derivedBits = await crypto.subtle.deriveBits(
        {
            name: "PBKDF2",
            salt: hexToBuffer(saltHex),
            iterations: PBKDF2_ITERATIONS,
            hash: "SHA-256",
        },
        keyMaterial,
        256
    );

    return bufferToHex(derivedBits);
}

export async function verifyPassword(password, saltHex, storedHash) {
    const computed = await hashPassword(password, saltHex);
    return computed === storedHash;
}

// ============================================================================
// 3. Compact Pilot Bearer Token (HMAC-SHA256 JWT)
// ============================================================================

function base64UrlEncode(str) {
    return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(str) {
    str = str.replace(/-/g, "+").replace(/_/g, "/");
    while (str.length % 4) {
        str += "=";
    }
    return atob(str);
}

export async function createPilotToken(payload, secret = DEFAULT_AUTH_SECRET, expiresInSec = 86400 * 30) {
    const header = { alg: "HS256", typ: "JWT" };
    const now = Math.floor(Date.now() / 1000);
    const exp = now + expiresInSec;

    const fullPayload = {
        ...payload,
        iat: now,
        exp: exp,
    };

    const encodedHeader = base64UrlEncode(JSON.stringify(header));
    const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
    const message = `${encodedHeader}.${encodedPayload}`;

    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw",
        enc.encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
    const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));

    return `${message}.${encodedSignature}`;
}

export async function verifyPilotToken(token, secret = DEFAULT_AUTH_SECRET) {
    if (!token || typeof token !== "string") return null;

    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const [encodedHeader, encodedPayload, encodedSignature] = parts;
    const message = `${encodedHeader}.${encodedPayload}`;

    try {
        const enc = new TextEncoder();
        const key = await crypto.subtle.importKey(
            "raw",
            enc.encode(secret),
            { name: "HMAC", hash: "SHA-256" },
            false,
            ["verify"]
        );

        // Decode signature from base64url to bytes
        const binarySig = base64UrlDecode(encodedSignature);
        const sigBytes = new Uint8Array(binarySig.length);
        for (let i = 0; i < binarySig.length; i++) {
            sigBytes[i] = binarySig.charCodeAt(i);
        }

        const valid = await crypto.subtle.verify("HMAC", key, sigBytes, enc.encode(message));
        if (!valid) return null;

        const payloadJson = base64UrlDecode(encodedPayload);
        const payload = JSON.parse(payloadJson);

        const now = Math.floor(Date.now() / 1000);
        if (payload.exp && payload.exp < now) {
            return null; // Expired
        }

        return payload;
    } catch {
        return null;
    }
}

/**
 * Extracts and verifies Bearer token from Request Authorization header.
 */
export async function getAuthenticatedPilot(request, env) {
    const authHeader = request.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
        return null;
    }

    const token = authHeader.substring(7).trim();
    const secret = env.AUTH_SECRET || DEFAULT_AUTH_SECRET;
    return await verifyPilotToken(token, secret);
}
