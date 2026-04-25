import crypto from "node:crypto";

function base64url(value) {
  return Buffer.from(value)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

const secret = process.env.DECK_PARTNER_JWT_SECRET || process.argv[2];

if (!secret) {
  console.error("Usage: DECK_PARTNER_JWT_SECRET=... node scripts/generate-partner-jwt.mjs");
  process.exit(1);
}

const now = Math.floor(Date.now() / 1000);
const header = { alg: "HS256", typ: "JWT" };
const payload = {
  iss: "partner-app",
  sub: "partner-app",
  aud: "orders-api",
  exp: now + 3600,
  iat: now
};

const encodedHeader = base64url(JSON.stringify(header));
const encodedPayload = base64url(JSON.stringify(payload));
const signingInput = `${encodedHeader}.${encodedPayload}`;
const signature = crypto
  .createHmac("sha256", secret)
  .update(signingInput)
  .digest("base64")
  .replace(/=/g, "")
  .replace(/\+/g, "-")
  .replace(/\//g, "_");

console.log(`${signingInput}.${signature}`);
