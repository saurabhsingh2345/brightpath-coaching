# BrightPath Coaching

A complete coaching-institute app: **one build** that shows an admin console or
a student portal depending on who logs in, backed by a real NestJS + PostgreSQL
API. Ships as an Android APK and as a web app from the same codebase.

> **Live:** <https://brightpath-coaching.vercel.app> ·
> **Android:** [latest release](https://github.com/saurabhsingh2345/brightpath-coaching/releases/latest) ·
> **Handing it to the institute?** [HANDOVER.md](HANDOVER.md) ·
> **Deploying / maintaining?** [DEPLOY.md](DEPLOY.md)

```
Flutter APK  ──HTTPS REST + WebSocket──▶  NestJS  ──Prisma──▶  PostgreSQL
```

Nothing in the app is mocked. Every screen reads and writes through the API.

---

## Contents

- [What's in it](#whats-in-it)
- [Project layout](#project-layout)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Demo logins](#demo-logins)
- [Running locally](#running-locally)
- [Pointing the app at your backend](#pointing-the-app-at-your-backend)
- [Building the APK](#building-the-apk)
- [Environment variables](#environment-variables)
- [Using Supabase instead of local Postgres](#using-supabase-instead-of-local-postgres)
- [API reference](#api-reference)
- [Rebranding](#rebranding)
- [Architecture notes](#architecture-notes)
- [Troubleshooting](#troubleshooting)

---

## What's in it

### Admin
| Area | What you can do |
|---|---|
| **Dashboard** | Total/active students, batches, today's attendance %, pending & overdue fees, collection rate, upcoming exams, recent announcements |
| **Students** | Create, edit, search, filter by batch/status, deactivate (keeps history) or hard-delete. Creating a student also creates their login |
| **Batches** | Create/edit/delete, capacity guard, activate/deactivate, drill into the roster |
| **Attendance** | Pick batch + date, mark Present / Absent / Late / Leave, bulk actions, day-wise history with percentages |
| **Fees** | Multi-installment plans, partial payments, running balance, payment history, printable receipts, automatic overdue flagging |
| **Timetable** | Weekly grid per batch with clash + room double-booking detection |
| **Exams** | Create exams with per-subject max marks, marks-entry grid with live totals, automatic percentage/grade/rank, publish or hide results |
| **Study material** | Upload PDFs/documents, assign to a batch or share institute-wide |
| **Announcements** | Send to all students or one batch, pin to top |
| **Chat** | 1:1 threads with any student, one group thread per batch, lock a group to read-only |
| **Profile** | Edit details, change password |

### Student
Dashboard (attendance %, fees due, next class, recent results, announcements),
own attendance history, fee ledger with receipts, weekly timetable, published
results with rank, study material for their batch, announcements, chat with
staff and their batch group, and profile/password settings.

### Access rules
Enforced server-side on every request, not just hidden in the UI:

- Students can only ever read **their own** attendance, fees and results — a
  student requesting another student's data gets `403`.
- Unpublished exam results are invisible to students.
- Students can chat with **staff and their own batch group** only, never with
  another student directly.
- Deactivated accounts cannot log in and their refresh tokens are revoked.

---

## Project layout

```
coaching-app/
├── backend/                     NestJS + Prisma REST API
│   ├── prisma/
│   │   ├── schema.prisma        12 models
│   │   ├── migrations/
│   │   └── seed.ts              demo data
│   ├── src/
│   │   ├── auth/                JWT + refresh, password change
│   │   ├── users/               admin user management
│   │   ├── students/            CRUD + summaries
│   │   ├── batches/             CRUD + roster assignment
│   │   ├── attendance/          sheet, bulk mark, history, reports
│   │   ├── fees/                plans, payments, receipts
│   │   ├── timetable/           weekly slots + clash detection
│   │   ├── exams/               subjects, marks, grades, ranks
│   │   ├── materials/           uploads assigned to batches
│   │   ├── announcements/       all-students or per-batch
│   │   ├── chat/                REST + Socket.IO gateway
│   │   ├── dashboard/           admin + student roll-ups
│   │   ├── uploads/             validated file storage
│   │   ├── common/              guards, decorators, error filter, paging
│   │   └── prisma/              Prisma service
│   ├── uploads/                 served read-only at /files
│   └── .env.example
├── mobile/                      Flutter app (one APK, both roles)
│   └── lib/
│       ├── core/                brand, config, theme, API client, formatters
│       ├── models/              response models
│       ├── services/            typed API facade + chat socket
│       ├── state/               auth, chat, async controller
│       ├── widgets/             loading/empty/error states, shared UI
│       └── screens/
│           ├── auth/            splash, login
│           ├── admin/           dashboard, students, batches, attendance,
│           │                    fees, exams, marks, announcements, more
│           ├── student/         dashboard, "me" hub
│           ├── chat/            list, thread, new chat
│           └── shared/          used by both roles (timetable, material,
│                                results, attendance report, receipt, profile)
├── .env.example
└── README.md
```

---

## Prerequisites

| Tool | Version used |
|---|---|
| Node.js | 20+ (tested on 24) |
| PostgreSQL | 14+ (tested on 18) — or a Supabase project |
| Flutter | 3.27+ (tested on 3.47, Dart 3.13) |
| JDK | 17+ |
| Android SDK | platform 36, build-tools 36 |

```bash
node -v && flutter --version && java -version
```

---

## Setup

### 1. Database

```bash
# macOS
brew install postgresql@16 && brew services start postgresql@16
createdb brightpath
```

Or with Docker:

```bash
docker run -d --name brightpath-db -p 5432:5432 \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=brightpath postgres:16
```

### 2. Backend

```bash
cd backend
cp .env.example .env          # then edit DATABASE_URL + the JWT secrets
npm install
npm run prisma:generate
npm run prisma:migrate        # creates the schema
npm run seed                  # demo data (safe to re-run)
npm run start:dev
```

The API is now on **http://localhost:4000** :

| | |
|---|---|
| REST | `http://localhost:4000/api` |
| Swagger docs | `http://localhost:4000/docs` |
| Health check | `http://localhost:4000/health` |
| Uploaded files | `http://localhost:4000/files/<name>` |
| Chat socket | `ws://localhost:4000/chat` |

> `npm run seed` **wipes and recreates** the demo tables. Don't run it against
> real data.

### 3. Mobile

```bash
cd mobile
flutter pub get
flutter run          # with an emulator or device attached
```

The default API base URL is `http://10.0.2.2:4000/api`, which is how the
**Android emulator** reaches your host machine. For a physical device see
[below](#pointing-the-app-at-your-backend).

---

## Demo logins

Created by `npm run seed`. The login screen has **Admin** and **Student**
shortcut buttons so you don't have to type these.

| Role | Email | Password |
|---|---|---|
| **ADMIN** | `admin@brightpath.edu` | `Admin@123` |
| STUDENT | `aarav@brightpath.edu` | `Student@123` |
| STUDENT | `diya@brightpath.edu` | `Student@123` |
| STUDENT | `vivaan@brightpath.edu` | `Student@123` |
| STUDENT | `ananya@brightpath.edu` | `Student@123` |
| STUDENT | `kabir@brightpath.edu` | `Student@123` |
| STUDENT | `isha@brightpath.edu` | `Student@123` |
| STUDENT | `rohan@brightpath.edu` | `Student@123` |
| STUDENT | `saanvi@brightpath.edu` | `Student@123` |
| STUDENT | `arjun@brightpath.edu` | `Student@123` |
| STUDENT | `meera@brightpath.edu` | `Student@123` |

All ten students share the same password. Change it with
`SEED_STUDENT_PASSWORD` in `.env`.

**Seeded data:** 1 admin · 10 students · 3 batches · 14 timetable slots ·
~150 attendance records over 31 days · 30 fee installments with 17 payments ·
4 exams (3 published) with results and ranks · 7 study material entries ·
5 announcements · 6 chat threads with 19 messages.

Students `aarav`, `kabir` and `meera` start with unread chat messages, so the
badge is visible immediately.

---

## Running locally

Two terminals:

```bash
# terminal 1
cd backend && npm run start:dev

# terminal 2
cd mobile && flutter run
```

Handy backend scripts:

```bash
npm run start:dev       # watch mode
npm run build           # compile to dist/
npm run start:prod      # run the compiled build
npm run prisma:migrate  # create + apply a migration
npm run prisma:deploy   # apply migrations (production)
npm run prisma:reset    # drop, re-migrate, re-seed
npm run prisma:studio   # browse the database
npm run seed            # re-seed demo data
npm run lint            # tsc --noEmit
```

Mobile:

```bash
cd mobile
dart analyze            # static analysis
flutter test            # unit tests for formatters + model parsing
```

---

## Pointing the app at your backend

The app reads its base URL from a compile-time define, so nothing is
hard-coded in source.

| Scenario | Command |
|---|---|
| Android emulator (default) | `flutter run` |
| Physical device on the same Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://192.168.1.9:4000/api` |
| Device over USB (`adb reverse tcp:4000 tcp:4000`) | `flutter run --dart-define=API_BASE_URL=http://localhost:4000/api` |
| Deployed backend | `flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/api` |

Find your LAN IP with `ipconfig getifaddr en0` (macOS) or `hostname -I` (Linux).
Set `PUBLIC_BASE_URL` in the backend `.env` to the **same** host so uploaded
files resolve; the app also rewrites `localhost` file URLs as a fallback.

Plain HTTP is only permitted for development hosts — see
`mobile/android/app/src/main/res/xml/network_security_config.xml`. Production
traffic must be HTTPS, which needs no change to that file.

---

## Building the APK

```bash
cd mobile

# universal debug build
flutter build apk --debug

# release, pointing at a deployed backend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api

# smaller per-architecture APKs
flutter build apk --release --split-per-abi

# Play Store bundle
flutter build appbundle --release
```

Output: `mobile/build/app/outputs/flutter-apk/app-release.apk` (~57 MB
universal, ~20 MB per ABI).

### Signing for release

The scaffold signs release builds with the **debug** key so `--release` works
out of the box. Before publishing, create a keystore and wire it up:

```bash
keytool -genkey -v -keystore ~/brightpath.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias brightpath
```

`mobile/android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=brightpath
storeFile=/absolute/path/to/brightpath.jks
```

Then replace `signingConfig = signingConfigs.getByName("debug")` in
`mobile/android/app/build.gradle.kts` with a config that reads those values.

---

## Environment variables

`backend/.env` (copy from `.env.example`):

| Variable | Purpose |
|---|---|
| `NODE_ENV` | `development` \| `production` |
| `PORT` | API port (default `4000`) |
| `API_PREFIX` | Route prefix (default `api`; `/health` stays unprefixed) |
| `DATABASE_URL` | Postgres connection string. Pooled URL on Supabase |
| `DIRECT_URL` | Non-pooled URL used by `prisma migrate`. Same as `DATABASE_URL` locally |
| `JWT_ACCESS_SECRET` | Access-token secret — **change this**, 32+ chars |
| `JWT_REFRESH_SECRET` | Refresh-token secret — **change this**, different from the above |
| `JWT_ACCESS_EXPIRES_IN` | Access token lifetime (default `15m`) |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token lifetime (default `30d`) |
| `CORS_ORIGINS` | Comma-separated origins, or `*` for development |
| `UPLOAD_DIR` | Where files are stored (default `uploads`) |
| `MAX_UPLOAD_SIZE_MB` | Per-file upload cap (default `20`) |
| `PUBLIC_BASE_URL` | Public origin used to build file URLs |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | Seeded admin credentials |
| `SEED_STUDENT_PASSWORD` | Password for every seeded student, and the default for new students |

Generate secrets with:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

## Using Supabase instead of local Postgres

1. Create a Supabase project and open **Project settings → Database**.
2. Put the **pooled** (pgBouncer, port `6543`) URI in `DATABASE_URL` and the
   **direct** (port `5432`) URI in `DIRECT_URL`. Prisma needs the direct one to
   run DDL:

   ```env
   DATABASE_URL="postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1"
   DIRECT_URL="postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:5432/postgres"
   ```

3. `npm run prisma:deploy && npm run seed`

The schema is plain PostgreSQL, so no Supabase-specific changes are needed.
Files are stored on the API server's disk; swap `UploadsService` for Supabase
Storage if you'd rather not keep local files.

---

## API reference

Full interactive docs at `/docs`. Every route needs
`Authorization: Bearer <accessToken>` except `/health` and the two public auth
routes.

<details>
<summary><b>auth</b></summary>

| Method | Route | Notes |
|---|---|---|
| POST | `/api/auth/login` | public |
| POST | `/api/auth/refresh` | public; rotates the refresh token |
| POST | `/api/auth/logout` | revokes the stored refresh token |
| GET | `/api/auth/me` | profile (+ student profile when applicable) |
| PATCH | `/api/auth/me` | update name/phone |
| POST | `/api/auth/change-password` | signs out every device |
</details>

<details>
<summary><b>dashboard, students, batches</b></summary>

| Method | Route | Role |
|---|---|---|
| GET | `/api/dashboard/admin` | admin |
| GET | `/api/dashboard/student` | student |
| GET | `/api/students` | admin — paginated, `search`, `batchId`, `isActive` |
| GET/POST | `/api/students`, `/api/students/:id` | admin |
| PATCH | `/api/students/:id` | admin |
| PATCH | `/api/students/:id/deactivate` · `/activate` | admin |
| DELETE | `/api/students/:id` | admin — permanent |
| GET | `/api/batches`, `/api/batches/:id` | both (read-only for students) |
| POST/PATCH/DELETE | `/api/batches...` | admin |
| POST | `/api/batches/:id/students` | admin — assign, capacity checked |
| DELETE | `/api/batches/:id/students/:studentId` | admin |
</details>

<details>
<summary><b>attendance, fees</b></summary>

| Method | Route | Role |
|---|---|---|
| GET | `/api/attendance/sheet?batchId=&date=` | admin — roster, pre-filled |
| POST | `/api/attendance/mark` | admin — bulk upsert |
| GET | `/api/attendance/history` | admin |
| GET | `/api/attendance/batch/:id/days` | admin — day-wise roll-up |
| GET | `/api/attendance/student/:id` | own data only for students |
| GET | `/api/attendance/me` | student |
| GET | `/api/fees` | admin — `status`, `batchId`, `studentId`, `search` |
| POST | `/api/fees/plan` | admin — multi-installment plan |
| POST | `/api/fees/:id/payments` | admin — full or partial |
| GET | `/api/fees/receipt/:paymentId` | receipt data |
| GET | `/api/fees/student/:id` · `/api/fees/me` | ledger |
</details>

<details>
<summary><b>timetable, exams, materials, announcements</b></summary>

| Method | Route | Role |
|---|---|---|
| GET | `/api/timetable/batch/:id` · `/next` · `/api/timetable/me` | both |
| POST/PATCH/DELETE | `/api/timetable...` | admin — clash checked |
| GET | `/api/exams`, `/api/exams/:id` | admin |
| GET | `/api/exams/:id/marks-sheet` | admin — entry grid |
| POST | `/api/exams/:id/results/bulk` | admin — recalculates ranks |
| PATCH | `/api/exams/:id` | admin — `isPublished` toggles visibility |
| GET | `/api/exams/student/:id` · `/api/exams/me` | published only for students |
| GET | `/api/materials` · `/api/materials/me` | both |
| POST | `/api/materials` | admin — `multipart/form-data` |
| GET | `/api/announcements` · `/api/announcements/me` | both |
| POST/PATCH/DELETE | `/api/announcements...` | admin |
| POST | `/api/uploads` | admin — standalone upload |
</details>

<details>
<summary><b>chat</b></summary>

| Method | Route | Notes |
|---|---|---|
| GET | `/api/chat/conversations` | threads + unread counts |
| GET | `/api/chat/unread` | total, for the tab badge |
| GET | `/api/chat/contacts?search=` | who you may message |
| POST | `/api/chat/direct` | open/create a 1:1 thread (idempotent) |
| POST | `/api/chat/batch/:batchId` | admin — create/repair a group thread |
| GET | `/api/chat/conversations/:id/messages?before=&limit=` | paged, oldest-first |
| POST | `/api/chat/conversations/:id/messages` | send; also pushed over the socket |
| PATCH | `/api/chat/conversations/:id/read` | clears unread |
| PATCH | `/api/chat/conversations/:id/lock` · `/unlock` | admin — group read-only |
| DELETE | `/api/chat/messages/:id` | soft delete |

**Socket** — namespace `/chat`, authenticate in the handshake:

```js
io('http://localhost:4000/chat', { auth: { token: accessToken } })
```

Server events: `ready`, `message`, `conversation`, `unauthorized`.
</details>

---

## Rebranding

Everything visual lives in **`mobile/lib/core/brand.dart`**:

```dart
static const String name = 'BrightPath';
static const String fullName = 'BrightPath Coaching';
static const String tagline = 'Learn with clarity';
static const Color seed = Color(0xFF3D5AFE);   // whole M3 palette derives from this
static const IconData logo = Icons.school_rounded;
static const String currencySymbol = '₹';
```

Change `seed` and the entire light **and** dark colour scheme regenerates.
Also update the launcher name in
`mobile/android/app/src/main/AndroidManifest.xml` (`android:label`) and the
institute name in `backend/src/fees/fees.service.ts` (`institute:`) which is
printed on receipts.

---

## Architecture notes

**Auth.** Short-lived access tokens (15 min) plus rotating refresh tokens
(30 days). Only a bcrypt hash of the refresh token is stored, and it's hashed
over a SHA-256 digest first — bcrypt silently truncates at 72 bytes, and two
JWTs for the same user share a longer prefix than that, so hashing the raw
token would make any two of them compare equal. Each refresh token also carries
a random `jti` so rotation invalidates the previous one even when two are issued
in the same second. The Flutter `ApiClient` refreshes once on a 401 and replays
the original request, collapsing concurrent 401s into a single refresh.

**Authorisation.** Two global guards: `JwtAuthGuard` (every route is
authenticated unless marked `@Public()`) and `RolesGuard` (`@Roles(Role.ADMIN)`).
Row-level ownership is checked inside the services, so a student cannot read
another student's records even with a valid token.

**Errors.** One `AllExceptionsFilter` turns validation failures, Prisma errors
and unexpected throws into the same JSON shape, so the app can always render
`message`. Prisma codes are mapped to sensible statuses (`P2002` → 409 with the
conflicting field, `P2025` → 404, and so on).

**Attendance integrity.** `@@unique([studentId, date])` makes duplicate
attendance impossible at the database level. Marking is an idempotent bulk
upsert, so a day can be corrected repeatedly. Requests are rejected if the same
student appears twice, the date is in the future, or the student is already
marked that day in a *different* batch.

**Money.** Stored as `Decimal(10,2)`, never floats. Fee status is always derived
from `(total, paid, dueDate)` in one place, so `PAID` / `PARTIAL` / `OVERDUE`
can never drift from the amounts. Payments are transactional and rejected if
they exceed the remaining balance. Receipt numbers are sequential per year.

**Ranks.** Dense ranking by percentage — tied students share a rank — and
recalculated for the whole exam whenever any result changes.

**Uploads.** The client filename is never trusted: files are stored under a
random name whose extension must match the declared MIME type (which is
allow-listed), and deletes are path-guarded.

**Chat.** REST is the source of truth; the Socket.IO gateway only broadcasts
messages that are already persisted, and each client also polls the
conversation list every 20 s. A dropped socket therefore degrades to "slightly
stale", never to "lost messages" — and the UI shows a quiet reconnecting strip
while it's down. Batch-thread membership is reconciled whenever the
conversation list is opened, so a newly-assigned student picks up their group
chat automatically. Sending shows an optimistic bubble that is replaced by the
saved message, and restores your text into the input if the send fails.

**Flutter state.** Deliberately small: `provider` for dependency injection,
`ChangeNotifier` for auth and chat, and one `AsyncController<T>` that owns
loading/data/error for every screen — which is why the empty, loading and error
states look identical everywhere.

---

## Troubleshooting

**"Cannot reach the server" in the app**
The emulator can't see `localhost`. Use `10.0.2.2` (the default) or pass your
LAN IP via `--dart-define=API_BASE_URL=...`. Check
`curl http://localhost:4000/health` first.

**Port 4000 already in use**
Change `PORT` in `backend/.env`, then rebuild the app with a matching
`API_BASE_URL`.

**`prisma migrate` fails on Supabase**
`DIRECT_URL` must be the non-pooled connection (port `5432`). pgBouncer cannot
run the DDL that migrations need.

**Gradle: "requires compileSdk 36 or later"**
Already handled — `mobile/android/build.gradle.kts` aligns every plugin
subproject to the app's `compileSdk`. Some plugins still pin an older SDK than
their own transitive AARs require.

**Uploaded files 404 from the device**
`PUBLIC_BASE_URL` in `backend/.env` must be a host the phone can reach, not
`localhost`.

**Chat shows "Reconnecting…"**
The socket is down but the app still works — messages arrive on the next poll.
Confirm the WebSocket host matches your API host and that nothing between them
strips upgrade headers.

**Seed data looks wrong after experimenting**
`cd backend && npm run prisma:reset` (drops, re-migrates, re-seeds).
