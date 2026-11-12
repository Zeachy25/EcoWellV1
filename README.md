# EcoWell

EcoWell is a Flutter wellness app that encourages people to spend restorative
time in local green spaces. Users can discover locations, check in when they
arrive, reflect on how they feel, and share experiences with the community.

## What the app does

- **Discover green spaces:** Browse locations on a map or from the Home screen.
  Location details include the address, category, description, Quiet Score,
  likes, and community comments.
- **Check in and reflect:** EcoWell checks your location before starting an
  assessment. If you are not at the selected space, it can show walking
  directions and let you start check-in after arrival.
- **Track wellness:** Complete before-and-after PSS-4 assessments, rate a
  location's quietness, and view your visit history and streak.
- **Connect with the community:** Share posts, comment, follow users, and
  browse community content. Create 24-hour photo stories for followers and
  view stories in Explore.
- **Talk to an AI wellness coach:** Open the floating AI bubble on any main
  tab for supportive guidance on stress, sleep, motivation, and nearby green
  spaces. Replies are brief by default, and suggested breathing or grounding
  exercises open EcoWell's existing animated activity runner. The coach falls
  back to local suggestions when offline and shows crisis hotline information
  when needed.
- **Stay informed:** See current weather and a seven-day forecast, plus
  in-app announcements and release updates.
- **Use saved data offline:** Previously loaded places and selected app data
  remain available offline. New likes, comments, and other server updates
  require a connection; visits and runs support offline recording and later
  synchronization.

## Tech stack

- Flutter and Dart
- Supabase for authentication, app data, and Edge Functions
- Google Gemini for the AI wellness coach
- Riverpod for state management
- Google Maps and Geolocator for maps and location
- OpenRouteService for walking directions
- Open-Meteo for weather forecasts
- SQLite for local caching and offline records

## Requirements

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- Android Studio or another Flutter-supported IDE/toolchain
- An Android emulator or physical Android device for the complete location and
  background-geofence experience
- Supabase project, Google Maps API key, and OpenRouteService API key for
  backend, map, and routing functionality
- A Gemini API key for the AI wellness coach

## Configure services

Before running against your own backend:

1. Configure the Supabase project URL and **publishable** key in
   `lib/core/config.dart`. Never put a Supabase `service_role` or other secret
   key in the client app.
2. Add your Google Maps API key to the Android Maps API-key entry in
   `android/app/src/main/AndroidManifest.xml`. Restrict the key to the
   application and APIs it needs.
3. Add your OpenRouteService API key in `lib/core/ors_config.dart`.
4. Apply the SQL setup scripts in `supabase/` that match the features enabled
   in your Supabase project. These scripts create or update the functions,
   tables, and policies used by the app. In particular, green-space data,
   visits, user profiles, community features, place likes/comments, runs, and
   announcements each have related SQL files. Run `supabase/post_shares.sql` to
   enable post and place sharing with in-app feed reposts.
5. In Supabase Authentication settings, configure the sign-in providers and
   redirect URL used by the app. The Android Google sign-in callback scheme is
   `io.supabase.ecowell://login-callback`.
6. To enable the AI wellness coach, run `supabase/ai.sql`, set the
   `GEMINI_API_KEY` secret (optionally `GEMINI_MODEL` and `AI_DAILY_LIMIT`),
   then deploy the function with `supabase functions deploy ai`. Keep JWT
   verification enabled. See
   [docs/ai-assistant-changes.md](docs/ai-assistant-changes.md) for the full
   setup, safety, and architecture notes.

The app requests location, notification, and photo-library permissions when
needed. Photo access is used by the Android in-app My Day gallery; Android's
selected-photo access is supported where available. Location access is used
for maps, directions, check-ins, and geofence-based arrival detection.
Background location access is used for features that continue tracking when
the app is minimized.
When installing an APK update from GitHub, Android may ask the user to allow
EcoWell to install apps from this source before opening the system installer.

## Run locally

From the repository root:

```sh
flutter pub get
flutter devices
flutter run
```

Select a connected device or emulator if Flutter does not choose one
automatically. You can also provide a device ID:

```sh
flutter run -d <device-id>
```

## Run tests and analysis

```sh
flutter test
flutter analyze
```

## Build an Android APK

```sh
flutter build apk --release
```

The APK is generated under `build/app/outputs/flutter-apk/`.

## Announcements and release updates

- Run `supabase/announcements.sql` in the Supabase SQL Editor to set up the
  in-app announcements table and Realtime updates.
- Publish APKs as assets on GitHub Releases for `Zeachy25/EcoWellV1`, using a
  version tag such as `v1.0.1`. The app checks for a newer release while open
  and offers the APK download in the app.
- Announcement and release checks happen while the app is open. Arrival and
  exit alerts are local notifications; this setup does not configure remote
  push notifications.

## Project structure

Feature code lives under `lib/features/`, with shared configuration,
services, offline storage, routing, and theme code under `lib/core/`. Backend
SQL setup scripts are in `supabase/`, and Flutter tests are in `test/`.

The current data model and data flows are documented in
[docs/architecture-diagrams.md](docs/architecture-diagrams.md). Objects without
checked-in schema definitions are labeled there so the diagrams are not
mistaken for a complete database migration specification.
