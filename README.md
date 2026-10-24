# ecowell

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Announcements and APK updates

- Run `supabase/announcements.sql` in the Supabase SQL Editor to create the
  read-only in-app announcements table. Publish announcements from the
  Supabase dashboard by adding a row with `published` enabled and a
  `published_at` date. The script also enables Supabase Realtime for this
  table so the bell updates while the app is open. Re-run the script if the
  table was created before Realtime was added.
- Publish APKs as assets on GitHub Releases for `Zeachy25/EcoWellV1`. Use a
  version tag such as `v1.0.1`, and attach the release APK. EcoWell checks for
  a newer release when Home opens and offers the APK download in the app.
- Announcement and release checks happen when the app is open. Existing
  arrival/exit local notifications remain separate; this does not configure
  remote push notifications.
