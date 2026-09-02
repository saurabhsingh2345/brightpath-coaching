# Deploying & maintaining

Everything is already provisioned and live. This is the map of what runs where
and how to push a change.

## What's running

| Piece | Service | Free tier | Notes |
|---|---|---|---|
| Web app + API | **Vercel** — project `brightpath-coaching` | Hobby | One deployment serves both, same origin |
| PostgreSQL | **Neon** via Vercel Marketplace — `brightpath-db` | 0.5 GB | Env vars injected automatically |
| Uploaded files | Stored **in Postgres** (`file_objects`) | — | See "Why files live in Postgres" |
| Source | **GitHub** `saurabhsingh2345/brightpath-coaching` (private) | — | |
| Android APK | **GitHub Releases**, built by Actions | — | Push a tag to publish |

Live URLs:

- App + API — <https://brightpath-coaching.vercel.app>
- API docs (Swagger) — <https://brightpath-coaching.vercel.app/docs>
- Health — <https://brightpath-coaching.vercel.app/health>

## Push a change

```bash
git add -A && git commit -m "…" && git push      # source of truth
./deploy.sh                                      # web + API live
```

`deploy.sh` builds the Flutter web bundle into `backend/public/` and deploys
the backend, which serves both. Anyone on the web link sees the change
immediately.

Add `--apk` to also build an Android APK locally:

```bash
./deploy.sh --apk
```

### Release a new APK to the institute

```bash
git tag v1.0.1 && git push origin v1.0.1
```

GitHub Actions builds it and attaches it to a release. Send them
<https://github.com/saurabhsingh2345/brightpath-coaching/releases/latest>.
The URL never changes, so the same link always gives the newest build.

The workflow reads the backend URL from the repo variable `API_BASE_URL`
(currently `https://brightpath-coaching.vercel.app/api`). Change it with:

```bash
gh variable set API_BASE_URL --body "https://your-new-host/api"
```

### Change the database schema

```bash
cd backend
npx prisma migrate dev --name what_changed   # writes + applies locally
cd .. && ./migrate.sh                        # applies to the hosted database
./deploy.sh
```

Never edit a migration that has already been applied — add a new one.

## Environment variables

Managed in Vercel, not in files. To inspect or change:

```bash
cd backend
vercel env ls                                    # names only
vercel env add SOME_KEY production               # add/replace
vercel env pull                                  # refresh backend/.env.local
```

`DATABASE_URL` / `DATABASE_URL_UNPOOLED` come from the Neon integration —
don't set them by hand. `DIRECT_URL` mirrors the unpooled one because Prisma
needs a non-pooled connection for migrations.

The JWT secrets were generated at setup. Rotating them signs everyone out:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## Local development

```bash
cd backend
cp .env.example .env        # point DATABASE_URL at a local Postgres
npm install
npm run prisma:migrate
npm run seed
npm run start:dev           # http://localhost:4000

cd ../mobile
flutter run                 # emulator reaches the host on 10.0.2.2
```

Local runs use the `disk` storage driver, so uploads land in `backend/uploads/`
as before. Production uses `database`. Override with `STORAGE_DRIVER`.

To point the local app at *production* instead:

```bash
flutter run --dart-define=API_BASE_URL=https://brightpath-coaching.vercel.app/api
```

## Design decisions worth remembering

**Why the API serves the web app.** The Flutter web bundle is copied into
`backend/public/` and served by Nest. One origin means the browser build needs
no configuration and there is no CORS to maintain — `AppConfig` just uses
`window.location.origin` on web.

**Why files live in Postgres.** Serverless hosts have no persistent disk. Vercel
Blob was the first choice but this account's Blob stores are suspended at the
free-tier threshold, so bytes go in the `file_objects` table instead. At
institute scale (lecture notes) that is simpler than an object store, and a
database backup covers the files too. Uploads are capped at 8 MB to protect
Neon's 0.5 GB. `UploadsService` has a driver seam — add an S3/Blob driver there
if the volume ever outgrows this.

**Real-time chat works on Vercel.** Verified in production: Socket.IO holds the
connection and pushes arrive. Because instances can recycle, the client also
polls the conversation list every 20 s, so a missed socket frame degrades to a
short delay rather than a lost message.

**The demo data is removable, safely.** Every seeded row carries `isDemo`.
`POST /api/maintenance/clear-demo-data` deletes only those rows, so the
institute's own records are structurally out of reach of that operation.

**Redeploys never overwrite real data.** `npm run seed:if-empty` (what a fresh
deploy would use) exits immediately if any user exists. Plain `npm run seed`
wipes and rebuilds the demo tables and is for local use.

## Cost

Free at this scale. Watch for:

- **Neon 0.5 GB** — mostly the `file_objects` table. `select
  pg_size_pretty(pg_total_relation_size('file_objects'));`
- **Vercel Hobby** — non-commercial use. If the institute pays for this app,
  Vercel expects a Pro plan.
- **Neon free projects idle** after inactivity and wake on the next request,
  which can make the first load of the day take a few seconds.
