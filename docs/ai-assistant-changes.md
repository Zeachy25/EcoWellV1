# AI Wellness Assistant

This document describes the AI wellness assistant added to EcoWell: what it
does, how it is built, how to configure it, and which files changed.

## What users see

- A floating `EcoWell AI` bubble appears on the main app frame, above the
  bottom navigation on Home, Explore, Map, and Dashboard.
- The bubble can be dragged around the screen. Its position is remembered on
  the phone, and it stays inside the app frame (it is not a system overlay, so
  no `SYSTEM_ALERT_WINDOW` permission is needed).
- Tapping the bubble opens a full chat screen at `/ai`.
- The existing `Talk to AI Coach` item in the center `+` menu now opens the
  same chat screen instead of showing a placeholder message.
- The chat screen shows the safety disclaimer, saved history, quick prompts,
  a typing indicator, and a composer that supports up to four lines.
- Replies are kept brief by default. When an assistant reply offers a breathing
  or grounding exercise, a button opens the matching activity in EcoWell.
- The exercise button launches the existing activity runner, so it reuses the
  app's breathing animation, controls, haptics, and completion logging.
- When launched from chat, completing or leaving an exercise adds a short,
  randomly selected built-in follow-up to the conversation. These local-only
  messages are cached on the device, do not call Gemini, and do not use quota.
  Opening the normal breathing or grounding exercise does not add a chat reply.
- If the assistant detects crisis language, it shows a supportive reply plus
  tappable crisis hotline buttons (1553, NCMH mobile numbers, and 911).
- When the network, Edge Function, or Gemini is unavailable, the app inserts a
  local, non-AI fallback suggestion and labels it `Local suggestion`.

## Architecture

| Layer | File | Responsibility |
| --- | --- | --- |
| Domain | `lib/features/ai/domain/ai_message.dart` | `AiMessage`, `AiReply`, and `AiException` models. |
| Domain | `lib/features/ai/domain/ai_safety.dart` | Disclaimer, crisis detection, crisis reply/resources, and local fallback copy. |
| Data | `lib/features/ai/data/ai_repository.dart` | Reads cached/server history, invokes the `ai` Edge Function, and maps errors. |
| State | `lib/features/ai/data/ai_providers.dart` | `AiChatState` and the `AiChatController` (history, send, crisis, fallback, retry). |
| UI | `lib/features/ai/presentation/ai_chat_screen.dart` | Chat screen, empty state, bubbles, crisis card, composer. |
| UI | `lib/features/ai/presentation/ai_chat_head.dart` | Draggable floating bubble and its saved position. |
| Routing | `lib/core/router.dart` | Adds the `/ai` route. |
| Shell | `lib/features/shell/presentation/main_shell.dart` | Places the bubble above the tab content and links the `+` menu item. |
| Cache | `lib/core/offline/json_cache.dart` | Adds `CacheKeys.aiChat(uid)` and clears it on sign-out. |
| Backend | `supabase/ai.sql` | Chat table, daily usage table, RLS, and quota functions. |
| Backend | `supabase/functions/ai/index.ts` | Authenticated Edge Function that calls Gemini. |

### Request flow

1. `AiChatController` adds the user's message optimistically and caches it.
2. `AiRepository.sendMessage` calls the `ai` Edge Function with the message and
   an optional list of nearby green-space names.
3. The Edge Function verifies the caller's JWT with the service-role client.
4. Crisis language is answered locally by the function (the model is never
   called), and the exchange is saved.
5. Otherwise the function consumes one daily quota unit, loads the last 12
   messages plus the user's first name, and calls Gemini.
6. The function saves the user and assistant rows, including the optional
   assistant `action`, then returns `reply`, `crisis`, `action`, and the saved
   `messages`. Crisis replies use a null stored action and never offer an
   exercise.
7. The controller replaces the optimistic user row with the saved rows and
   caches the conversation.

The action is either `breathing`, `grounding`, or null. Offline fallbacks use
the same exercise buttons for stress/panic and low mood; general and nature
suggestions do not offer an exercise action.

For activities launched from the AI chat, the runner returns whether the user
completed the exercise or exited early. The chat then adds one of several
prewritten follow-ups for that exercise and outcome. This only happens for the
AI chat entry point, including when chat falls back to the activity list.

If `GEMINI_API_KEY` is missing the function returns `ai_unavailable` without
saving anything. If the Gemini call fails, the quota unit is refunded.

## Safety and privacy

- The Gemini API key lives only in Supabase secrets. It is never shipped in the
  Flutter app.
- The system prompt limits the assistant to supportive wellness guidance and
  forbids diagnoses, prescriptions, and requests for sensitive information.
- Crisis detection exists in both the app and the Edge Function. The app can
  answer immediately while offline; the server is the source of truth.
- The function stores the user id, role, content, optional action, and
  timestamp. The app may send nearby green-space names, but no coordinates are
  sent to Gemini.
- Users can read only their own rows (`auth.uid() = user_id`). Direct
  insert/update/delete is not granted to clients; only the Edge Function
  writes through the service role.
- Assistant replies are general wellness suggestions, not medical advice, and
  the chat screen always shows that disclaimer.

## Offline behavior

- The most recent conversation is stored with `JsonCache` under
  `ai_chat:<user-id>` and is loaded before the server request completes.
- Local-only fallback replies survive a server-history refresh.
- Signing out clears the cached conversation with the other personal caches.
- Offline fallback replies are deterministic and keyword-based. They suggest
  the matching in-app breathing or grounding exercise, a green-space walk, or
  a small reset, and are clearly marked as local.

## Daily quota

- Default limit: 30 assistant messages per user per day.
- The limit is stored in `public.ai_usage` and enforced by
  `public.consume_ai_quota(uuid, integer)`.
- Crisis replies do not consume quota because they never call the model.
- Failed Gemini calls refund the quota unit with `public.refund_ai_quota(uuid)`.
- When the limit is reached the app shows an error, keeps the text in the
  composer for a retry, and does not insert a local fallback.

## Configuration

### 1. Create the database objects

Run `supabase/ai.sql` in the Supabase SQL Editor or apply it as a migration.
It is safe to run again.

### 2. Set the Gemini secret and options

```sh
supabase secrets set GEMINI_API_KEY=<your-gemini-api-key>
# Optional:
supabase secrets set GEMINI_MODEL=gemini-3.5-flash-lite
supabase secrets set AI_DAILY_LIMIT=30
```

`GEMINI_MODEL` defaults to `gemini-3.5-flash-lite`; `AI_DAILY_LIMIT` defaults
to `30`. Gemini uses structured JSON output and a 350-token output ceiling;
the prompt requests at most three short sentences (about 60 words) by default.

### 3. Deploy the Edge Function

```sh
supabase functions deploy ai
```

The function must keep JWT verification enabled. `supabase/config.toml`
contains:

```toml
[functions.ai]
verify_jwt = true
```

The Flutter app invokes the function with the signed-in user's session, so an
anonymous caller cannot use the Gemini quota.

### 4. Run the app

No new Flutter packages are required. `url_launcher` (already used by the app)
opens the dialer for crisis numbers.

```sh
flutter pub get
flutter run
```

## Tests

```sh
flutter analyze
flutter test
deno check supabase/functions/ai/index.ts
```

The new tests are:

- `test/ai_message_test.dart`: message serialization, local rows, server rows,
  missing fields, and fallback error codes.
- `test/ai_safety_test.dart`: English and Filipino crisis phrases, ordinary
  distress, fallback branches, and crisis resources.

## Known limitations

- Crisis detection is keyword-based and cannot catch every phrasing. The
  disclaimer and the in-chat crisis card remain visible regardless.
- The AI conversation is capped at 100 saved messages per user in the client
  query and 12 history messages per Gemini request.
- The floating bubble lives inside the main tab shell, so it is not visible
  on full-screen pages such as the chat screen itself, activity runners, or
  authentication screens.
- The assistant is not a substitute for professional care and does not provide
  diagnosis or treatment.
