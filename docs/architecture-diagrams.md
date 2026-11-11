# EcoWell ERD and DFD

These diagrams describe the current Flutter app and the Supabase objects it
uses. They were prepared from the Dart source, the six checked-in SQL scripts,
the project documentation, and the Android app configuration. Build output and
dependency caches are not part of the diagrams.

## Reading the diagrams

- **Defined in checked-in SQL** means a table's DDL is present in `supabase/`.
- **App-referenced** means Dart code reads or writes the object, but its table
  definition is not present in the checked-in SQL.
- **Plan-only** means the object is described in `PLAN.md` but is not defined by
  the checked-in SQL. Confirm these objects against the live Supabase project
  before using the diagrams as a database migration specification.
- For app-referenced entities, columns reflect fields used by Dart or an RPC
  contract. Primary-key markers on entities without checked-in DDL are logical
  identifiers and must be verified against the live schema.
- Relationship lines show logical ID links used by the app. Where the source
  schema is absent, they do not assert that a database foreign-key constraint
  exists.

The current app directly calls Open-Meteo, BigDataCloud, OpenRouteService, and
GitHub Releases. The AI coach, server-side weather suggestions, and remote
push-notification services described in the development plan are not shown as
implemented flows.

## ERD: identity and wellness

`RUNS` is defined in `supabase/runs.sql`. The shown profile columns include
fields used by the app and additions in `supabase/user_profile.sql`; the base
profile DDL is not checked in. `VISIT_SUMMARIES` and
`GREEN_SPACES_WITH_STATS` are views referenced by the app, not tables.

```mermaid
erDiagram
    AUTH_USERS {
        uuid id PK
    }

    PROFILES {
        uuid id PK
        text full_name
        date birthdate
        text avatar_url
        text cover_url
        text bio
        timestamptz consented_at
        text consent_version
        integer streak_count
    }

    GREEN_SPACES {
        uuid id PK
        text name
        text description
        text category
        text address
        text photo_url
        geography center
        geography boundary
    }

    VISITS {
        uuid id PK
        uuid user_id
        uuid place_id
        text status
        timestamptz entry_time
        timestamptz exit_time
    }

    ASSESSMENTS {
        uuid id PK
        uuid visit_id
        uuid user_id
        text type
        integer q1
        integer q2
        integer q3
        integer q4
    }

    QUIET_RATINGS {
        uuid visit_id PK
        integer rating
    }

    ACTIVITIES {
        uuid id PK
        text type
        integer duration_sec
        jsonb steps
    }

    ACTIVITY_LOGS {
        uuid id PK
        uuid user_id
        uuid activity_id
        uuid visit_id
    }

    RUNS {
        uuid id PK
        uuid user_id
        text activity_type
        timestamptz started_at
        timestamptz ended_at
        double distance_m
        integer duration_s
        integer avg_pace_s_per_km
        jsonb path
        timestamptz created_at
    }

    AUTH_USERS ||--o| PROFILES : "has profile"
    AUTH_USERS ||--o{ VISITS : "owns"
    AUTH_USERS ||--o{ ASSESSMENTS : "submits"
    AUTH_USERS ||--o{ ACTIVITY_LOGS : "completes"
    AUTH_USERS ||--o{ RUNS : "records"
    GREEN_SPACES ||--o{ VISITS : "hosts"
    VISITS ||--o{ ASSESSMENTS : "has pre and post"
    VISITS ||--o| QUIET_RATINGS : "receives"
    ACTIVITIES ||--o{ ACTIVITY_LOGS : "is completed in"
    VISITS o|--o{ ACTIVITY_LOGS : "may include"
```

### Views and RPC-derived data

- `VISIT_SUMMARIES` combines visit and assessment results for visit history
  and community post composition.
- `GREEN_SPACES_WITH_STATS` supplies the average Quiet Score and rating count
  returned with green-space data.
- `get_dashboard` returns aggregate visit, streak, activity, and reduction
  metrics. Its backing schema/function definition is not checked in.
- `finish_visit` accepts the post-assessment answers and Quiet rating and
  returns the visit result. Its SQL definition is not checked in.
- `QUIET_RATINGS` is documented in `PLAN.md`; the current app submits its value
  through `finish_visit`. The exact live table columns and constraints need
  verification.

## ERD: community and announcements

`PLACE_LIKES`, `PLACE_COMMENTS`, and `ANNOUNCEMENTS` are defined in checked-in
SQL. `PROFILES`, `GREEN_SPACES`, and `AUTH_USERS` are the same entities as in
the wellness diagram. Other community tables and their constraints are
app-referenced, but their DDL is not in this repository.

```mermaid
erDiagram
    AUTH_USERS {
        uuid id PK
    }

    PROFILES {
        uuid id PK
        text full_name
        text avatar_url
    }

    GREEN_SPACES {
        uuid id PK
        text name
    }

    VISITS {
        uuid id PK
    }

    POSTS {
        uuid id PK
        uuid user_id
        uuid place_id
        uuid visit_id
        text caption
        timestamptz created_at
        integer visit_minutes
        integer stress_reduction
    }

    POST_MEDIA {
        uuid id PK
        uuid post_id
        text storage_path
        integer sort_order
    }

    POST_LIKES {
        uuid post_id PK
        uuid user_id PK
        timestamptz created_at
    }

    POST_COMMENTS {
        uuid id PK
        uuid post_id
        uuid user_id
        text body
        timestamptz created_at
    }

    POST_REPORTS {
        uuid id PK
        uuid post_id
        uuid reporter_id
        text reason
    }

    FOLLOWS {
        uuid follower_id PK
        uuid following_id PK
    }

    MY_DAYS {
        uuid id PK
        uuid user_id
        uuid place_id
        text photo_path
        text caption
        text place_name
        timestamptz created_at
        timestamptz expires_at
        integer visit_minutes
        integer stress_reduction
    }

    MY_DAY_VIEWS {
        uuid my_day_id PK
        uuid viewer_id PK
    }

    PLACE_LIKES {
        uuid place_id PK
        uuid user_id PK
        timestamptz created_at
    }

    PLACE_COMMENTS {
        uuid id PK
        uuid place_id
        uuid user_id
        text body
        timestamptz created_at
    }

    ANNOUNCEMENTS {
        uuid id PK
        text title
        text message
        text link_url
        boolean published
        timestamptz published_at
        timestamptz created_at
    }

    AUTH_USERS ||--o| PROFILES : "has profile"
    PROFILES ||--o{ POSTS : "authors"
    GREEN_SPACES ||--o{ POSTS : "is post location"
    VISITS o|--o{ POSTS : "may be attached"
    POSTS ||--o{ POST_MEDIA : "has media paths"
    POSTS ||--o{ POST_LIKES : "receives"
    AUTH_USERS ||--o{ POST_LIKES : "likes"
    POSTS ||--o{ POST_COMMENTS : "has comments"
    AUTH_USERS ||--o{ POST_COMMENTS : "writes"
    POSTS ||--o{ POST_REPORTS : "may be reported"
    AUTH_USERS ||--o{ POST_REPORTS : "reports"
    PROFILES ||--o{ FOLLOWS : "follower or followed"
    PROFILES ||--o{ MY_DAYS : "shares"
    GREEN_SPACES o|--o{ MY_DAYS : "may be tagged"
    MY_DAYS ||--o{ MY_DAY_VIEWS : "has views"
    PROFILES ||--o{ MY_DAY_VIEWS : "views"
    GREEN_SPACES ||--o{ PLACE_LIKES : "receives"
    AUTH_USERS ||--o{ PLACE_LIKES : "likes"
    GREEN_SPACES ||--o{ PLACE_COMMENTS : "has comments"
    PROFILES ||--o{ PLACE_COMMENTS : "writes"
```

Posts and My Day photos are files in the Supabase Storage `post-media` bucket;
the relational rows store paths. Profile and cover images use the `avatars`
and `covers` buckets. `PUBLIC_PROFILES` is a restricted profile view referenced
by SQL functions, not a base table.

## ERD: on-device persistence

SQLite is a separate local store, not a replica with enforced foreign keys.
Offline visit/run rows are queued or retained for local history. `CACHE_ENTRIES`
stores JSON snapshots. SharedPreferences stores small device settings and
read/favorite state.

```mermaid
erDiagram
    CACHE_ENTRIES {
        text key PK
        text json
        integer updated_at
    }

    OFFLINE_VISITS {
        text id PK
        text user_id
        text place_id
        text place_name
        text server_visit_id
        integer entry_time
        text pre_answers
        text post_answers
        integer quiet_rating
        text status
        integer updated_at
    }

    OFFLINE_RUNS {
        text id PK
        text user_id
        text activity_type
        integer started_at
        integer ended_at
        real distance_m
        integer duration_s
        text path
        text status
        integer updated_at
    }
```

## DFD Level 0: system context

```mermaid
flowchart LR
    User[External entity: EcoWell user]
    Device[External entity: Android device services<br/>GPS, permissions, gallery, notifications, installer]
    Maps[External service: Google Maps SDK]
    ORS[External service: OpenRouteService]
    Weather[External service: Open-Meteo]
    Geo[External service: BigDataCloud reverse geocoder]
    GitHub[External service: GitHub Releases]
    Supabase[External system: Supabase<br/>Auth, Postgres, Storage, Realtime]

    App((0. EcoWell mobile app))

    User -->|account details, assessments, posts, interactions| App
    App -->|screens, wellness results, alerts, routes| User
    Device -->|location, selected media, permission state| App
    App -->|location requests, local alerts, APK install request| Device
    App -->|map camera, markers, place polygons| Maps
    App -->|walking route request: start/end coordinates| ORS
    ORS -->|route geometry and instructions| App
    App -->|coordinates and forecast query| Weather
    Weather -->|current and forecast data| App
    App -->|coordinates for place label| Geo
    Geo -->|city/region label| App
    App -->|latest-release metadata and APK download request| GitHub
    GitHub -->|release metadata and APK bytes| App
    App -->|JWT-authenticated queries, RPCs, writes, media, Realtime subscription| Supabase
    Supabase -->|auth state, rows, RPC results, media URLs, Realtime changes| App
```

## DFD Level 1: implemented app data flows

```mermaid
flowchart LR
    User[External entity: user]
    Android[External entity: Android OS<br/>GPS, gallery, local notifications]
    Maps[External service: Google Maps]
    ORS[External service: OpenRouteService]
    Weather[External service: Open-Meteo]
    Geo[External service: BigDataCloud]
    GitHub[External service: GitHub Releases]
    Supabase[(Supabase<br/>Auth, Postgres, Storage, Realtime)]
    SQLite[(D1: SQLite<br/>cache_entries, offline_visits, offline_runs)]
    Prefs[(D2: SharedPreferences<br/>favorites, onboarding, read/release state)]

    Auth((1.0 Authenticate and manage profile))
    Discover((2.0 Discover places and weather))
    Visit((3.0 Record visit and assessments))
    Activity((4.0 Complete activities and record runs))
    Social((5.0 Share and interact))
    Updates((6.0 Read announcements and check releases))
    Sync((7.0 Synchronize queued records))

    User -->|credentials, consent, profile edits| Auth
    Auth -->|session, account/profile screens| User
    Auth <-->|sign-in, signup, profile read/update| Supabase
    Auth <-->|profile snapshot| SQLite

    User -->|map/search, forecast request| Discover
    Discover -->|places, weather, location results| User
    Android -->|current location and permission state| Discover
    Discover -->|map markers/polygons| Maps
    Discover -->|route request| ORS
    ORS -->|walking directions| Discover
    Discover -->|forecast coordinates| Weather
    Weather -->|forecast values| Discover
    Discover -->|reverse-geocode coordinates| Geo
    Geo -->|place label| Discover
    Discover <-->|green spaces, Quiet Score aggregates, place social counts| Supabase
    Discover <-->|cached places and weather JSON| SQLite
    Discover <-->|favorite place IDs| Prefs

    User -->|start/end visit, PSS-4 answers, Quiet rating| Visit
    Android -->|location updates and geofence events| Visit
    Visit -->|arrival/exit alerts| Android
    Visit <-->|online visit and assessment operations, finish_visit result| Supabase
    Visit <-->|queued visit and cached result inputs| SQLite
    Visit -->|finish result and streak| User
    Visit -->|queued visit records| Sync

    User -->|activity selection and run controls| Activity
    Android -->|GPS samples| Activity
    Activity <-->|activity catalog and completion logs| Supabase
    Activity <-->|run checkpoints, pending uploads, local run history| SQLite
    Activity -->|completed activity/run summary| User
    Activity -->|pending run records| Sync

    User -->|posts, comments, likes, follows, My Day| Social
    Android -->|selected photos| Social
    Social -->|feed, profile and interaction results| User
    Social <-->|community rows, profile RPCs, place social actions| Supabase
    Social <-->|post, story, avatar and cover files| Supabase
    Social <-->|cached feed/profile snapshots| SQLite

    User -->|open announcement or release prompt| Updates
    Updates -->|announcement, update prompt, download/install handoff| User
    Updates <-->|published announcements and Realtime updates| Supabase
    Updates <-->|release metadata and APK download| GitHub
    Updates <-->|read IDs and prompted release tag| Prefs
    Updates -->|APK install intent| Android

    Android -->|network status changes| Sync
    Sync -->|visit queue uploads and finish_visit RPC| Supabase
    Sync -->|run inserts| Supabase
    Sync -->|remove synced visits; mark synced runs| SQLite
```

### Important implementation notes

- Visits are saved locally when offline and uploaded when connectivity returns.
  A finished visit is sent as a visit row, pre-assessment, then `finish_visit`.
- Runs are written to SQLite first, then inserted into `runs`; the same run ID
  is used for retries.
- Previously fetched green spaces, selected profile/feed/dashboard data, and
  weather can be read from SQLite while offline. Favorites and several UI
  flags are in SharedPreferences.
- Community actions such as likes/comments require a server connection; their
  returned data is not modeled as an offline write queue.
- Location samples are used on-device for visits and run recording. Run paths
  are uploaded as `runs.path`.
- The Android app uses local notifications for arrival/exit alerts. The
  checked-in implementation does not show a remote push-notification flow.
