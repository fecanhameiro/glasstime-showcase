const jwt = require("jsonwebtoken");
const http2 = require("http2");

const BUNDLE_ID = "com.prismlabs.glasstime";

// Use sandbox for development, production for release
const APNS_HOST = process.env.APNS_PRODUCTION === "true"
  ? "api.push.apple.com"
  : "api.sandbox.push.apple.com";

// Cache JWT (valid 1h, Apple recommends refresh no more than every 20min)
let cachedJWT = null;
let jwtExpiry = 0;

/**
 * Generate a JWT token for APNs authentication.
 */
function generateJWT() {
  const keyContent = process.env.APNS_AUTH_KEY;
  if (!keyContent) throw new Error("APNS_AUTH_KEY not configured");

  // Restore newlines (stored with | delimiter in .env)
  const key = keyContent.replace(/\|/g, "\n");

  return jwt.sign({}, key, {
    algorithm: "ES256",
    keyid: process.env.APNS_KEY_ID,
    issuer: process.env.APNS_TEAM_ID,
    expiresIn: "1h",
  });
}

function getJWT() {
  const now = Date.now();
  if (cachedJWT && now < jwtExpiry) return cachedJWT;
  cachedJWT = generateJWT();
  jwtExpiry = now + 20 * 60 * 1000;
  return cachedJWT;
}

/**
 * Send an APNs push notification to end or update a Live Activity.
 *
 * @param {string} pushToken — The ActivityKit push token (hex string)
 * @param {boolean} shouldEnd — true: end LA (disappears), false: update to completed state (stays visible)
 */
async function sendAPNsPush(pushToken, shouldEnd = true) {
  const token = getJWT();
  const timestamp = Math.floor(Date.now() / 1000);

  const aps = {
    timestamp: timestamp,
    event: shouldEnd ? "end" : "update",
    "content-state": {
      remainingSeconds: 0,
      elapsedSeconds: 0,
      totalDurationSeconds: 0,
      timerState: "completed",
      timerStartDate: null,
      timerEndDate: null,
    },
  };

  // Only add dismissal-date when ending (immediate removal from Lock Screen)
  if (shouldEnd) {
    aps["dismissal-date"] = timestamp;
  }

  const payload = JSON.stringify({
    aps: aps,
  });

  return new Promise((resolve, reject) => {
    const client = http2.connect(`https://${APNS_HOST}`);

    client.on("error", (err) => {
      client.close();
      reject(err);
    });

    const headers = {
      ":method": "POST",
      ":path": `/3/device/${pushToken}`,
      "authorization": `bearer ${token}`,
      "apns-topic": `${BUNDLE_ID}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": "10",
      "content-type": "application/json",
    };

    const req = client.request(headers);

    let responseData = "";
    let statusCode;

    req.on("response", (hdrs) => {
      statusCode = hdrs[":status"];
    });

    req.on("data", (chunk) => {
      responseData += chunk;
    });

    req.on("end", () => {
      client.close();

      if (statusCode === 200) {
        console.log("APNs push sent successfully");
        resolve();
      } else {
        const error = new Error(`APNs returned ${statusCode}: ${responseData}`);
        error.statusCode = statusCode;
        console.error("APNs error:", statusCode, responseData);
        reject(error);
      }
    });

    req.write(payload);
    req.end();
  });
}

module.exports = { sendAPNsPush };
