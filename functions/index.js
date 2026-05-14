/**

 * Set env:    add SOUNDCLOUD_CLIENT_ID to functions/.env
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {setGlobalOptions} = require("firebase-functions");
const logger = require("firebase-functions/logger");
const {OpenAI} = require("openai");
const axios = require("axios");

initializeApp();
const db = getFirestore();

const openaiApiKey = defineSecret("OPENAI_API_KEY");

setGlobalOptions({maxInstances: 10, region: "europe-west1"});

const CORS_ORIGIN = "https://musicapp-19bff.web.app";

exports.musicAgent = onCall(
    {secrets: [openaiApiKey], cors: [CORS_ORIGIN]},
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
              content:
                "You are Aria, a warm and music-obsessed AI DJ " +
                "living inside a music app. " +
                "You love talking about music, moods, genres, " +
                "artists, and vibes. " +
                "When the user asks for music, respond naturally and " +
                "conversationally (1-3 sentences max), like a friend " +
                "who really knows their music. " +
                "You can comment on the mood, suggest a genre, " +
                "mention an artist, or just vibe with them. " +
                "Then provide Spotify search keywords. " +
                "Always respond in JSON with exactly this shape: " +
                "{\"reply\": \"your conversational message\", " +
                "\"keywords\": [\"keyword1\", \"keyword2\", \"kw3\"]}. " +
                "Keywords should be 3-5 short Spotify search terms.",
            },
            {role: "user", content: prompt},
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
        const reply = parsed.reply || "Let me find some tracks for you!";
        const keywords = Array.isArray(parsed.keywords) ?
          parsed.keywords.map((k) => String(k).trim()).filter(Boolean) :
          [];
        return {reply, keywords};
      } catch (error) {
        logger.error("OpenAI musicAgent error", error);
        throw new HttpsError("internal", "AI request failed");
      }
    },
);

exports.getRecommendations = onCall(
    {secrets: [openaiApiKey], cors: [CORS_ORIGIN]},
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

exports.soundcloudSearch = onCall(
    {cors: [CORS_ORIGIN]},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Sign in required");
      }
      const clientId = process.env.SOUNDCLOUD_CLIENT_ID;
      if (!clientId) {
        throw new HttpsError(
            "internal",
            "SoundCloud client ID not configured. " +
            "Add SOUNDCLOUD_CLIENT_ID to functions/.env",
        );
      }
      const data = request.data || {};
      const query = data.query || null;
      const limit = data.limit || 12;
      const params = {
        client_id: clientId,
        limit,
      };
      if (query) {
        params.q = query;
      } else {
        params.linked_partitioning = "true";
      }
      try {
        const res = await axios.get(
            "https://api.soundcloud.com/tracks",
            {params},
        );
        const body = res.data;
        let tracks = [];
        if (Array.isArray(body)) {
          tracks = body;
        } else if (body && Array.isArray(body.collection)) {
          tracks = body.collection;
        }
        return {tracks};
      } catch (error) {
        const detail = error &&
          error.response &&
          error.response.data ?
          error.response.data :
          error;
        logger.error("SoundCloud proxy error", detail);
        throw new HttpsError("internal", "SoundCloud request failed");
      }
    },
);
