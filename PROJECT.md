# Chalk — Project Log

> Formerly "Kalendr". Name changed to **Chalk**. Rename across codebase (files, namespaces, solution, Flutter package) is pending.

---

## Stack

| Layer | Technology |
|---|---|
| Backend API | ASP.NET Core 9, EF Core 9, SignalR |
| Database | **PostgreSQL** (migrated from SQLite — see below) |
| Mobile app | Flutter (Android, targeting Play Store internal track) |
| Auth | JWT (BCrypt password hashing) |
| Email | SMTP via MailKit |
| Realtime | SignalR (`/hubs/calendar`) |
| API docs | Scalar (`/scalar/v1`, dev only) |

## Infrastructure

| Thing | Detail |
|---|---|
| VPS | Hetzner |
| Deployment | `git pull` → `dotnet publish` → `systemctl restart kalendr` (systemd service) |
| Android CI | GitHub Actions → Flutter build → Play Store internal track |
| API CI | GitHub Actions → SSH into Hetzner on push to `main` |

---

## Features Implemented

- User auth (register, login, password reset via email, change password/email, delete account)
- Groups with invite codes, owner/member roles, color assignment, kick/transfer ownership
- Personal events and group events
- Event sharing (personal event shared to one or more groups)
- Event colors, all-day events, work schedule events
- Recurring event series (batch create, edit series, delete series) — keyed by `RecurrenceId`
- Reactions (emoji toggle per event), Comments, RSVPs (going/maybe/declined)
- Notifications (in-app, real-time via SignalR)
- Dark/light theme, localization (l10n), onboarding screen
- Calendar, Groups, Notifications, Profile tabs

---

## Change Log

### 2026-04-12 — VPS Hardening & Config Fixes

**JWT key was malformed in systemd override**
- The line `Environment="xK9#mP2$..."` was missing the `Jwt__Key=` prefix
- Systemd was treating the entire string as a variable name with no value
- App was falling back to the placeholder key in `appsettings.json`
- Fixed: `Environment="Jwt__Key=xK9#mP2$vL8nQ5rT7wY3uJ6hF4dA1eB0cG2iM9oS5pZ8kN3"`

**SMTP credentials moved into systemd override**
- `appsettings.Production.json` existed only in `/opt/kalendr/publish/` — fragile, not version-controlled, survives deploys by luck
- Moved all SMTP config into `/etc/systemd/system/kalendr.service.d/override.conf` so it survives any future `dotnet publish` overwrite
- Forgot password flow confirmed working

**PostgreSQL password rotated**
- Old password was exposed in a chat session
- Rotated via `ALTER USER chalk PASSWORD '...'` and updated the systemd override to match

**Ledgr API port locked to localhost**
- `ledgr-api.service` was binding to `0.0.0.0:5000` — directly reachable from the internet
- nginx was already proxying `ledgr.nherrera.dev` → `localhost:5000` correctly
- Fixed by replacing `Environment=PORT=5000` with `Environment=ASPNETCORE_URLS=http://localhost:5000` in the base service file
- Port now shows as `127.0.0.1:5000` only

---

### 2026-04-11 — SQLite → PostgreSQL Migration (Production)

**Full database migration completed on Hetzner VPS**
- Installed PostgreSQL 16, created `chalk` database and `chalk` user
- Dropped all old SQLite-generated EF Core migrations (TEXT columns for UUIDs — incompatible with Npgsql)
- Regenerated a single clean migration: `20260411145117_InitialCreate` (native `uuid` columns)
- Applied migration to fresh PostgreSQL schema — all tables created correctly
- App restarted and confirmed running: `Application started. Listening on http://localhost:5115`
- New migrations committed to GitHub so future deploys don't break

**Root cause of `operator does not exist: text = uuid`**
- Old SQLite migrations typed all UUID columns as `TEXT`
- Npgsql sends `uuid`-typed parameters — PostgreSQL refuses to compare `text` with `uuid`
- Fix: delete old migrations entirely, regenerate with Npgsql provider so columns get native `uuid` type

**`Program.cs` changes**
- Added `AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true)` for `DateTime` compatibility
- Added `opt.ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning))` to suppress EF Core 9 crash on nav property mismatch
- Added `using Microsoft.EntityFrameworkCore.Diagnostics`

---

### 2026-04-10 — Security: Keystore Exposure

**`tmp.b64` was committed to the public GitHub repo**
- File was the Android release keystore (PKCS#12) in base64, accidentally committed on Apr 7
- Untracked from git, added `*.b64` and `tmp.*` to `.gitignore`
- Purged from all 22 commits using `git filter-repo --path tmp.b64 --invert-paths --force`
- Force pushed to GitHub — file no longer exists anywhere in repo history

**Action still required:**
- Check Google Play Console → Release → Setup → App signing to confirm Play App Signing is enabled
- If Play App Signing is ON: the exposed key is the upload key only — Google holds the real distribution key, so impact is limited
- If Play App Signing is OFF: treat the keystore as compromised, generate a new one, and contact Google

---

### 2026-04-10 — Refactor & Bug Fixes

#### Backend (`Kalendr.API`)

**Removed dead title-based series endpoints**
- `DELETE /api/events/delete-series` (matched by title + groupId — fragile, collision-prone)
- `POST /api/events/update-series` (same problem)
- Removed `UpdateSeriesRequest` DTO from `Kalendr.Shared`
- The recurrenceId-based endpoints (`PUT /api/events/series/{id}`, `DELETE /api/events/series/{id}`) are the only series management path now

**Auth consistency in `EventsController`**
- `GetEvent` was reimplementing its own access check inline instead of using `CanAccessEventAsync`
- Replaced with the shared helper — one path, no divergence risk

**Navigation properties added to `CalendarEvent` model**
- Added `Reactions`, `Comments`, `Rsvps` collections to `CalendarEvent`
- Updated `AppDbContext` to wire these up via `WithMany(e => e.Reactions/Comments/Rsvps)`
- Model is now consistent — everything reachable through the entity graph

**SQLite → PostgreSQL**
- Swapped `Microsoft.EntityFrameworkCore.Sqlite` for `Npgsql.EntityFrameworkCore.PostgreSQL` in `Kalendr.API.csproj`
- Updated `Program.cs` to use `UseNpgsql`
- `appsettings.json` — connection string template updated, Jwt issuer/audience renamed to "Chalk"/"ChalkApp"
- `appsettings.Development.json` — local dev Postgres connection string added
- `Dockerfile` — added comment about PostgreSQL dependency and how to pass connection string

#### Flutter (`kalendr_app`)

**Removed dead series methods from `ApiService`**
- `updateSeries()` → called `POST /api/events/update-series` (now removed from API)
- `deleteEventSeries()` → called `DELETE /api/events/delete-series` (now removed from API)
- Note: `updateSeries` had a bug where it was passing `isAllDay` as `isWorkHours` — moot now since it's gone

---

## Pending / Known Issues

### VPS / Infrastructure

- [ ] **Run services as non-root** — both `kalendr` and `ledgr-api` run as root. Create a dedicated system user and update the service files. Low urgency but worth doing before the app grows.
- [ ] **Add swap** — currently 0B swap. With two .NET services on a 4GB box it's fine, but worth adding 2GB as a safety net.
- [ ] **Delete `kalendr.db`** — old SQLite file still at `/opt/Kalendr/Kalendr.API/kalendr.db`. Not used, just dead weight.

### Code quality

- [ ] No tests exist — highest-risk areas are auth, event sharing logic, and recurrence series operations
- [ ] `CanAccessEventAsync` does not handle group events shared to other groups (only direct group membership). Verify this is intentional.
- [ ] `DeleteAccount` in `AuthController` does not delete `EventGroupShares` owned by the user's events — may leave orphaned share rows (EF cascade should handle it, but worth verifying)

### Name change (Kalendr → Chalk) — pending

- [ ] Rename solution: `Kalendr.sln` → `Chalk.sln`
- [ ] Rename projects: `Kalendr.API` → `Chalk.API`, `Kalendr.Shared` → `Chalk.Shared`
- [ ] Update all namespaces (`Kalendr.API.*` → `Chalk.API.*`, etc.)
- [ ] Flutter: rename app name in `pubspec.yaml`, `AndroidManifest.xml`, bundle ID (`com.kalendr.kalendr_app` → `com.chalk.chalk_app`)
- [ ] `appsettings.json` Jwt issuer/audience — **done** (already set to "Chalk"/"ChalkApp")
- [ ] GitHub Actions workflow filenames + artifact name — `chalk-release-aab` already done in Android workflow
- [ ] Update `ApiService._base` production URL once domain is updated

---

## API Surface (current)

```
Auth
  POST   /api/auth/register
  POST   /api/auth/login
  DELETE /api/auth/account
  PATCH  /api/auth/password
  PATCH  /api/auth/email
  POST   /api/auth/forgot-password
  POST   /api/auth/reset-password

Groups
  GET    /api/groups
  POST   /api/groups
  GET    /api/groups/{id}
  POST   /api/groups/join
  PATCH  /api/groups/{id}/rename
  PATCH  /api/groups/{id}/color
  DELETE /api/groups/{id}/leave
  DELETE /api/groups/{id}/members/{userId}
  POST   /api/groups/{id}/transfer/{userId}

Events
  GET    /api/events/group/{groupId}
  GET    /api/events/personal
  POST   /api/events
  POST   /api/events/batch
  GET    /api/events/{id}
  PUT    /api/events/{id}
  PATCH  /api/events/{id}/metadata
  DELETE /api/events/{id}
  PUT    /api/events/series/{recurrenceId}
  DELETE /api/events/series/{recurrenceId}
  GET    /api/events/{id}/reactions
  POST   /api/events/{id}/reactions
  GET    /api/events/{id}/comments
  POST   /api/events/{id}/comments
  DELETE /api/events/comments/{id}
  GET    /api/events/{id}/rsvps
  POST   /api/events/{id}/rsvp

Notifications
  GET    /api/notifications
  POST   /api/notifications/mark-read
  DELETE /api/notifications/{id}

Realtime (SignalR)
  Hub:   /hubs/calendar
  Events emitted: EventCreated, EventUpdated, EventDeleted, SeriesDeleted,
                  ReactionAdded, ReactionRemoved
```
