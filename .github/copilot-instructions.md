# GitHub Copilot Instructions — WildGuard

Read and obey **`/AGENTS.md`** in the repository root before suggesting or making any changes. It is the authoritative development contract for this project.

## Core rules (full detail in `/AGENTS.md`)

- **Project**: WildGuard — Smart Wildlife Conservation and Anti-Poaching Monitoring System (SE3070 Assignment 02). Not a social, ecommerce, adoption, or tourism app.
- **Exactly four graded parent use cases**: UC01 Manage Patrol Operations (Joel), UC02 Record & Review Wildlife Incidents (Thushalini), UC03 Coordinate Wildlife Conflict Response (Vaishnavi), UC04 Analyze Conservation Data & Generate Reports (Kanistan). Do not add a fifth parent use case.
- **Each member owns ONE use case.** Do not duplicate or modify another member's graded functionality from UI code — go through domain/repository interfaces.
- **Offline-first + stable IDs**: generate a stable client ID, save locally first, sync with idempotent upsert using the SAME ID, mark SYNCHRONIZED only after remote acknowledgement. Never create duplicate records on retry. Never fabricate GPS coordinates.
- **Reuse existing domain models, enums, and Firestore collection names.** Do not create parallel/duplicate models or collections. Do not rename persisted fields or enum values casually.
- **Auth is supporting infrastructure, NOT a graded use case.** Firebase Auth (email + password) for identity; Firestore `users/{firebaseAuthUid}` for profile/role. Never determine role from email naming. No public registration. Do NOT add Google/Facebook/Apple/OTP/biometric login unless explicitly requested.
- **Architecture**: UI → Riverpod controller/provider → repository interface → repository impl → Firestore/Drift/service. Do not bypass layers or put large workflows in widgets.
- **Frozen design is authoritative.** Do not change functionality just because a different design seems "better" — if implementation conflicts with the corrected design, STOP and explain.
- **Quality gate**: `flutter analyze` and `flutter test` must pass. Meaningful tests (positive/negative/edge/error). Do not delete or weaken working tests.
- **Never**: hardcode credentials/current-user IDs in production flow, weaken Firestore/Storage security (`allow read, write: if true;`), add unrelated packages, or push/commit/merge without explicit instruction.

When a requested change conflicts with `/AGENTS.md`, STOP and explain the conflict before writing code.
