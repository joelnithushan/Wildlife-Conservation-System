# Smart Wildlife Conservation and Anti-Poaching Monitoring System

**SE3070 – Assignment 02 | Group Project**

A Flutter application for park rangers and conservation managers to coordinate patrol operations, record wildlife incidents, respond to conflict alerts, and analyse conservation data — with full offline-first support.

---

## Group Members & Ownership

| Member | Use Case | Description |
|---|---|---|
| Joel | UC01 | Manage Patrol Operations |
| Thushalini | UC02 | Record and Review Wildlife Incidents |
| Vaishnavi | UC03 | Coordinate Wildlife Conflict Response |
| Kanistan | UC04 | Analyze Conservation Data and Generate Reports |

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter 3.x, Material 3 |
| Language | Dart 3.x (null-safe) |
| State management | Riverpod 2 + riverpod_generator |
| Routing | go_router |
| Offline DB | Drift (SQLite) |
| Backend | Firebase (Auth, Firestore, Storage) |
| Maps | google_maps_flutter |
| Charts | fl_chart |
| Export | pdf, csv |
| Testing | flutter_test, mocktail |

---

## Setup Instructions

### Prerequisites
- Flutter SDK ≥ 3.3.0
- Dart SDK ≥ 3.3.0
- Android Studio or Xcode (for device emulators)
- A Firebase project (see below)

### 1. Clone and install dependencies

```bash
git clone https://github.com/joelnithushan/Wildlife-Conservation-System-.git
cd Wildlife-Conservation-System-
flutter pub get
```

### 2. Run code generation (Drift + Riverpod)

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Firebase setup

1. Create a project at [Firebase Console](https://console.firebase.google.com)
2. Enable: Authentication, Cloud Firestore, Firebase Storage
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
4. Run: `flutterfire configure`
5. This generates `lib/firebase_options.dart` — **do not commit this file**

### 4. Run the app

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web (manager dashboard)
flutter run -d chrome
```

---

## Running Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Specific feature
flutter test test/patrol/
flutter test test/incidents/
flutter test test/conflict_response/
flutter test test/analytics/
```

---

## Code Generation

After modifying any Drift table or Riverpod `@riverpod` annotation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Folder Structure

```
lib/
  core/
    constants/        # App-wide constants
    theme/            # AppTheme, AppColors
    routing/          # GoRouter setup
    errors/           # Failure sealed classes
    utils/            # Extensions
    widgets/          # HomeShell navigation
    database/         # Drift AppDatabase + tables
    services/         # FirebaseService (abstract)
    sync/             # SyncService (abstract)

  features/
    patrol/           # UC01 – Joel
    incidents/        # UC02 – Thushalini
    conflict_response/ # UC03 – Vaishnavi
    analytics/        # UC04 – Kanistan

  shared/
    models/           # Shared enums
    widgets/          # Shared UI widgets
    services/         # LocationService

  app.dart
  main.dart

test/
  patrol/
  incidents/
  conflict_response/
  analytics/
  core/
```

---

## Branch Strategy

```
main                           ← integration / stable branch
feature/uc01-patrol            ← Joel
feature/uc02-incidents         ← Thushalini
feature/uc03-conflict-response ← Vaishnavi
feature/uc04-analytics         ← Kanistan
```

**Workflow:**
1. `main` is the integration/stable branch (holds this shared foundation).
2. Each member works on their feature branch.
3. Feature work is merged into `main` via pull requests — no direct commits to `main`.

---

## Architecture Notes

- **Clean Architecture** per feature: `data → domain → presentation`
- **Offline-first**: field writes go to Drift (SQLite) first; `SyncService` pushes pending records to Firestore when online
- **No hardcoded secrets**: Firebase config is generated locally and excluded from git
- **Independent modules**: each UC depends only on `core/` and `shared/` — no cross-feature imports

---

## Shared Application Foundation

The `feat: add shared application foundation` work provides the common layer all
four UCs build on. Feature UIs and repository implementations are added later on
each feature branch.

### Shared architecture
- `core/enums/app_enums.dart` — all status enums + safe serialization (`parseEnum`,
  `.wire`) and lifecycle rules (`PatrolStatus`/`AlertStatus` transitions). Raw
  status strings are never scattered through the code.
- `shared/models/` — framework-agnostic domain models with `toMap`/`fromMap`
  (`AppUser`, `Patrol`, `PatrolPosition`, `PatrolRoute`, `IncidentReport`,
  `RiskZone`, `TrackedAnimal`, `LocationReading`, `WildlifeRiskAlert`,
  `ResponseAssignment`, `CommunityReport`, `ReportCriteria`,
  `ConservationReport`, `Park`, `GeoCoordinate`).
- `shared/repositories/` — contracts only: `PatrolRepository`,
  `IncidentRepository`, `ConflictRepository`, `ReportRepository`,
  `ReportExportService`.
- `shared/session/current_user.dart` — `currentUserProvider` with demo role
  switching (Park Manager / Ranger / CLO / Researcher); Firebase-Auth compatible.
- `shared/providers/` — shared Riverpod providers (connectivity, online status).
- `shared/demo/demo_data.dart` — in-memory dev seed data (never writes to Firebase).
- `core/services/`, `core/sync/`, `core/errors/`, `core/utils/` — Firebase &
  connectivity abstractions, sync service, exceptions, validators, ID/date helpers.

### Firestore collections
Names are centralised in `core/constants/firestore_collections.dart` (never
hardcoded): `users`, `parks`, `patrol_routes`, `patrols`, `patrol_positions`,
`incident_reports`, `risk_zones`, `tracked_animals`, `location_readings`,
`wildlife_risk_alerts`, `response_assignments`, `community_reports`.
UC04 reads and aggregates from these records — there is no separate analytics DB.

### Offline data strategy
Drift/SQLite mirrors **only** the tables needed for field workflows without
coverage: `patrols`, `patrol_positions`, `incident_reports`. Each offline row
carries a stable client ID, a `syncState`, and `createdAt`/`updatedAt`.
Coordination data (alerts, assignments) is online-first and not mirrored locally.

### Sync lifecycle
`SyncState`: `pending → synchronized` on success, or `pending → failed` (retryable).
`SyncService` (`syncPendingPatrolData`, `syncPendingIncidentData`,
`syncAllPendingData`) reads pending rows and **upserts by the record's stable ID**,
so retrying a pending record never creates a duplicate remote document
(idempotent). Records are marked `synchronized` only after a successful write.

### Member feature ownership
| Member | Branch | Use case |
|---|---|---|
| Joel | `feature/uc01-patrol` | UC01 Manage Patrol Operations |
| Thushalini | `feature/uc02-incidents` | UC02 Record & Review Wildlife Incidents |
| Vaishnavi | `feature/uc03-conflict-response` | UC03 Coordinate Wildlife Conflict Response |
| Kanistan | `feature/uc04-analytics` | UC04 Analyze Conservation Data & Reports |

---

## Database & Firebase setup

One Firebase project backs the whole app: **Cloud Firestore** (sync target),
**Drift/SQLite** (offline), **Firebase Storage** (evidence photos, UC02+).

The app is **offline-first and runs without Firebase**: `bootstrapFirebase()` in
`main.dart` initializes Firebase safely (falls back to local Drift + an in-memory
sync writer if not configured). Once configured, `firebaseReadyProvider` flips to
`true` and sync/storage use the real Firestore/Storage implementations — no code
change needed.

**To make Firebase real (manual, one-time):**
```bash
# 1. Install CLIs
dart pub global activate flutterfire_cli
npm install -g firebase-tools          # or: curl -sL https://firebase.tools | bash

# 2. Log in and configure (generates lib/firebase_options.dart — git-ignored)
firebase login
flutterfire configure

# 3. In main.dart, pass the generated options:
#    await bootstrapFirebase(optionsOverride: DefaultFirebaseOptions.currentPlatform);

# 4. In the Firebase console: enable Firestore (choose region) and Storage.

# 5. Deploy rules + indexes (config files are in the repo root)
firebase deploy --only firestore:rules,firestore:indexes,storage
```

- **Collections** are centralised in `core/constants/firestore_collections.dart`.
- **Rules**: `firestore.rules` now ships **authenticated, role-aware** rules as
  the active block (signed-in required; reference data manager-only; per-user
  profile access) with a commented development/emulator block kept for local work.
  See "Shared Authentication & Role-Based Access" below.
- **Indexes**: `firestore.indexes.json` predefines likely composite indexes;
  Firestore also prints an index-creation link the first time a query needs one.
- **Seeding**: `FirestoreDemoSeeder.seedIfMissing()` (in `core/database/seed/`) is
  idempotent and **never auto-runs** — call it manually; it skips docs that exist.

---

## Shared Authentication & Role-Based Access

Shared foundation feature. Firebase **Email/Password** authentication identifies
the user; the **Cloud Firestore** `users/{uid}` document supplies the WildGuard
profile and role. There is **no public sign-up** — accounts are provisioned by
administrators.

### How it works

```
Splash / session restore
  → check Firebase auth state
    → not signed in ............ Login (email + password)
    → signed in + valid profile  role dashboard (via AccessPolicy)
    → signed in + bad profile .. Account Issue (retry / sign out)
```

- **Identity vs profile** are separated: `AuthService` (`features/auth/data/`)
  wraps `firebase_auth`; `UserRepository` loads/validates `users/{uid}` from
  Firestore. Neither leaks Firebase types to the UI.
- **State** lives in `AuthController` (`features/auth/application/`), a Riverpod
  `Notifier<AuthSession>` exposing `AuthInitial / AuthUnauthenticated /
  AuthLoadingProfile / Authenticated / AuthProfileError`. Firebase error codes
  are mapped to friendly messages (`AuthFailure`) — raw exceptions are never shown.
- **Routing** is centralised: `go_router`'s `redirect` guard reads the session +
  `AccessPolicy` (`features/auth/domain/access_policy.dart`) — the single,
  testable source of role → dashboard and role → allowed-route rules. Role checks
  are never scattered through widgets.
- **Offline/demo mode**: when Firebase is not configured, the app runs with the
  existing demo session (so UC01 and the test suite work without a live backend).

### Supported roles

| Role (`users.role`)        | Display label               | Lands on            |
|----------------------------|-----------------------------|---------------------|
| `parkManager`              | Park Manager                | `/manager`          |
| `ranger`                   | Ranger                      | `/ranger`           |
| `communityLiaisonOfficer`  | Community Liaison Officer    | `/clo`              |
| `conservationResearcher`   | Conservation Researcher     | `/researcher`       |

Access matrix (enforced by `AccessPolicy` + the router guard):

| Route / module        | Manager | Ranger | CLO | Researcher |
|-----------------------|:-------:|:------:|:---:|:----------:|
| Assign Patrol (UC01)  | ✅ | ❌ | ❌ | ❌ |
| My Patrols (UC01)     | ✅ | ✅ | ❌ | ❌ |
| Incident Review (UC02)| ✅ | ✅ | ❌ | ❌ |
| Conflict Response (UC03)| ✅ | ✅ | ✅ | ❌ |
| Reports (UC04)        | ✅ | ❌ | ❌ | ✅ |

### Firestore user document

`users/{firebaseUid}` — the document **id must equal the Firebase Auth UID**
(never the email):

```json
{
  "id": "<firebase-auth-uid>",
  "name": "K. Perera",
  "email": "ranger1@wildguard.lk",
  "role": "ranger",
  "parkId": "minneriya",
  "isAvailable": true,
  "isActive": true
}
```

`isActive: false`, an unsupported `role`, a missing document, or missing
`name`/`parkId` all route the user to the **Account Issue** screen instead of a
dashboard.

### Demo accounts (create manually)

| Email                    | Role                      |
|--------------------------|---------------------------|
| manager@wildguard.lk     | parkManager               |
| ranger1@wildguard.lk     | ranger                    |
| ranger2@wildguard.lk     | ranger                    |
| clo@wildguard.lk         | communityLiaisonOfficer   |
| researcher@wildguard.lk  | conservationResearcher    |

Passwords are **not** stored in source and users are **not** created from the app.

### Firebase Console steps (manual)

1. **Authentication → Sign-in method → Email/Password → Enable.**
2. Create each demo user (Authentication → Users → Add user) and copy its **UID**.
3. For each, create `users/{uid}` with the fields above (id = that UID).
4. If `lib/firebase_options.dart` is missing, run `flutterfire configure` and pass
   the options in `main.dart` (`bootstrapFirebase(optionsOverride: …)`) — required
   for **web**. Native Android/iOS use `google-services.json` /
   `GoogleService-Info.plist`.
5. Deploy rules: `firebase deploy --only firestore:rules`.

### Tests

- `test/auth/access_policy_test.dart` — role → dashboard + access-matrix guards.
- `test/auth/auth_controller_test.dart` — login, invalid/network/disabled/missing
  profile/unsupported role, logout, password reset, auth-state changes, profile
  validation, error mapping (fakes; no live Firebase).
- `test/auth/auth_widgets_test.dart` — splash, login form + validation + password
  toggle + loading + error, forgot-password, access-denied, profile, logout dialog.

---

## UC01 – Manage Patrol Operations

Implemented on `feature/uc01-patrol`. Two scenarios under one use case:

- **UC01-S01 Assign Patrol Route** (Park Manager): pick a route + available ranger
  + schedule → creates one `Patrol` (status `assigned`, stable ID, `pending` sync).
- **UC01-S02 Conduct Assigned Patrol** (Ranger): view *My Patrols* → open details →
  start → GPS tracking → manual waypoint → offline capture → sync → finish →
  coverage summary.

**Flow / screens:** My Patrols → Patrol Details → Patrol In Progress → Manual
Waypoint → Completion Summary. A demo role switcher (app bar) toggles between
Ranger and Park Manager on one device.

**Location / GPS:** the app requests location permission at patrol start. GPS and
manual waypoints produce the *same* `PatrolPosition` model (only `captureMode`
differs). A GPS fix is never fabricated — if location is unavailable the UI shows
a message and manual waypoint stays available. Maps are shown as a lightweight
`RoutePreview` (CustomPaint) so the app runs without a Google Maps API key.

**Offline behaviour:** every position/patrol change is written to Drift first with
`syncState = pending`; field work continues fully offline (an amber banner shows
"Offline – positions saved on this device" with the pending count).

**Synchronization:** when back online, `SyncService.syncAllPendingData()` upserts
pending records to Firestore **keyed by their stable client ID** — retry-safe and
idempotent, so retries never create duplicate patrols/positions. Records flip to
`synchronized` only after a successful write; failures stay `failed` and retry.
Without Firebase configured, an in-memory writer backs sync for demo (swap in
`FirestoreRemoteWriter` via `remoteWriterProvider` once Firebase is set up).

**Coverage:** `CalculateCoverage` (in `features/patrol/domain/usecases`) returns
0–100% = fraction of planned-route waypoints visited within a 150 m tolerance.
Deterministic and unit-tested.

**Status lifecycle** (enforced in the repository, not just the UI):
`assigned → inProgress → completed`. Duplicate start, starting a completed patrol,
and completing a non-in-progress patrol are all rejected.

**Run UC01 tests:**
```bash
flutter test test/patrol      # UC01 unit + widget tests
flutter test                  # whole suite
```

## UC04 – Analyze Conservation Data and Generate Reports

Implemented on `feature/uc04-analytics` (UC04-S01, Park Manager and Conservation Researcher).

**Filters.** Open Conservation Reports, choose a permitted park, a start and end date, and one or more incident categories, then Generate Report. Invalid filters show an inline error and do not query data. Categories are the shared UC02 values: Poaching, Animal injury, Human-wildlife conflict, Illegal logging, and Other.

**Synchronized-data rule.** One `generateReport` read builds one snapshot. Only `syncState = synchronized` incidents and completed patrols are aggregated. Pending and failed field records that match the filters are excluded from totals and reported as "N pending field records excluded".

**Aggregation.** Incident totals are counts by the selected categories. Patrol coverage is the average of `coveragePercent` on completed, synchronized patrols in the park and period (incomplete patrols are omitted; if none qualify the report shows N/A). Conflict alerts from UC03 are counted open vs resolved and bucketed weekly (period of 92 days or less) or monthly. No separate analytics collection is written, and source records are not modified.

**Empty results and outages.** Valid filters with no matching synchronized records produce an empty report (zeros, N/A coverage) and "No records for these filters." If the read fails, the app shows "The data service is unavailable – no new report was created.", keeps the filters, and does not present an older report as new.

**Export.** Optional, and only after a report is on screen. PDF and CSV are rendered from that same `ConservationReport` (same snapshot, filters, and cutoff) with no new query. A failed export leaves the report unchanged.

**Run UC04 tests:**
```bash
flutter test test/analytics
```

### Running on Web
The Drift connection is platform-conditional (native SQLite on mobile, SQLite
WASM on web), so the app compiles for web (`flutter build web`). To actually run
the DB on web, serve `sqlite3.wasm` and `drift_worker.js` from `web/` (see the
[drift web docs](https://drift.simonbinder.eu/web/)).
