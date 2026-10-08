# WildGuard — Repository Rules and Development Contract

> This file is the authoritative development contract for the WildGuard project.
>
> ALL human developers and AI coding agents MUST read this file before modifying the repository.
>
> Do not ignore, weaken, reinterpret, or bypass these rules.
>
> If a requested change conflicts with this file, STOP and explain the conflict before modifying code.

---

# 1. PROJECT IDENTITY

## App Name

WildGuard

UI wordmark may be displayed as:

WILDGUARD

## Tagline

Conserve • Track • Protect

## Full Academic Project Title

Smart Wildlife Conservation and Anti-Poaching Monitoring System

## Module

SE3070 – Case Studies in Software Engineering

## Assignment

Assignment 02 – Implementation of a software solution based on a case study design

## Purpose

WildGuard is a wildlife conservation operations system designed to support:

- wildlife ranger patrol management
- offline patrol tracking
- wildlife/poaching incident reporting
- wildlife conflict-risk alerts
- responder coordination
- conservation analytics and reports

The system consists primarily of:

1. mobile workflows for Rangers and responders
2. management/dashboard workflows for Park Managers
3. reporting access for Conservation Researchers

WildGuard is NOT a generic wildlife social app.

WildGuard is NOT an ecommerce app.

WildGuard is NOT an animal-adoption app.

WildGuard is NOT a public tourism app.

---

# 2. AUTHORITATIVE BUSINESS USE CASES

There are exactly FOUR graded parent business use cases.

Do not introduce another parent use case without explicit team approval.

## UC01 — Manage Patrol Operations

Owner:

Joel

Feature branch:

feature/uc01-patrol

Primary actors:

- Park Manager
- Ranger

Scope:

Park Manager assigns a patrol.

Ranger conducts the patrol.

End-to-end flow:

Park Manager
→ Select Patrol Route
→ Select Ranger
→ Select Date / Schedule
→ Assign Patrol

Ranger
→ My Patrols
→ Patrol Details
→ Start Patrol
→ Record GPS Positions
→ Optionally Mark Manual Waypoint
→ Continue Offline if required
→ Synchronize pending records
→ Finish Patrol
→ View Coverage Summary

Required lifecycle:

ASSIGNED
→ IN_PROGRESS
→ COMPLETED

Never introduce alternative patrol statuses without justification and team approval.

---

# 3. UC01 NON-NEGOTIABLE RULES

Every Patrol must have a stable ID.

Every PatrolPosition must have a stable ID.

GPS points and manual waypoints MUST use the SAME PatrolPosition model.

Do NOT create:

ManualWaypointModel
ManualWaypointTable
GpsWaypointModel

Use:

PatrolPosition.captureMode

with:

gps
manual

No GPS fix:

- do not invent coordinates
- display an understandable error
- allow manual waypoint

Offline:

- patrol operations must continue
- save locally first
- records become PENDING

Reconnect:

- synchronize using the SAME stable IDs
- use idempotent/upsert behaviour
- do not create duplicate Firestore records

Only mark a record SYNCHRONIZED after successful acknowledgement.

Coverage must be calculated when the patrol is completed.

Coverage must remain between 0 and 100.

Do not implement complex GIS unless specifically required.

---

# 4. UC02 — RECORD AND REVIEW WILDLIFE INCIDENTS

Owner:

Thushalini

Feature branch:

feature/uc02-incidents

Primary actors:

- Ranger
- Park Manager / Authorized Reviewer

End-to-end Ranger flow:

New Incident
→ Select Category
→ Add Photo OR Evidence Omission Reason
→ GPS Location OR Manual Location
→ Description
→ Review
→ Submit
→ Offline Save if required
→ Synchronize

Manager flow:

Incident Review Queue
→ Open Report
→ Review Evidence
→ Review Location
→ Change Review Status
→ Add Optional Review Note
→ Save Reviewer + Timestamp

---

# 5. UC02 NON-NEGOTIABLE RULES

Supported incident categories include:

- snare
- carcass
- illegal campsite
- suspicious footprints
- other

Evidence rule:

A submitted incident must contain:

PHOTO

OR

EVIDENCE OMISSION REASON

It must NOT require both.

If no photo exists:

evidenceOmissionReason must be supplied.

Location source:

gps
or
manual

Never fabricate GPS coordinates.

The incident must support offline creation.

Local save happens before synchronization.

A central Park Manager review queue must show only synchronized reports.

Required submission/review statuses:

SubmissionStatus:

draft
submitted

ReviewStatus:

pendingReview
underReview
verified
rejected

Review changes must record:

- reviewerId
- reviewedAt
- resulting status
- optional review note

Community conflict reports DO NOT belong to UC02.

Community conflict reports belong to UC03.

---

# 6. UC03 — COORDINATE WILDLIFE CONFLICT RESPONSE

Owner:

Vaishnavi

Feature branch:

feature/uc03-conflict-response

Primary actor:

Park Manager

Secondary actors:

- Ranger
- Community Liaison Officer
- GPS Collar / Sensor System
- Community Member

Valid triggers:

A. GPS collar / sensor reading

OR

B. credible community conflict report

These are ALTERNATIVE triggers.

Never require both.

End-to-end flow:

Risk Information
→ Validate
→ Evaluate Risk Zone
→ Create or Update Wildlife Risk Alert
→ Manager Reviews Alert
→ View Available Responders
→ Assign Ranger or CLO
→ Notify Responder
→ Record Delivery
→ Monitor Acknowledgement
→ Responder Acknowledges
→ Start Response
→ Response In Progress
→ Record Action / Outcome
→ Manager Resolves Alert

Timeout flow:

No acknowledgement
→ Escalation
→ Reassignment

---

# 7. UC03 NON-NEGOTIABLE RULES

Required alert lifecycle:

NEW
→ ASSIGNED
→ ACKNOWLEDGED
→ RESPONSE_IN_PROGRESS
→ RESOLVED

Do not allow invalid transitions such as:

RESOLVED → ASSIGNED

or:

NEW → RESOLVED

Notification delivery and responder acknowledgement are DIFFERENT concepts.

DeliveryState:

pending
delivered
failed

Delivery does NOT mean acknowledgement.

At most one OPEN alert should exist for:

same animal
+
same risk zone

When another valid reading arrives:

update the existing open alert where appropriate.

Do not create duplicate open alerts.

Reassignment:

- uses the SAME WildlifeRiskAlert
- may create a NEW ResponseAssignment
- preserves assignment history

Only Park Manager resolves the final alert.

Responder recording an outcome does NOT automatically resolve the alert.

Real physical GPS collar hardware is NOT required.

Collar input may be simulated.

Simulated collar readings must still pass through the same domain/repository logic.

Simulated notification delivery is acceptable unless the team explicitly decides to implement FCM.

Do not unnecessarily build FCM just for complexity.

---

# 8. UC04 — ANALYZE CONSERVATION DATA AND GENERATE REPORTS

Owner:

Kanistan

Feature branch:

feature/uc04-analytics

Primary actors:

- Park Manager
- Conservation Researcher

Flow:

Open Reports
→ Select Park
→ Select Date Range
→ Select Categories
→ Validate Filters
→ Create Consistent Snapshot
→ Calculate Incident Statistics
→ Calculate Patrol Coverage
→ Calculate Conflict Trends
→ View Report

Optional:

View Report
→ Export
→ PDF or CSV

Export is OPTIONAL.

It is not mandatory for report generation.

---

# 9. UC04 NON-NEGOTIABLE RULES

UC04 is READ ONLY with respect to UC01–UC03 source records.

UC04 MUST NOT:

- create Patrol records
- modify Patrol records
- create IncidentReport records
- review incidents
- create WildlifeRiskAlerts
- assign responders
- resolve alerts

UC04 reads source data from UC01–UC03.

Reporting must use synchronized data.

Pending field records must not silently appear in totals.

Where supported, display:

pending/excluded record count

A generated report uses ONE consistent snapshot.

The snapshot must preserve:

- selected filters
- data cutoff
- generation time
- calculated values

If filters change:

generate a new snapshot.

Do NOT mutate an existing generated report.

Export must use the SAME generated report/snapshot.

Do NOT re-query Firestore during PDF/CSV export.

Report data includes:

- incident totals
- category counts
- patrol coverage
- conflict trends
- data cutoff
- pending/excluded count

PDF and CSV export must reflect the report currently displayed.

---

# 10. LOGIN / AUTHENTICATION ROLES

Only internal authorized personnel have WildGuard staff logins.

Supported authenticated roles:

1. Park Manager
2. Ranger
3. Community Liaison Officer
4. Conservation Researcher
5. System Admin (SUPPORTING role — see below)

Use enum:

UserRole.parkManager
UserRole.ranger
UserRole.communityLiaisonOfficer
UserRole.conservationResearcher
UserRole.admin

Do not create new staff roles casually.

### System Admin (supporting role)

`UserRole.admin` is a SUPPORTING role for account management, NOT one of the four
graded business use cases (see §35). The admin:

- is seeded as a permanent default account (admin@gmail.com) at startup
- creates / edits / deletes the operational staff accounts (ranger, manager,
  CLO, researcher) with all required personal details + profile picture
- is the ONLY actor who may edit a staff member's profile — staff cannot edit
  their own details

Operational staff can sign in with EITHER their email OR their generated
username (see §16a). The admin signs in by email only. Do not expand the admin
beyond account management, and do not treat it as a fifth business use case.

---

# 11. ACTORS WHO DO NOT HAVE NORMAL STAFF LOGINS

Community Member:

No normal WildGuard staff login is required.

Community Member represents an external conflict-reporting actor.

GPS Collar / Sensor System:

No human login.

It represents an external/system input.

Field Officer:

Conceptual/generalized UML actor.

Do not create a separate Field Officer login role unless explicitly required.

---

# 12. AUTHENTICATION ARCHITECTURE

Use:

Firebase Authentication

with:

Email + Password

User business/profile data comes from:

Firestore

Path:

users/{firebaseAuthUid}

The Firestore document ID must correspond to Firebase Auth UID.

Authentication determines identity.

Firestore profile determines:

- name
- email
- role
- parkId
- isAvailable
- isActive

Never determine role from email naming.

Never write logic such as:

if email.contains("manager")

Never hardcode current-user IDs in production flows.

Use current authenticated session/profile.

---

# 13. NO PUBLIC REGISTRATION

WildGuard is an authorized personnel system.

Do NOT add public Sign Up unless specifically approved.

Required auth features:

- splash/session restore
- email/password login
- forgot password
- logout
- profile
- role-based routing
- access denied
- invalid/disabled account handling

Do NOT add unless explicitly requested:

- Google login
- Facebook login
- Apple login
- OTP
- social authentication
- public registration
- biometric authentication

Login/logout are support functionality.

They are NOT one of the four graded business use cases.

Do not spend major project scope on authentication features.

---

# 14. ROLE ACCESS MATRIX

## Park Manager

Allowed:

- Manager Dashboard
- Assign Patrol Route
- Incident Review Queue
- Review Incident
- Risk Alerts
- Assign Responder
- Monitor Response
- Resolve Alert
- Conservation Reports
- Profile

Not a primary Ranger field workflow user.

---

## Ranger

Allowed:

- Ranger Dashboard
- My Patrols
- Patrol Details
- Start/Complete Patrol
- GPS Tracking
- Manual Waypoints
- Report Wildlife Incident
- View own assigned conflict responses
- Acknowledge assigned response
- Start response
- Record response progress/outcome
- Profile

Not allowed:

- assign patrols
- review incidents as Park Manager
- manage all alerts
- access management reports unless requirements explicitly change

---

## Community Liaison Officer

Allowed:

- CLO Dashboard
- own conflict-response assignments
- acknowledge assignment
- start response
- record response progress
- record outcome
- profile

Not allowed:

- assign patrols
- incident review
- Park Manager alert management
- report analytics unless requirements change

---

## Conservation Researcher

Allowed:

- Researcher Dashboard
- Conservation Reports
- report generation
- optional export
- profile

Not allowed:

- assign patrols
- modify incidents
- manage conflict responses
- modify operational records

---

# 15. ROUTE SECURITY

Role access must be centralized.

Do not scatter arbitrary role checks across random widgets.

Use existing:

AccessPolicy
route guard
current session/profile providers

Unauthenticated user:

→ Login

Unauthorized authenticated user:

→ Access Denied / appropriate dashboard

Logging out must prevent back navigation into protected routes.

---

# 16. DEMO ACCOUNTS

Suggested demo identities:

manager@wildguard.lk
→ Park Manager

ranger1@wildguard.lk
→ Ranger / K. Perera

ranger2@wildguard.lk
→ Ranger / R. Silva

clo@wildguard.lk
→ Community Liaison Officer / S. Nimal

researcher@wildguard.lk
→ Conservation Researcher

NEVER commit plaintext passwords.

Passwords belong only in:

Firebase Authentication / secure demo notes outside source control.

### Default admin account

A permanent default system admin is seeded on first launch (idempotent):

- email: admin@gmail.com
- password: password123   (DEMO credential for the academic project only —
  change it for any real deployment; never make the repo public with it)

The admin creates all other staff accounts in-app.

---

# 16a. USERNAME FORMAT (LOGIN HANDLE)

Operational staff get a generated login username in the format:

  {roleCode}_{firstName}_{seq}      e.g. ranger_kumar_001

- roleCode: ranger | manager | clo | researcher (admin -> admin)
- firstName: first word of the full name, lowercased, a–z0–9 only
- seq: zero-padded 3-digit sequence, unique within the same role + first name

The username is the general identifier used across the app (assignment, lists,
etc.). The FULL NAME (e.g. "Kumar Ravi") is shown only in the profile section,
to the admin, and in ranger/manager detail views. Usernames must be unique and
are generated by `UsernameGenerator` — do not hand-mint conflicting formats.

---

# 17. DOMAIN MODELS

Reuse existing domain models.

Do NOT create duplicates.

Core models:

User
Park
PatrolRoute
Patrol
PatrolPosition
IncidentReport
RiskZone
TrackedAnimal
LocationReading
WildlifeRiskAlert
ResponseAssignment
CommunityReport
ReportCriteria
ConservationReport
GeoCoordinate

If a required model already exists:

extend/reuse it.

Do NOT create parallel models such as:

PatrolData
PatrolInfo
PatrolEntity2
NewIncidentModel
WildlifeAlertData

without a clear architectural reason.

---

# 18. ENUM CONTRACT

Existing enum names and values are part of the data contract.

Do not rename them casually.

## PatrolStatus

assigned
inProgress
completed

## SyncState

pending
synchronized
failed

## CaptureMode

gps
manual

## SubmissionStatus

draft
submitted

## ReviewStatus

pendingReview
underReview
verified
rejected

## AlertStatus

newAlert
assigned
acknowledged
responseInProgress
resolved

## DeliveryState

pending
delivered
failed

## UserRole

ranger
parkManager
communityLiaisonOfficer
conservationResearcher
admin

## Gender

male
female
other

## ResponderRole

ranger
communityLiaisonOfficer

## AlertSource

collar
communityReport

Do not introduce random string statuses.

Use enum serialization consistently.

---

# 19. FIRESTORE COLLECTION CONTRACT

Use these collection names consistently:

users
parks
patrol_routes
patrols
patrol_positions
incident_reports
risk_zones
tracked_animals
location_readings
wildlife_risk_alerts
response_assignments
community_reports

Do not create:

patrolData
patrolRecords
incidentData
alerts2
responses_new

or other duplicate collections.

Use centralized Firestore collection constants.

---

# 20. LOCAL DATABASE CONTRACT

Drift / SQLite is the primary offline store for field workflows.

Offline-focused local tables:

Patrols
PatrolPositions
IncidentReports

Do not mirror every Firestore collection into Drift without a real requirement.

Core reasons for Drift:

- Ranger may have no network
- patrol tracking must continue
- incident reporting must continue
- unsynchronized data must survive

---

# 21. OFFLINE-FIRST RULE

Field operations must be local-first.

For offline-capable records:

1. Generate stable client ID.
2. Save locally.
3. Set sync state.
4. Attempt remote sync when possible.
5. Keep data locally if remote sync fails.
6. Retry later using SAME ID.
7. Mark SYNCHRONIZED only after acknowledgement.

Never display:

"Saved"

unless local persistence actually succeeded.

Never display:

"Synced"

until remote acknowledgement succeeds.

Never throw away unsynchronized field data.

---

# 22. DUPLICATE-PREVENTION RULE

Retries must be idempotent.

Never use a synchronization strategy that creates a new Firestore record every retry.

Prefer stable document ID + set/upsert.

The same domain record ID must remain the same across retries.

Examples:

Patrol ID stays identical.

PatrolPosition ID stays identical.

IncidentReport ID stays identical.

LocationReading ID stays identical.

ResponseAssignment ID stays identical.

---

# 23. CURRENT FIREBASE RESPONSIBILITIES

Firebase Authentication:

identity/session

Firestore:

shared/cloud persistence

Firebase Storage:

incident evidence files

Drift:

offline/local field records

Do not mix responsibilities unnecessarily.

---

# 24. FIREBASE STORAGE

Incident evidence path should remain deterministic/stable.

Do not upload arbitrary file types.

Evidence should normally be image content.

Do not store Firebase secrets in Dart source.

Do not make Storage permanently public.

---

# 25. MAP / LOCATION RULES

Geolocation must use the existing location abstraction.

UI must not directly own all geolocator business logic.

Handle:

- permission granted
- permission denied
- permanently denied
- location services disabled
- no GPS fix

Never invent GPS coordinates.

Manual location should remain available where the scenario permits it.

Real Google Maps is OPTIONAL unless explicitly required.

Do not replace a working route/map abstraction solely to add complexity.

---

# 26. UI / BRANDING CONTRACT

App:

WildGuard

Wordmark:

WILDGUARD

Tagline:

Conserve • Track • Protect

Primary color:

#1F5A43

Use broadly:

Dark green:
primary actions

Green:
success/synchronized

Amber:
pending/offline/warning

Red:
real errors/danger/rejected states

Background:

white / warm-light neutral

Use consistent:

- spacing
- cards
- buttons
- typography
- status chips
- field styles

Do not redesign individual screens into unrelated styles.

---

# 27. FROZEN DESIGN RULE

Assignment 02 corrected design is authoritative.

Implementation must remain aligned with:

Corrected Use Case Diagram
Corrected Class Diagram
Corrected Use Case Scenarios
Corrected Sequence Diagrams
Corrected Storyboards
Corrected Low-Fidelity Wireframes
Corrected High-Fidelity UI

Do NOT change functionality merely because an AI agent thinks another design is "better".

If implementation conflicts with the corrected design:

STOP.

Explain the mismatch.

Do not silently alter the design contract.

---

# 28. USE CASE OWNERSHIP BOUNDARIES

Each member owns ONE parent use case.

Do not duplicate another member's graded functionality.

## UC01 owns:

- patrol assignment
- patrol execution
- GPS/manual tracking
- patrol completion
- coverage

## UC02 owns:

- Ranger wildlife incident reports
- evidence
- incident location
- incident submission
- review workflow

## UC03 owns:

- community conflict reports
- collar readings
- risk alerts
- responder assignment
- acknowledgement
- response coordination
- outcome
- resolution

## UC04 owns:

- analytics
- conservation reports
- charts
- PDF/CSV reporting

UC04 reads other feature data but must not own their write operations.

---

# 29. CROSS-FEATURE RULE

Do not directly modify another feature's internal state from UI code.

Communicate through:

domain/repository interfaces

or established shared services.

Example:

UC04 must not update an IncidentReport directly.

UC03 must not create a UC02 IncidentReport to represent a community report.

UC02 must not create WildlifeRiskAlert for Ranger incident reporting unless the corrected design explicitly requires it.

---

# 30. ARCHITECTURE

Follow existing architecture.

Typical flow:

UI
↓
Riverpod Controller / Provider
↓
Repository Interface
↓
Repository Implementation
↓
Firestore / Drift / Service

Do not bypass repository layers from random screens.

Do not put large business workflows directly in Widgets.

---

# 31. STATE MANAGEMENT

Use existing Riverpod architecture.

Shared providers may include:

- current session
- database
- Firestore
- connectivity
- repositories
- sync service

Feature-specific state stays inside the corresponding feature.

Example:

features/patrol/
features/incidents/
features/conflict_response/
features/analytics/

Do not create one giant global application provider.

---

# 32. SOLID / CODE QUALITY

Code should remain:

- readable
- testable
- modular
- maintainable

Follow Single Responsibility.

Prefer dependency inversion through repository/service contracts.

Do not create god classes.

Do not create 1000-line Widgets.

Do not duplicate identical business logic.

Do not add abstraction purely for abstraction's sake.

Do not rewrite working architecture without a demonstrated problem.

---

# 33. COMMENTS / DOCUMENTATION

Comments should explain:

WHY

not obvious syntax.

Good:

// Use the client-generated ID so retries remain idempotent.

Bad:

// Increment count by one.

Public/shared non-obvious domain logic should be documented.

Do not fill files with meaningless comments solely to appear documented.

---

# 34. ERROR HANDLING

Never expose raw Firebase exceptions directly in UI.

Use understandable messages.

Do not swallow critical failures silently.

Preserve user-entered data when recovery is possible.

Important cases:

- local save failure
- network loss
- synchronization failure
- GPS unavailable
- unauthorized access
- invalid state transition
- Firestore unavailable
- Storage upload failure

---

# 35. AUTHENTICATION IS SUPPORTING INFRASTRUCTURE

Authentication exists to support role-specific business use cases.

Do NOT treat:

Login
Logout
Forgot Password
Admin User Management

as a fifth business use case.

Do not expand authentication scope unless explicitly requested.

---

# 36. TESTING CONTRACT

No feature is complete only because the UI looks correct.

Required checks:

flutter analyze

flutter test

For final grading:

flutter test --coverage

Assignment target:

>80% meaningful coverage for each selected use case where practical.

Tests must include:

positive cases
negative cases
edge cases
error cases

Do not create meaningless tests solely to inflate test count.

---

# 37. FEATURE TESTING RESPONSIBILITY

Each member is responsible for meaningful tests for their own use case.

## UC01 tests should cover examples such as:

assignment success/failure
status transitions
GPS position
manual waypoint
offline save
sync retry
duplicate prevention
completion
coverage

## UC02:

category validation
photo/omission rule
GPS/manual location
offline incident
sync
review queue filtering
verification/rejection
reviewer metadata

## UC03:

risk-zone detection
duplicate-open-alert prevention
community trigger
assignment
delivery
acknowledgement
timeout/escalation
reassignment
response
outcome
resolution

## UC04:

filter validation
authorization
snapshot generation
synchronized-only data
excluded pending data
statistics
coverage
trends
empty report
PDF/CSV same-snapshot export

---

# 38. GIT BRANCH STRATEGY

main

is the stable/integration branch.

Feature branches:

feature/uc01-patrol
feature/uc02-incidents
feature/uc03-conflict-response
feature/uc04-analytics

Members should work on their corresponding feature branch.

Do not directly push unfinished feature development to main.

Use Pull Requests into main.

---

# 39. BEFORE STARTING WORK

Every human/AI agent must:

1. Check current branch.
2. Pull latest appropriate base.
3. Inspect existing implementation.
4. Read AGENTS.md.
5. Identify feature ownership.
6. Reuse existing models/services/providers.
7. State what files are going to change.
8. Avoid unrelated changes.

---

# 40. BEFORE MERGING

Required:

flutter analyze

must pass.

flutter test

must pass.

No known destructive migration.

No hardcoded passwords.

No duplicate domain models.

No unrelated feature regressions.

No accidentally changed frozen design.

---

# 41. DO NOT DELETE WORKING TESTS

Never delete or weaken tests just to make CI pass.

If a test fails because requirements changed:

verify against the corrected design first.

Update code rather than weakening valid assertions.

---

# 42. DO NOT HARDCODE PRODUCTION CURRENT USER

Demo data may contain:

PM001
R001
R002
CLO001
CR001
PARK-MIN

These are valid DEMO/SEED references.

They must not replace actual authenticated session context in production flow.

Use:

currentUser.id
currentUser.role
currentUser.parkId

where required.

---

# 43. DEMO DATA

Canonical demo environment may include:

Park:

Minneriya National Park

Users:

Park Manager

K. Perera
Ranger

R. Silva
Ranger

S. Nimal
Community Liaison Officer

Conservation Researcher

Routes:

RT-07
North Ridge

RT-05
River Loop

RT-02
Gate Circuit

Risk Zones:

Farmland East
Village Edge
A11 Junction

Tracked Animal:

EL-07
Elephant

Demo data must remain separated from production business logic.

Do not hardcode demo values inside UI Widgets.

---

# 44. COMMUNITY REPORT BOUNDARY

A CommunityReport is NOT an IncidentReport.

IncidentReport:

Ranger field observation
→ UC02

CommunityReport:

community wildlife-conflict input
→ UC03

Do not combine them into one model solely for convenience.

---

# 45. REPORTING BOUNDARY

ConservationReport is derived/read-only output.

Do not make report generation create/modify operational records.

Analytics may read:

Patrol
IncidentReport
WildlifeRiskAlert

but should not own their state.

---

# 46. STATUS TRANSITIONS ARE DOMAIN RULES

Status validation belongs in testable domain/service/repository logic.

Do not rely only on disabled UI buttons.

Examples:

Patrol:

assigned → inProgress → completed

Alert:

newAlert → assigned → acknowledged → responseInProgress → resolved

Invalid operations must be rejected even if called programmatically.

---

# 47. AI AGENT RESTRICTIONS

AI agents MUST NOT automatically:

- recreate the Flutter project
- change package/bundle identifiers
- replace Riverpod
- replace Drift
- replace Firebase
- change Firestore collection names
- rename domain enums
- redesign all screens
- rewrite working features
- create new parent use cases
- introduce a new architecture
- change branch strategy
- remove tests
- weaken security rules
- hardcode credentials
- add unrelated packages
- push/commit/merge without explicit instruction

---

# 48. AI AGENT CHANGE POLICY

Before changing shared code, AI must answer:

Why is this shared change necessary?

Which use case requires it?

Could it be solved inside the feature module?

Will it affect another member?

Will it alter persisted data/schema?

If the change is not clearly necessary:

DO NOT make it.

---

# 49. SHARED MODEL CHANGE POLICY

Changes to these require extra caution:

User
Patrol
PatrolPosition
IncidentReport
WildlifeRiskAlert
ResponseAssignment
CommunityReport

Before changing fields:

check Firestore mapping
check Drift schema if relevant
check serialization
check tests
check other feature consumers

Never casually rename persisted fields.

---

# 50. DATABASE MIGRATION POLICY

Do not delete the local database to "fix" schema errors.

If Drift schema changes:

- increment schema version
- create migration
- preserve user data
- regenerate Drift code
- test migration

---

# 51. SECURITY RULE

Client UI role checks are not sufficient backend security.

Firestore/Storage security must still require authentication and appropriate access.

Do not permanently use:

allow read, write: if true;

Do not expose secrets.

---

# 52. APP UI RULE

The application should look professional and cohesive.

Do not allow each member to introduce a completely different visual system.

Use shared:

theme
colors
spacing
typography
buttons
input fields
cards
status components

Feature-specific UI may differ functionally but must still feel like WildGuard.

---

# 53. LOGIN UI RULE

Login should use WildGuard branding.

Required:

- wildlife hero/background
- WildGuard logo
- WILDGUARD title
- conservation subtitle
- email OR username field (single identifier field)
- password
- forgot password
- sign in
- authorized personnel message
- tagline

There is ONE login page for all users. No social login — the "Continue with
Google" button has been removed (do not re-add Google/Facebook/Apple/OTP unless
explicitly requested, per §13).

Onboarding: a splash screen followed by 3 onboarding pages (PNG illustrations in
assets/images/onboarding/) with Next + Skip; Skip/finish navigates to login.

Every authenticated area shows a role-aware bottom navigation bar that always
includes a Profile tab. The profile section shows the profile picture and the
staff member's details (read-only for staff; editable only by the admin).

Do not modify authentication backend merely for UI work.

---

# 54. WHAT MUST NOT BE OVER-ENGINEERED

Do not spend assignment time implementing:

- microservices
- complex GIS
- machine learning
- blockchain
- advanced event buses
- unnecessary custom backend
- custom authentication server
- unnecessary cloud functions
- enterprise-grade notification infrastructure

unless explicitly required.

This is a university software engineering case-study implementation.

Quality and alignment matter more than unnecessary complexity.

---

# 55. GRADING PRIORITY

The four parent business use cases are the graded implementation focus.

Priority order:

1. Correct implementation
2. Alignment with corrected design
3. Excellent UX
4. Maintainable code
5. Meaningful testing
6. Reliable persistence/offline behaviour
7. Optional polish

Do not sacrifice the core use case for unrelated enhancements.

---

# 56. DESIGN CHANGE RULE

If someone believes the frozen design must change:

DO NOT silently modify the app.

First document:

Current design
Problem
Proposed change
Reason
Affected UML/scenario/UI
Implementation impact

Get team approval.

Then update all affected artifacts consistently.

---

# 57. DEFINITION OF DONE FOR A FEATURE

A feature is DONE only when:

- corrected scenario is covered
- normal flow works
- required alternatives work
- required exception/error states work
- persistence works
- correct user/role access works
- UI matches WildGuard design
- tests are meaningful
- flutter analyze passes
- flutter test passes
- no unrelated feature is broken

A screen merely rendering is NOT completion.

---

# 58. CURRENT REPOSITORY BASELINE

The repository already contains substantial working architecture.

Agents must inspect the current code before creating anything new.

Expected existing systems include:

- Flutter
- Riverpod
- Firebase Authentication
- Firestore
- Firebase Storage
- Drift
- ConnectivityService
- SyncService
- role-based routing
- domain models
- repository interfaces
- shared design system
- UC01
- UC02
- UC03
- UC04
- automated tests

Never assume a component is missing solely because the prompt mentions it.

Inspect first.

---

# 59. SOURCE OF TRUTH ORDER

When rules appear to conflict, follow this order:

1. SE3070 Assignment 02 specification
2. Frozen corrected Assignment 02 design artefacts
3. This AGENTS.md
4. Existing domain contracts/tests
5. Feature-specific implementation conventions
6. Individual developer/AI preference

Personal preference is never above the corrected design.

---

# 60. FINAL AGENT INSTRUCTION

Before writing code, always ask:

- Which UC does this belong to?
- Which actor performs it?
- Does the corrected scenario require it?
- Does a model/service already exist?
- Am I changing another member's scope?
- Does this work offline if required?
- Can retry create duplicates?
- Is the current user coming from authenticated session?
- Does the status transition remain valid?
- Are tests required?
- Will this change break another feature?

If uncertain:

STOP and inspect the repository/design.

Do not guess.

---

# END OF WILDGUARD REPOSITORY CONTRACT
