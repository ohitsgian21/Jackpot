# Jackpot — Project Handoff (Phase 0 Bootstrap)

Written at the end of the initial bootstrap session. Read this first if you're picking the project back up after a break — it covers what exists, what's verified, what's still open, and what to study before going further.

## 1. What this project is

Jackpot is a cross-platform personal finance manager (Windows desktop + Android now, iOS later) replacing spreadsheet-based budget tracking. Manual data entry only (no Plaid/bank aggregator in this phase). Core differentiator: detailed category-based budgeting (target vs. actual per category per month), not a single total.

Full spec docs (read these for the "why" behind everything below):
- `CLAUDE.md` (root) — concise, load-every-session decisions and non-negotiables
- `docs/PROJECT_PLAN.md` — full product/technical spec
- `docs/ROADMAP.md` — sprint-level breakdown and the Claude Code workflow this project follows

## 2. Tech stack (all settled decisions — see `CLAUDE.md` for the "don't relitigate this" list)

| Layer | Choice |
|---|---|
| Client | Flutter (Dart), single codebase for Windows desktop + Android |
| State | Riverpod (`flutter_riverpod`) |
| Backend | Supabase (Postgres + Auth + Row Level Security) |
| Offline sync | PowerSync (mirrors Supabase → local SQLite) |
| Local encryption | SQLCipher, built into the `powersync` package |
| Secure token storage | `flutter_secure_storage` |
| Money | `money2` package, integer minor units (cents) — never `double` |

## 3. What's been done (this session)

### Dev environment (this machine)
- **Flutter 3.44.8-stable** installed manually to `C:\src\flutter`, added to user PATH (no official winget package exists for Flutter)
- **Android Studio** installed via `winget install Google.AndroidStudio`. Note: this only installs the IDE — the SDK itself was set up separately and headlessly:
  - Android SDK command-line tools downloaded to `C:\Users\OhItsGian\AppData\Local\Android\Sdk\cmdline-tools\latest`
  - `ANDROID_HOME` / `ANDROID_SDK_ROOT` set to `C:\Users\OhItsGian\AppData\Local\Android\Sdk` (user env vars)
  - `JAVA_HOME` set to `C:\Program Files\Android\Android Studio\jbr` (Android Studio's bundled JBR — no separate JDK install needed)
  - Installed via `sdkmanager`: `platform-tools`, `platforms;android-35`, `platforms;android-36`, `build-tools;35.0.0`, `build-tools;28.0.3`, `emulator`, `system-images;android-35;google_apis;x86_64` — all licenses accepted
  - AVD created: **`Pixel_Jackpot_API_35`** (medium_phone profile, Android 15 / API 35, x86_64)
- **Visual Studio Build Tools 2022** installed via winget, with the **`Microsoft.VisualStudio.Workload.VCTools`** workload (not `NativeDesktop` — that ID is for the full VS IDE, not Build Tools; this tripped up the first two install attempts) + `Microsoft.VisualStudio.Component.VC.ATL`
- **Windows Developer Mode enabled** via registry (`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock\AllowDevelopmentWithoutDevLicense = 1`) — required for Flutter plugin symlink support on Windows; without it, `flutter pub get` fails with a symlink error
- `flutter doctor -v` is **fully clean, no issues**, as of this session

### Repo structure
```
CLAUDE.md
docs/
  PROJECT_PLAN.md
  ROADMAP.md
  HANDOFF.md          ← this file
supabase/
  schema.sql          # Postgres schema + RLS policies (write-side security boundary)
powersync/
  sync-streams.yaml   # PowerSync Sync Streams config (read/replication-side boundary)
lib/
  main.dart
  data/
    secure_storage_local_storage.dart
  features/
    auth/
      auth_repository.dart
      auth_gate.dart
      login_screen.dart
      signup_screen.dart
    home/
      home_screen.dart   # placeholder post-login screen, replaced in Sprint 3
android/, windows/, test/   # standard flutter create output
```
Git: local repo only (`git init`, no remote configured yet), 2 commits so far.

### Architecture correction made this session (important)
The original docs said "RLS is the security boundary, not the app layer" as a blanket, settled statement. **This is only true for writes.** Research during this session found that PowerSync's replication connection to Supabase bypasses RLS entirely for reads — what syncs to a device is scoped by PowerSync's own **Sync Streams** config, not Postgres RLS. `CLAUDE.md` has been updated to reflect this: RLS governs writes, `powersync/sync-streams.yaml` governs what replicates to a device, and both need review with equal scrutiny. `powersync/sync-streams.yaml` currently mirrors every RLS policy in `supabase/schema.sql` table-for-table.

Also note: PowerSync's docs distinguish legacy "Sync Rules" (`bucket_definitions` YAML, `request.user_id()`) from the current recommended **Sync Streams** (`streams:` YAML, `auth.user_id()`) — this project uses Sync Streams throughout.

### Supabase + PowerSync (cloud accounts — created by the user, not automatable)
- Supabase project created: name `jackpot`, US region, URL `https://nooxqddqqwsbaetcrzhc.supabase.co`
- `supabase/schema.sql` has been run against it (tables + RLS policies exist)
- PowerSync Cloud instance created: `https://6a6415df91ecf2aec48d379a.powersync.journeyapps.com`
- Credentials live in **`env.json`** at the project root (gitignored, never committed) — `SUPABASE_URL`, `SUPABASE_ANON_KEY` (a publishable key, `sb_publishable_...` format), `POWERSYNC_URL`. Run the app with `--dart-define-from-file=env.json`.

### Auth wiring (Flutter code)
- `Supabase.initialize()` in `lib/main.dart`, using `publishableKey` (not the deprecated `anonKey` param)
- `SecureLocalStorage` / `SecureGotrueAsyncStorage` (`lib/data/secure_storage_local_storage.dart`) back the Supabase session and PKCE code verifier with `flutter_secure_storage` instead of the default plaintext `SharedPreferences`. Reads fail closed (return null/false, logged via `debugPrint`) rather than crash if secure storage is unreadable — this matters more on Windows, where `flutter_secure_storage` encrypts a file on disk (keyed via Credential Manager) rather than storing the secret directly in Credential Manager the way macOS/iOS keychain does.
- Email/password only (no social login yet — deferred by design, can be added later without a schema change)
- `AuthGate` (`lib/features/auth/auth_gate.dart`) watches auth state and routes to `LoginScreen` or the placeholder `HomeScreen`
- App-resume PIN/biometric lock was explicitly **deferred past Phase 0** (would use `local_auth` when added)

### Verification completed this session
- `flutter analyze` — clean
- `flutter test` — passing (a basic `LoginScreen` widget test)
- **Windows**: `flutter build windows --debug` succeeds; ran the built `jackpot.exe` directly — Supabase initialized successfully against the real project, no crash from the secure-storage native plugin
- **Android**: `flutter run -d emulator-5554` on the `Pixel_Jackpot_API_35` AVD — built, installed, launched, Supabase initialized successfully. (First run hit a stale Gradle daemon lock from an earlier interrupted attempt — fixed with `cd android && ./gradlew --stop`. Worth knowing if a future `flutter run` mysteriously fails with `Timeout waiting to lock build logic queue`.)

## 4. What's NOT done yet (explicitly deferred or blocked on manual steps)

**Manual steps only you can do** (not automatable — need browser/dashboard access):
1. Run the PowerSync replication role + publication SQL in Supabase's SQL Editor:
   ```sql
   CREATE ROLE powersync_role WITH REPLICATION BYPASSRLS LOGIN PASSWORD 'pick-a-strong-random-password';
   GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role;
   CREATE PUBLICATION powersync FOR ALL TABLES;
   ```
2. Connect PowerSync to Supabase: dashboard → Connect to Source Database → Postgres → paste Supabase's **direct connection** string (not the pooler) → set username to `powersync_role` and the password from step 1 → SSL mode `verify-full` (no certificate upload needed, Supabase's CA is trusted by default) → Test → Save.
3. Paste `powersync/sync-streams.yaml` into the PowerSync dashboard's Sync Streams section and deploy.
4. Create two test users in Supabase Auth and manually confirm querying as one never returns the other's rows (the RLS check `ROADMAP.md` Phase 0 calls for) — this checks the write-side boundary; deploying and reviewing sync-streams.yaml checks the read-side boundary. Both need to happen.
5. Try an actual signup in the running app. Supabase requires email confirmation by default — confirm this flow behaves sensibly (the signup screen already shows "Check your email to confirm your account" when `session == null` after signup, but hasn't been tested against a real inbox yet).

**Explicitly out of scope for Phase 0** (per decisions made this session, revisit when relevant):
- Sprint 1+ (accounts CRUD, income/bills, dashboard, calendar, budgets — see `docs/ROADMAP.md`)
- CI/GitHub Actions (no remote repo configured yet — repo is local-only by choice)
- Social login (Google/Apple)
- PIN/biometric app-resume lock (`local_auth`)
- Supabase MFA
- Firebase/FCM push notifications (needed starting Sprint 6)

## 5. Things to study / plan for before continuing

- **PowerSync Sync Streams semantics**: read `https://docs.powersync.com/sync/streams/overview` before writing any new table's stream — the `auth.user_id()` / `subscription.parameter()` mechanics and `auto_subscribe` behavior matter for how a future feature (e.g. filtering by a specific account) would request data.
- **money2 package API**: `Money.fromInt` / `fromIntWithCurrency` for constructing values from integer cents, and how it round-trips with Postgres `numeric(12,2)` — work this out concretely in Sprint 1 when the first real balance field gets built (credit card `current_balance`), not by ad hoc trial.
- **Debt payoff math** (Phase 2, but worth reading now while fresh): snowball = lowest balance first, avalanche = highest APR first, user chooses; monthly interest = `balance × (APR / 12)`. Already documented in `CLAUDE.md` and `PROJECT_PLAN.md`.
- **flutter_secure_storage on Windows**: behavior is file-based-encryption-keyed-via-Credential-Manager, not a direct Credential Manager entry. If a Windows install ever gets into a bad secure-storage state (e.g. after certain uninstall/reinstall sequences), the app should fail closed to the login screen (already implemented) — but this hasn't been stress-tested with an actual uninstall/reinstall cycle.
- **Recurring bill generation logic** (Sprint 2) — `bills.recurrence_rule` is a free-text column in the current schema with no defined format yet. Decide the recurrence rule representation (RRULE string? custom enum + interval?) before Sprint 2 starts.
- **Budget rollover semantics** (Sprint 5) — `budgets.rollover` is a boolean today; the actual rollover calculation (unused budget carries to next month) isn't designed yet.
- Re-read `docs/ROADMAP.md`'s "workflow" section before starting Sprint 1 — it recommends a spec-first `AskUserQuestion` interview written to a `SPEC.md`, then a **fresh session** to implement, rather than continuing in a long-running session.

## 6. How to run the app right now

```
cd "Jackpot SC"
flutter run -d windows --dart-define-from-file=env.json
# or
flutter run -d emulator-5554 --dart-define-from-file=env.json   # emulator must be running first
```
If the Android emulator isn't running: `emulator -avd Pixel_Jackpot_API_35` (needs `C:\Users\OhItsGian\AppData\Local\Android\Sdk\emulator` on PATH, or use the full path).

If a future `flutter run` on Android fails with a Gradle build-logic lock timeout, run `cd android && ./gradlew --stop` first.

## 7. Decisions log from this session (answers given when asked)

| Question | Answer |
|---|---|
| Plan scope | Phase 0 only (not Sprint 1) |
| Existing cloud accounts | None — created fresh |
| Dev environment setup | Include full setup (nothing was installed) |
| Git | Init locally only, no remote |
| Admin rights | Yes, full admin |
| Auth methods | Email/password only |
| Android testing | Both emulator and physical device |
| Supabase local dev | Cloud project only, no Docker |
| App lock (PIN/biometric) | Defer to later phase |
| Package identifier | `com.jackpot.app` |
| Supabase region | US |
