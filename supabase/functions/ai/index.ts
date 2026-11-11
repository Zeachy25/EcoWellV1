// EcoWell AI assistant Edge Function.
//
// The Flutter app calls this with the signed-in user's JWT. The function
// verifies the user, applies a daily quota, checks for crisis language, then
// calls Gemini with a tightly scoped wellness-coach prompt. The API key stays
// in Supabase secrets and is never exposed to the client.

import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";
const DAILY_LIMIT = Number(Deno.env.get("AI_DAILY_LIMIT") ?? "30");
const MAX_MESSAGE_LENGTH = 2000;
const HISTORY_LIMIT = 12;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `You are EcoWell's assistant, a calm, friendly nature-based wellness companion inside a mobile app.

STYLE
- Match the length of the user's message. A greeting or short message gets 1-2 short sentences.
- Default to 1-3 short sentences and about 60 words or fewer. Only go longer if the user asks for steps or a detailed explanation.
- Write like a friendly person texting: plain, warm, no headings, no bullet lists, no emojis unless the user uses them.
- Do not introduce yourself at length or list what you can do unless asked.
- Ask at most one short question per reply, and only when it helps.
- Give one suggestion at a time, not a menu of options.

EXAMPLES
User: Hi
Assistant: Hi! How are you feeling today?

User: I'm stressed about exams
Assistant: That sounds heavy. Would you like to try the breathing exercise in EcoWell, or talk it through first?

SCOPE
- You help with stress, mood, breathing, time in green spaces, and using EcoWell.
- You are not a therapist and you do not diagnose or give medical advice.
- If asked about unrelated topics, answer briefly or gently steer back to wellness.

SAFETY
- If the user mentions self-harm, suicide, or being in danger, drop the normal style. Respond with warmth and care, encourage them to contact local emergency services, a crisis helpline, or someone they trust right now, and do not give normal wellness tips in that reply.

OUTPUT CONTRACT
Return only this JSON shape:
{"reply": "...", "action": "none" | "breathing" | "grounding"}

- Put your normal, user-facing answer in "reply".
- Set "action" to "breathing" only when your reply invites the user to start the app's breathing exercise.
- Set "action" to "grounding" only when your reply invites the user to start the grounding exercise.
- Otherwise use "none".
- Do not mention this JSON or the action field.
- When offering an app exercise, do not promise a specific duration.`;

const CRISIS_REPLY = `I'm really sorry you're carrying this right now. You deserve support, and you don't have to face it alone.

Please reach out now:
• National Center for Mental Health (NCMH) Crisis Hotline: 1553 (nationwide, 24/7)
• NCMH mobile: 0917-899-8727 or 0966-351-4518
• Emergency: 911

If you are in immediate danger, please call 911 or go to the nearest emergency room. If you can, stay with someone you trust while you make contact.`;

const CRISIS_PATTERNS = [
  /suicid/i,
  /kill(ing)? myself/i,
  /end(ing)? my life/i,
  /self[-\s]?harm/i,
  /hurt(ing)? myself/i,
  /don'?t want to (live|be alive)/i,
  /better off dead/i,
  /no reason to live/i,
  /magpakamatay/i,
  /patayin (ang )?sarili/i,
  /saktan (ang )?sarili/i,
  /(ayoko|ayaw ko) nang mabuhay/i,
];

type ChatRole = "user" | "assistant";

interface ChatRow {
  role: ChatRole;
  content: string;
}

type AiAction = "none" | "breathing" | "grounding";

interface CoachReply {
  reply: string;
  action: AiAction;
}

const COACH_RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    reply: { type: "STRING" },
    action: {
      type: "STRING",
      enum: ["none", "breathing", "grounding"],
    },
  },
  required: ["reply", "action"],
};

interface AiRequestBody {
  message?: unknown;
  nearby?: unknown;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function isCrisis(text: string): boolean {
  return CRISIS_PATTERNS.some((pattern) => pattern.test(text));
}

function nearbyNames(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim().slice(0, 100))
    .filter(Boolean)
    .slice(0, 5);
}

function errorCode(error: unknown): string {
  if (error && typeof error === "object" && "code" in error) {
    const code = (error as { code?: unknown }).code;
    if (typeof code === "string") return code;
  }
  return "ai_unavailable";
}

function detectAction(text: string): AiAction {
  if (/grounding exercise|5[-\s]?4[-\s]?3[-\s]?2[-\s]?1/i.test(text)) {
    return "grounding";
  }
  if (
    /breathing exercise|breathing pause|breath ?work|\bbreathe in\b/i.test(text)
  ) {
    return "breathing";
  }
  return "none";
}

function parseCoachReply(text: string): CoachReply {
  const cleaned = text
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  try {
    const data = JSON.parse(cleaned);
    const reply = typeof data?.reply === "string" ? data.reply.trim() : "";
    const rawAction = typeof data?.action === "string"
      ? data.action.toLowerCase()
      : "none";
    const action: AiAction = rawAction === "breathing" ||
        rawAction === "grounding"
      ? rawAction
      : "none";
    if (reply) return { reply, action };
  } catch {
    // The model returned plain text instead of the requested JSON.
  }
  return { reply: cleaned, action: detectAction(cleaned) };
}

async function insertMessages(
  admin: SupabaseClient,
  userId: string,
  userText: string,
  assistantText: string,
  action: AiAction = "none",
): Promise<Record<string, unknown>[]> {
  const stamp = Date.now();
  const { data, error } = await admin.from("chat_messages").insert([
    {
      user_id: userId,
      role: "user",
      content: userText,
      created_at: new Date(stamp).toISOString(),
    },
    {
      user_id: userId,
      role: "assistant",
      content: assistantText,
      action: action === "none" ? null : action,
      created_at: new Date(stamp + 1).toISOString(),
    },
  ]).select("id, role, content, action, created_at");
  if (error) {
    console.error("Could not save AI chat messages", error);
    return [];
  }
  return (data ?? []) as Record<string, unknown>[];
}

async function callGemini(
  message: string,
  history: ChatRow[],
  profileName: string | null,
  nearby: string[],
): Promise<CoachReply> {
  // Gemini expects a user turn first; drop any leading saved assistant rows
  // when older messages have rolled out of the history window.
  const conversation = [...history];
  while (conversation.length > 0 && conversation[0].role === "assistant") {
    conversation.shift();
  }

  const contents = conversation.map((row) => ({
    role: row.role === "assistant" ? "model" : "user",
    parts: [{ text: row.content }],
  }));
  contents.push({ role: "user", parts: [{ text: message }] });

  const context: string[] = [];
  if (profileName) context.push(`The user's first name is ${profileName}.`);
  if (nearby.length > 0) {
    context.push(
      `Nearby green spaces the app can suggest: ${nearby.join(", ")}.`,
    );
  }

  const systemInstruction = context.length > 0
    ? `${SYSTEM_PROMPT}\n\nApp context:\n${context.join("\n")}`
    : SYSTEM_PROMPT;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25_000);
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(GEMINI_MODEL)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemInstruction }] },
          contents,
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 350,
            responseMimeType: "application/json",
            responseSchema: COACH_RESPONSE_SCHEMA,
          },
        }),
        signal: controller.signal,
      },
    );

    if (!response.ok) {
      const detail = await response.text();
      console.error(`Gemini error ${response.status}: ${detail}`);
      throw new Error("Gemini request failed");
    }

    const data = await response.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    const text = Array.isArray(parts)
      ? parts
        .map((part: { text?: unknown }) =>
          typeof part?.text === "string" ? part.text : ""
        )
        .join("")
        .trim()
      : "";

    if (!text) {
      console.error("Gemini returned no text", data);
      throw new Error("Gemini returned no text");
    }
    return parseCoachReply(text);
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") {
    return json({ code: "method_not_allowed", error: "Method not allowed" }, 405);
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return json({ code: "unauthorized", error: "Please sign in first." }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: { user }, error: authError } = await admin.auth.getUser(token);
  if (authError || !user) {
    return json({ code: "unauthorized", error: "Your session has expired." }, 401);
  }

  let body: AiRequestBody;
  try {
    body = await request.json();
  } catch {
    return json({ code: "invalid_json", error: "Invalid request." }, 400);
  }

  const message = typeof body.message === "string"
    ? body.message.trim()
    : "";
  if (!message) {
    return json({ code: "empty_message", error: "Please type a message." }, 400);
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return json(
      {
        code: "message_too_long",
        error: `Please keep messages under ${MAX_MESSAGE_LENGTH} characters.`,
      },
      400,
    );
  }

  // Crisis language gets a local safety response and never reaches the model.
  if (isCrisis(message)) {
    const messages = await insertMessages(
      admin,
      user.id,
      message,
      CRISIS_REPLY,
    );
    return json({
      reply: CRISIS_REPLY,
      crisis: true,
      action: "none",
      messages,
    });
  }

  if (!GEMINI_API_KEY) {
    return json(
      {
        code: "ai_unavailable",
        error: "The AI assistant is not configured yet.",
      },
      503,
    );
  }

  const { data: allowed, error: quotaError } = await admin.rpc(
    "consume_ai_quota",
    { p_user_id: user.id, p_limit: DAILY_LIMIT },
  );
  if (quotaError) {
    console.error("Quota check failed", quotaError);
    return json(
      { code: "ai_unavailable", error: "The AI assistant is unavailable." },
      503,
    );
  }
  if (!allowed) {
    return json(
      {
        code: "rate_limited",
        error: "You have reached today's AI limit. Please try again tomorrow.",
      },
      429,
    );
  }

  const { data: historyRows } = await admin
    .from("chat_messages")
    .select("role, content")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false })
    .limit(HISTORY_LIMIT);

  const history = ((historyRows ?? []) as ChatRow[]).reverse();

  const { data: profile } = await admin
    .from("profiles")
    .select("full_name")
    .eq("id", user.id)
    .maybeSingle();

  const fullName = typeof profile?.full_name === "string"
    ? profile.full_name.trim()
    : "";
  const firstName = fullName.split(/\s+/)[0] || null;

  try {
    const coachReply = await callGemini(
      message,
      history,
      firstName,
      nearbyNames(body.nearby),
    );
    const messages = await insertMessages(
      admin,
      user.id,
      message,
      coachReply.reply,
      coachReply.action,
    );
    return json({
      reply: coachReply.reply,
      crisis: false,
      action: coachReply.action,
      messages,
    });
  } catch (error) {
    console.error("AI coach request failed", error);
    // The model call failed, so the user should not lose quota for it.
    await admin.rpc("refund_ai_quota", { p_user_id: user.id });
    return json(
      {
        code: errorCode(error),
        error: "The AI assistant is unavailable right now.",
      },
      503,
    );
  }
});
