/**
 * Cloud Functions: OpenAI proxy + recommendation queries.
 * Set secret: firebase functions:secrets:set OPENAI_API_KEY
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {setGlobalOptions} = require("firebase-functions");
const logger = require("firebase-functions/logger");
const {OpenAI} = require("openai");

initializeApp();
const db = getFirestore();

const openaiApiKey = defineSecret("OPENAI_API_KEY");

setGlobalOptions({maxInstances: 10, region: "europe-west1"});

exports.musicAgent = onCall(
    {secrets: [openaiApiKey]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const prompt = request.data && request.data.prompt;
      if (!prompt || typeof prompt !== "string") {
        throw new HttpsError("invalid-argument", "prompt is required");
      }
      const openai = new OpenAI({apiKey: openaiApiKey.value()});
      try {
        const response = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: "You are a music discovery agent. Convert the user's " +
                "mood or request into 3-5 short SoundCloud search keywords. " +
                "Return ONLY the keywords separated by commas.",
            },
            {role: "user", content: prompt},
          ],
        });
        const keywords = response.choices[0].message.content || "";
        return {keywords};
      } catch (error) {
        logger.error("OpenAI musicAgent error", error);
        throw new HttpsError("internal", "AI request failed");
      }
    },
);

exports.getRecommendations = onCall(
    {secrets: [openaiApiKey]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const uid = request.auth.uid;
      const snap = await db.collection("users").doc(uid)
          .collection("listen_history")
          .orderBy("playedAt", "desc")
          .limit(15)
          .get();
      const lines = snap.docs.map((d) => {
        const x = d.data();
        const title = x.title || "";
        const artist = x.artist || "";
        return title + " — " + artist;
      });
      const openai = new OpenAI({apiKey: openaiApiKey.value()});
      const historyText = lines.length ? lines.join("\n") : "No history yet.";
      try {
        const response = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content: "Return JSON only with shape " +
                "{\"queries\":[\"string\", ...]} and exactly 5 diverse " +
                "SoundCloud search queries for this user.",
            },
            {
              role: "user",
              content: "Recent listens:\n" + historyText,
            },
          ],
          response_format: {type: "json_object"},
        });
        const raw = response.choices[0].message.content || "{}";
        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch (e) {
          parsed = {};
        }
        let queries = parsed.queries;
        if (!Array.isArray(queries)) {
          queries = [];
        }
        queries = queries.map((q) => String(q).trim()).filter(Boolean);
        if (queries.length === 0) {
          queries = [
            "chill beats",
            "indie pop",
            "hip hop instrumental",
            "acoustic covers",
            "electronic dance",
          ];
        }
        return {queries};
      } catch (error) {
        logger.error("OpenAI getRecommendations error", error);
        return {
          queries: [
            "lofi hip hop",
            "pop hits",
            "rock classics",
            "electronic chill",
            "r&b slow jams",
          ],
        };
      }
    },
);
