EcoWell Development Plan & Architecture
Prepared for the EcoWell BSIT capstone. Stack: Flutter + Supabase (PostgreSQL/PostGIS). Last updated October 15, 2026.
1. Product summary
EcoWell is an Android-first mobile app that helps users reduce stress by visiting nearby green spaces. It detects arrival with geofencing, measures stress before and after each visit with the 4-item Perceived Stress Scale (PSS-4), and turns the difference into a Stress Reduction Score. Around that core it adds a Quiet Score for each place, guided breathing and grounding activities, a progress dashboard, a community feed, an AI wellness coach, weather-aware suggestions and smart notifications.
Target users are adults aged 18 to 60. EcoWell is a wellness tool, not a medical or diagnostic product.
Core value loop: Discover a green space → Arrive (geofence) → Pre-assessment → Spend time or do an activity → Post-assessment + Quiet rating → See Stress Reduction Score and streak.
2. Technology stack
Layer
Choice
Notes
Mobile UI
Flutter (Dart), Material 3
One codebase, Android first
State management
Riverpod
Dependency injection + testable state
Navigation
go_router
Declarative routes, auth redirects
Backend platform
Supabase
Auth, Postgres, Storage, Realtime, Edge Functions
Database
PostgreSQL + PostGIS
Relational, analytics, geospatial
Maps
google_maps_flutter
Markers and polygons
Location
geolocator + a geofencing strategy (see F4)
Highest technical risk
Charts
fl_chart
Dashboard trends
PDF export
pdf + printing
Client-side report
Push notifications
Firebase Cloud Messaging + flutter_local_notifications
Firebase is used only for push, not for data
Weather
Open-Meteo (no key) or OpenWeatherMap
Called from an Edge Function
AI coach
An LLM API (for example the Claude API)
Called only from an Edge Function
Images
image_picker + flutter_image_compress
Upload to Supabase Storage
Server logic
SQL functions (RPC) + Edge Functions (TypeScript)
Rules that must not be bypassed
Scheduling
pg_cron
Reminders, stale-visit cleanup
Tooling
Git/GitHub, Supabase CLI, Android Studio or VS Code

3. System architecture
┌────────────────────────── Flutter app (Android) ───────────────────────────┐
│ Presentation : screens + widgets          (features/*/presentation)         │
│ State        : Riverpod providers/notifiers                                 │
│ Domain       : models (Visit, GreenSpace, Assessment ...)                   │
│ Data         : repositories -> Supabase client, Edge Functions, local cache │
│ Device       : GPS/geofence · notifications · camera/gallery · PDF          │
└───────────────┬───────────────────────────────────────┬────────────────────┘
                │ HTTPS + JWT (Supabase Auth)            │ HTTPS
┌───────────────▼──────────── Supabase ────────────┐  ┌──▼─────────────────┐
│ Auth · Postgres + PostGIS (RLS on every table)    │  │ Google Maps SDK    │
│ Storage (avatars, post-media) · Realtime (feed)   │  │ Firebase (push)    │
│ RPC: complete_visit, nearby_green_spaces, stats   │  └────────────────────┘
│ Edge Functions: ai-coach · weather · notify ·     │──► Weather API
│                 delete-account                    │──► LLM API
│ pg_cron: reminders, abandon stale visits          │
└───────────────────────────────────────────────────┘
Design principles
• The app never calls third-party AI or weather APIs directly. Edge Functions hold the secrets.
• Security is enforced in the database (Row Level Security), not only in app code.
• Rules that must not be bypassed live in the database: PSS-4 scoring, the 18-60 age rule, one pre and one post assessment per visit, one Quiet rating per visit, streak updates.
• Feature-first folders: each feature owns its screens, state and data access.
• Repository pattern: screens talk to repositories, not to Supabase directly, so data sources can change without touching the UI.
3.1 The core visit sequence
1. The app loads cached green spaces (boundary + center) when it starts or the map opens.
2. Location monitoring: operating-system circular geofences (center + radius) wake the app, then the app confirms the user is inside the real polygon.
3. On confirmed entry, the app inserts a visit (status in_progress) and shows an arrival prompt.
4. Pre-assessment: four PSS-4 questions are saved as an assessment of type pre.
5. Optional guided activity: saved to activity_logs.
6. On exit, or when the user taps End visit: post-assessment (type post) and a Quiet rating from 1 to 5.
7. The RPC complete_visit(visit_id) sets exit_time and status, updates the streak and returns a summary.
8. The app shows the Stress Reduction Score (pre total minus post total; positive means less stress) and refreshes the dashboard.
Edge cases to handle: GPS drift (require a short dwell time and an accuracy threshold), visit left open (auto-abandon after about 6 hours with pg_cron), no network (queue the write and retry), user denies location permission (show a manual Start visit button when near a place).
4. Data architecture
4.1 Implemented in 001_foundation.sql
Table / object
Purpose
Key rules
profiles
One row per user: name, birthdate, streak fields
Created by a signup trigger; age 18-60 enforced
green_spaces
Place with polygon boundary and center point
PostGIS GiST indexes
visits
One row per trip to a place
status: in_progress, completed, abandoned
assessments
PSS-4 answers (0-4 each)
total_score computed by the database; unique per visit and type
quiet_ratings
Quiet Score 1-5
One per user per visit
activities, activity_logs
Guided content and completion history
steps stored as JSONB
runs
One row per Quick Run (GPS walk/run recorded in the app)
path polyline as JSONB, offline queue on the phone (runs.sql)
visit_summaries (view)
Pre score, post score, Stress Reduction Score
Respects RLS
green_spaces_with_stats (view)
Average Quiet Score and rating count
Respects RLS
nearby_green_spaces()
Places within a radius, sorted by distance
Used by the map
4.2 Planned migrations
002_community.sql
• posts (user, place, optional visit, caption, created_at), post_media, comments, reactions (one per user per post), my_day (24-hour stories with expires_at), reports (for moderation).
• A public_profiles view that exposes only id, display name and avatar, never birthdate or scores, so the feed can show authors.
• RLS: signed-in users read; users create, edit and delete only their own rows.
003_ai_coach.sql
• chat_messages (user, role, content, created_at) and ai_usage (user, day, count) for rate limiting.
004_notifications.sql
• device_tokens (user, token), user_settings (notification toggles, reminder time, quiet hours), notifications (type, title, body, sent_at, read_at).
005_functions_and_cron.sql
• complete_visit(visit_id): closes the visit and updates streak fields.
• abandon_stale_visits(): scheduled cleanup.
• get_user_stats() and weekly_trend() for the dashboard.
Streak rule: a day counts when the user completes at least one visit that day, using Asia/Manila time. A visit on the day after the last counted day extends the streak; any longer gap resets it to 1. longest_streak keeps the maximum.
4.3 Storage buckets
• avatars and covers: public read, users write only inside their own folder (<uid>/...), created in user_profile.sql.
• post-media: images only, size limit (for example 5 MB), signed-in read, users write their own files.
• myday: same rules, files removed after 24 hours.
5. Project structure
5.1 Flutter app
ecowell/
├─ lib/
│  ├─ main.dart
│  ├─ core/
│  │  ├─ config.dart              Supabase URL + publishable key
│  │  ├─ router.dart              go_router + auth redirect
│  │  ├─ theme.dart
│  │  ├─ constants/               PSS-4 questions, score labels, strings
│  │  ├─ services/
│  │  │  ├─ location_service.dart
│  │  │  ├─ geofence_service.dart
│  │  │  ├─ notification_service.dart
│  │  │  └─ connectivity_service.dart
│  │  └─ utils/                   Manila-time helpers, polygon math, formatters
│  ├─ shared/
│  │  ├─ widgets/                 cards, buttons, loading/error/empty states
│  │  └─ models/                  profile.dart
│  └─ features/                   each has data/ domain/ presentation/
│     ├─ auth/                    splash, login, register, consent
│     ├─ home/                    bottom-navigation shell, home tab
│     ├─ map/                     map screen, place details, nearby list
│     ├─ visit/                   arrival prompt, PSS-4, active visit, result
│     ├─ activities/              breathing, grounding (guided)
│     ├─ runs/                    Quick Run: GPS walk/run recorder + history
│     ├─ dashboard/               streak, trends, history, PDF export
│     ├─ community/               feed, create post, comments, MyDay, profiles
│     ├─ ai_coach/                chat
│     ├─ explore/                 tips and articles
│     ├─ notifications/           inbox, preferences
│     └─ settings/                profile, privacy, delete account
├─ test/                          unit + widget tests
├─ integration_test/              end-to-end flows
├─ android/                       manifest, permissions, Maps key
└─ pubspec.yaml
5.2 Supabase and repository root
supabase/
├─ config.toml
├─ migrations/
│  ├─ 001_foundation.sql          (done)
│  ├─ 002_community.sql
│  ├─ 003_ai_coach.sql
│  ├─ 004_notifications.sql
│  └─ 005_functions_and_cron.sql
├─ functions/
│  ├─ ai-coach/index.ts
│  ├─ weather-suggestion/index.ts
│  ├─ send-notifications/index.ts
│  └─ delete-account/index.ts
└─ seed/
   ├─ green_spaces.sql            real boundaries (drawn on geojson.io)
   └─ activities.sql
docs/                              ERD, test logs, screenshots, manuals
README.md  .gitignore
5.3 Conventions
• Database names in snake_case, Dart in lowerCamelCase, files in snake_case.
• One migration per feature. Never edit a migration that has already been applied; add a new one.
• Branch per feature (feature/map, feature/visit-flow). Run flutter analyze and flutter test before merging.
6. Feature plan
Each feature has a goal, the data it uses, and a clear definition of done.
F1. Authentication (written, needs testing). Splash, register with age check, login, logout, route protection. Done when a new user can register, log in and see their profile on Home.
F2. Consent, profile and settings. A Data Privacy Act consent screen on first launch (what is collected, why, and the user's rights), edit profile, avatar upload, notification preferences, export my data, delete my account (Edge Function with the secret key). Done when a user can see, change and delete their own data.
F3. Map and green spaces. Google Map with markers, user location, nearby list from nearby_green_spaces(), place details with photo, description and average Quiet Score, and directions. Opening the Google Maps app with url_launcher is free; the Directions API needs billing. Cache the green space list locally. Done when a user can find a place and navigate to it.
F4. Visit flow and geofencing. Implements section 3.1.
• Strategy: register circular geofences with the operating system to wake the app, then verify against the real polygon with point-in-polygon math. Keep a foreground location stream while a visit is active.
• Require a dwell time (for example 60 to 120 seconds inside) and an accuracy threshold before starting a visit.
• Show a foreground-service notification while tracking. Ask for foreground location first, then background location with a clear explanation.
• Always provide a manual Start visit button when the user is near a place.
• Evaluate maintained geofencing plugins and field test early; this is the riskiest feature.
• Done when walking into and out of a real park creates and closes a visit reliably on at least two phones.
F5. PSS-4 assessment and scoring. Four questions on a 0 to 4 scale (never to very often). Items 2 and 3 are reverse-scored, and the database computes the total. Show results with gentle, non-diagnostic wording. Done when a pre and post assessment produce the correct Stress Reduction Score.
F6. Quiet Score. A 1 to 5 rating after each visit, one per visit, with the average shown on place cards through green_spaces_with_stats.
F7. Activities and Quick Run. Quick Run (the "+" button) is a Strava-style GPS recorder: the user picks walk or run, the map draws their path while the timer, distance and pace run, and the finished run is saved offline first (SQLite) then synced to the runs table (runs.sql). It keeps recording with the screen off via the foreground service and recovers an interrupted run on the next opening. Breathing exercise (animated circle with timer, such as box breathing) and 5-4-3-2-1 grounding live in the activities table; completions go to activity_logs.
F8. Dashboard and export. Streak, total visits, average Stress Reduction Score, weekly trend chart (fl_chart), visited places history, and a PDF summary (pdf + printing).
F9. Community and MyDay. Paged feed, create post with compressed photos, comments, reactions, report button, 24-hour MyDay stories, Realtime updates for new posts. Show only display name and avatar for authors. Facebook-style profiles (/u/:id, user_profile.sql): cover photo, profile picture, joined date, follower/following counts, bio, photos grid and the person's posts; follow/unfollow for others, Edit profile sheet (name, bio, avatar + cover upload) and Log out on your own. Profiles never expose wellness scores (streak, stress, visits, runs). Profile headers and timelines are cached per user (JsonCache keys user_profile:<uid>, user_posts:<uid>), so any profile opened while online still renders offline with a "last saved info" hint.
F10. AI wellness coach. Chat screen that calls the ai-coach Edge Function.
• The function builds the prompt: supportive, brief, non-diagnostic, suggests nearby green spaces and activities.
• Store messages, rate limit per user per day, keep API keys in Supabase secrets.
• Safety: detect crisis language and show local crisis hotline details instead of normal coaching. Verify the current Philippine hotline numbers before release.
F11. Weather suggestions. An Edge Function fetches the forecast for the user's area and returns a short suggestion (good time to go out, rain warning) shown on Home.
F12. Notifications. Visit reminders at the user's chosen time, streak-at-risk nudges, weather tips. FCM tokens are saved in device_tokens; pg_cron triggers send-notifications. Respect quiet hours and opt-outs.
F13. Explore. Curated tips and short articles about nature and wellbeing, stored as simple rows or bundled JSON at first.
7. Security, privacy and safety
• Row Level Security on every table, tested with two accounts (user A must never read user B's visits or assessments).
• The publishable key is safe in the app. The secret (service_role) key exists only inside Edge Functions. All third-party API keys are stored as Supabase secrets.
• Data Privacy Act of 2012 (RA 10173): collect only what is needed, explain the purpose, get consent before collecting location, let users access and delete their data, and avoid storing a continuous location trail (store visits, not tracks).
• Encryption: TLS in transit and encryption at rest provided by the platform. Check Supabase's security documentation for the exact wording before stating it in your paper.
• Auth: email confirmation turned on before real-user testing, minimum 8-character passwords, platform rate limits.
• Community: report and remove content, authenticated access only, no personal data in public views.
• Show a clear disclaimer that EcoWell is not a substitute for professional mental health care.
8. Android configuration checklist
• Permissions: INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE (and the location foreground-service type on Android 14), POST_NOTIFICATIONS (Android 13 and up).
• Google Maps API key in AndroidManifest meta-data, restricted to your package name and SHA-1 fingerprint.
• Check each plugin's minimum SDK and set minSdk accordingly.
• Some phone brands kill background apps aggressively. Test on real devices and add a short in-app guide for battery settings.
• Use emulator GPS simulation for early work, but validate on physical phones outdoors.
9. Development workflow
• Use two Supabase projects if possible: one for development, one for the demo and evaluation.
• Supabase CLI: supabase init, supabase link, supabase db push for migrations, supabase functions deploy for Edge Functions.
• Keep secrets out of Git (.env files, secret keys). Commit migrations and seed files.
• Small commits, one branch per feature, merge only when the feature's definition of done is met.
• Keep a changelog and screenshots in docs/ as you go; they become your paper's evidence.
10. Roadmap
Phase
Work
Result
0. Foundation
Supabase setup, 001 schema, Flutter scaffold, F1 Auth
Users can register and log in
1. Core loop
F2 consent and profile, F3 Map, F4 Visit and geofencing, F5 PSS-4, F6 Quiet Score
One full visit measured end to end
2. Engagement
F7 Activities, F8 Dashboard and PDF, F11 Weather, F12 Notifications
Users see progress and get nudges
3. Social and AI
F9 Community and MyDay, F10 AI coach, F13 Explore
Full feature set
4. Hardening
RLS audit, field tests, bug fixing, user evaluation, documentation
Release candidate APK
Spend extra time on Phase 1. If the core loop is solid, everything after it is lower risk. Freeze new features after Phase 3.
11. Testing plan
• Unit tests: age check, streak logic, polygon math, score interpretation.
• Database tests: constraint checks (invalid answers, duplicate ratings) and a two-account RLS test.
• Widget tests: form validation on login and register.
• Integration test: register, start a visit, complete both assessments, see the result.
• Field tests: walk into and out of each real park with at least two phones. Record detection delay, false triggers and battery use.
• Usability evaluation: use the instrument your adviser requires (for example SUS or an ISO 25010 questionnaire) with real users from the target age range.
• Keep a test log in docs/ with dates, devices and results.
12. Risks and mitigations
Risk
Mitigation
Background geofencing unreliable on some phones
OS circle geofences, foreground service, manual Start visit fallback
Poor GPS accuracy under tree cover
Dwell time, accuracy threshold, slightly generous polygons
Google Maps billing or quota
Stay within free usage, use url_launcher for directions
Supabase free-tier limits or project pausing
Keep migrations in Git, keep the project active, upgrade only if needed
Scope creep
Core loop first, freeze features after Phase 3
Privacy or legal concerns
Consent screen, data minimization, delete-account, disclaimers
AI gives harmful or off-topic advice
Strict system prompt, crisis detection, rate limits, clear disclaimer
13. Next steps
1. Confirm 001_foundation.sql ran and the Step 2 auth screens work (register, log in, see your name on Home).
2. Collect green space data: list the parks and nature spots you will support, draw each boundary on geojson.io, and record name, category, description and a photo. These become seed/green_spaces.sql.
3. Create a Google Maps API key for Android and restrict it to your app.
4. Decide how directions will work: open the Google Maps app (free) or use the Directions API (needs billing).
5. Start F3, the map and green spaces.