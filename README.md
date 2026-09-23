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
