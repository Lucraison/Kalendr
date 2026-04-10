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

### Must-do before next deploy

- [ ] **Migrate EF Core to PostgreSQL** — All existing SQLite migrations are now invalid. Steps:
  1. Delete everything in `Kalendr.API/Migrations/` (or archive it)
  2. `dotnet ef migrations add InitialPostgres`
  3. `dotnet ef database update` against a running Postgres instance

- [ ] **Install PostgreSQL on Hetzner VPS**
  ```bash
  apt install -y postgresql postgresql-contrib
  sudo -u postgres psql -c "CREATE USER chalk WITH PASSWORD 'your-password';"
  sudo -u postgres psql -c "CREATE DATABASE chalk OWNER chalk;"
  ```
  Then set the `ConnectionStrings__Default` env var in the systemd service unit.

- [ ] **Update systemd service unit** to inject the Postgres connection string:
  Add `Environment="ConnectionStrings__Default=Host=localhost;Port=5432;Database=chalk;Username=chalk;Password=..."` to `/etc/systemd/system/kalendr.service`

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
