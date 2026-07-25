# Jackpot

Cross-platform personal finance manager (Windows desktop + Android now, iOS later). Manual data entry only — no bank aggregator (Plaid, etc.) integration in this phase. Replaces spreadsheet-based budget tracking with a single dashboard for credit cards, loans, income, bills, and detailed category budgets.

Full feature roadmap, data model, and rationale: see `docs/PROJECT_PLAN.md`. This file only covers what Claude needs on every session — keep it that way when editing.

## Stack

- **Flutter (Dart)** — single codebase for desktop + mobile
- **Riverpod** — state management
- **Supabase** — Postgres + Auth + Row Level Security (source of truth)
- **PowerSync** — offline-first sync layer; mirrors Supabase tables into local SQLite so the app is fully usable offline and syncs in the background
- **SQLCipher** (under PowerSync's local DB) — encrypts the on-device SQLite cache at rest

## Commands

Fill these in once `flutter create` has run and CI is wired up — placeholders below are the expected shape:

- `flutter run -d windows` — run desktop build
- `flutter run -d android` — run on Android emulator/device
- `flutter test` — run unit + widget tests. Run this before every commit.
- `flutter analyze` — static analysis. Must be clean before committing.
- `flutter build windows --release` / `flutter build apk --release` — production builds

## Architecture decisions (non-obvious — don't relitigate these)

- **Offline-first, even though the product decision was "cloud-synced."** PowerSync mirrors Supabase to local SQLite so the app works with no connection and syncs when back online. Don't build a cloud-only data layer or add a "requires internet" check anywhere.
- **RLS is the security boundary for writes; PowerSync Sync Streams are the boundary for what replicates to a device.** Every table has a Postgres Row Level Security policy scoping rows to `auth.uid()`, and this remains authoritative for INSERT/UPDATE/DELETE. But PowerSync's replication connection to Supabase bypasses RLS — reads that sync to a device are scoped entirely by `powersync/sync-streams.yaml`. Treat that file as a security artifact of equal weight to RLS: every table's stream query must mirror its RLS policy's `user_id = auth.uid()` logic, and a change to one should prompt review of the other. Never rely on client-side filtering alone to isolate user data.
- **Computed values are never stored.** Credit utilization %, days-until-due, debt payoff projections, budget remaining — all calculated in Dart from raw balances/rates at read time, never persisted as columns. Storing them causes drift between synced replicas.
- **No bank API integration in this phase.** All entry is manual by product decision. Don't add Plaid or any account-aggregator dependency without an explicit go-ahead — it changes the compliance posture (PCI-adjacent obligations) of the whole app.
- **Budgeting is category-based and detailed, not a single total.** Each category has its own monthly target vs. actual. This is the core differentiator of the app — treat the budget engine as first-class, not a secondary feature.
- **Debt payoff supports both snowball and avalanche.** Snowball sorts by lowest balance first, avalanche by highest APR first. Let the user choose; don't hardcode one. Monthly interest on a balance = `balance × (APR / 12)`.
- **Asset tracking is intentionally out of scope for now** (planned as a future paid tier). Don't add an `assets` table casually — when it lands it should be an additive `Account` type (like `credit_card` or `loan` today), not a schema rework.

## Money handling — non-negotiable

- **Never use `double` for currency.** Floating-point arithmetic produces rounding errors that are unacceptable in a finance app. Use an integer minor-unit representation (store cents, not dollars) or a fixed-point decimal package. This applies to every balance, payment, and budget amount.
- **Concrete implementation: the `money2` package**, backed by integer minor units (cents). Construct `Money` values via `Money.fromInt`/`fromIntWithCurrency` at the Postgres `numeric(12,2)` boundary — never parse a `numeric` column into a Dart `double` en route. This is settled so Sprint 1 doesn't re-litigate the package choice.
- Round only at display time, using the stored precise value for all calculations.

## Code style

- Effective Dart conventions. `flutter analyze` clean before every commit.
- Riverpod providers organized per feature folder (`lib/features/<feature>/`), not one global providers file.
- No business logic in widgets. Money math (utilization, projections, budget calculations) lives in providers/services so it's unit-testable without a widget tree.

## Workflow

- Feature branches, one PR per feature, no direct commits to `main`.
- Any calculation touching money (interest, projections, utilization, budget remaining) needs a unit test before merging — this is the category of bug users will actually notice.
- Secrets (Supabase URL/anon key) come from `--dart-define`, never hardcoded or committed.

## Repo layout

```
lib/
  features/        # one folder per feature: dashboard, cards, loans, budgets, calendar
  data/             # Supabase/PowerSync models and repositories
  shared/           # shared widgets, theme, utils
docs/
  PROJECT_PLAN.md   # full roadmap, data model, phase breakdown
  ROADMAP.md        # sprint-level breakdown and Claude Code workflow
supabase/
  schema.sql        # Postgres schema + RLS policies — source of truth for the write-side boundary
powersync/
  sync-streams.yaml # PowerSync Sync Streams config — source of truth for the read/replication-side boundary
```
