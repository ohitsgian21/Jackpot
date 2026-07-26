# Sprint 1 — Accounts CRUD (credit cards + loans)

Written from an `AskUserQuestion` interview per `docs/ROADMAP.md`'s workflow. Implement this in a **fresh session** with clean context, working from this doc rather than scrollback.

Scope per `docs/ROADMAP.md`: "Accounts — CRUD for credit cards and loans (data layer, repository, forms)." Verify: "Widget tests for validation; a card/loan created in the UI appears correctly in Supabase."

## 0. Foundational prerequisite — PowerSync client is not wired in yet

Checked before writing this spec: `lib/` has no PowerSync schema, no `PowerSyncDatabase` instance, no `PowerSyncBackendConnector`. Only Supabase Auth exists so far (`lib/main.dart`, `lib/features/auth/`). The `powersync: ^2.3.2` package is a pubspec dependency but otherwise untouched.

Per `CLAUDE.md`: **offline-first is non-negotiable** — the app reads and writes local SQLite via PowerSync, which syncs to Supabase in the background. That means account CRUD must go through the PowerSync local database, not direct `supabase_flutter` table calls. This sprint therefore starts with:

1. **Local schema** (`lib/data/powersync/schema.dart` or similar) — `Table` definitions for at least `accounts`, `credit_card_details`, `loan_details` (mirroring `supabase/schema.sql`'s columns for those three tables). Money columns (`credit_limit`, `current_balance`, `apr`, `minimum_payment`, `original_principal`, `remaining_balance`, `interest_rate`, `monthly_payment`) **must be declared as `text` in the local schema, not `real`** — PowerSync's `real` type is a float and would silently reintroduce the exact rounding-error risk `CLAUDE.md` prohibits. Storing as text preserves the exact decimal string round-tripped from Postgres `numeric(12,2)`, and the repository layer parses that string into `Money` at the boundary (never through a `double`).
2. **`PowerSyncDatabase` instance**, initialized in `main.dart` alongside `Supabase.initialize()`, opened against a local file (SQLCipher-encrypted per `CLAUDE.md` — confirm the `powersync` package's default local DB is already SQLCipher-backed, or whether an explicit key/config is needed).
3. **`PowerSyncBackendConnector`** implementation: `fetchCredentials()` returns the current Supabase session's access token + the `POWERSYNC_URL` from `env.json`; `uploadData()` reads PowerSync's local crud queue and applies each op against Supabase (via `supabase_flutter`'s client, matching table-for-table). Needs to react to Supabase token refresh (`authStateChangesProvider` already exists in `lib/features/auth/auth_repository.dart` and can likely drive re-connecting the PowerSync client on sign-in/out).
4. Confirm `.connect()` is called after a session exists (post-`AuthGate`) and disconnected/cleared on sign-out, so one user's local cache is never visible to the next user on a shared device.

This is real scope, not a checkbox — expect it to be the highest-risk, least-familiar part of the sprint. Everything below (repository, forms, list) builds on top of it.

## 1. Entry point / navigation

`HomeScreen` (`lib/features/home/home_screen.dart`) stops being a placeholder and becomes the real accounts list:
- App bar: "Jackpot" title, sign-out action (unchanged).
- Body: list of the signed-in user's accounts (see §4).
- FAB: opens the add-account flow (§2).

No separate navigation shell (drawer/bottom nav/tabs) this sprint — a single list screen is the whole UI. Sprint 3 (dashboard) will build the real app shell around this later.

## 2. Add-account flow

Single flow, reached from the FAB:
1. A type-selector step: **Credit Card** or **Loan**.
2. Based on the choice, show that type's form (§3). Submitting inserts one row into `accounts` and one into `credit_card_details` or `loan_details` — both writes happen in a single local PowerSync transaction so they can't end up inconsistent (an `accounts` row with no matching detail row, or vice versa).

Editing an existing account reuses the same form (pre-filled), reached by tapping a list row.

## 3. Form fields

Required fields raise a validation error on submit if empty; optional fields can be left blank and filled in later via edit. Matches `supabase/schema.sql`'s nullable columns exactly — no new constraints invented here.

**Both types share:**
- `name` — required, free text
- `institution` — optional, free text

**Credit card (`credit_card_details`):**
- `credit_limit` — required, currency
- `current_balance` — optional, currency, defaults to 0 if left blank (matches the schema's `default 0`)
- `apr` — optional, percentage (e.g. enter `24.99`, stored as `numeric(5,2)`)
- `statement_date` — optional, date picker
- `due_date` — optional, date picker
- `minimum_payment` — optional, currency

**Loan (`loan_details`):**
- `original_principal` — required, currency
- `remaining_balance` — required, currency
- `interest_rate` — optional, percentage
- `term_months` — optional, integer
- `monthly_payment` — optional, currency
- `due_date` — optional, date picker
- `start_date` — optional, date picker

**Currency input:** plain `TextFormField` with a decimal numeric keyboard (`TextInputType.numberWithOptions(decimal: true)`), validated as a well-formed non-negative decimal with at most 2 fraction digits, then parsed straight into `Money.fromFixedWithCurrency` (or equivalent — avoid any intermediate `double`) at submit time. No masked/formatted-while-typing input this sprint.

**Percentage input (APR/interest rate):** plain decimal text field, validated as 0–100 with up to 2 fraction digits, stored as-is in `numeric(5,2)`.

## 4. Accounts list

- One combined `ListView`, not separated into Cards/Loans sections — sorted by `created_at` (newest first) is a reasonable default unless you'd rather sort by name.
- Each row shows: an icon or badge distinguishing credit card vs. loan, the account `name`, `institution` (if set), and the balance (`current_balance` for cards, `remaining_balance` for loans).
- Empty state: friendly message + prompt to tap the FAB, when the user has zero accounts.
- Tapping a row opens it pre-filled in the edit form (§2/§3).

## 5. Delete

- Swipe-to-delete or an overflow-menu action on each list row (implementer's choice — pick whichever is less code, no strong preference expressed).
- Standard confirmation dialog: *"Delete [name]? This can't be undone."* — same wording regardless of balance, no special-casing for a nonzero balance.
- Deleting the `accounts` row cascades to `credit_card_details`/`loan_details` via the schema's `ON DELETE CASCADE` — no need to delete the detail row separately, but confirm this cascade actually fires through PowerSync's local-write-then-sync path the same way it would with a direct Postgres delete (worth an explicit manual check, not just an assumption).

## 6. Money handling (restating `CLAUDE.md`'s non-negotiable, for this sprint specifically)

- Never let a `numeric` value pass through a Dart `double` at any point — not in the local PowerSync schema (§0), not in form parsing (§3), not in display formatting.
- Round only at display time, using `money2`'s formatting.

## 7. Testing / definition of done

Matches `docs/ROADMAP.md`'s stated verify step, nothing added beyond it:
- Widget tests covering form validation (required-field errors, malformed currency/percentage input rejected) for both the credit card and loan forms.
- `flutter analyze` clean.
- One manual end-to-end check per account type: create it in the running app, confirm both the `accounts` row and its `credit_card_details`/`loan_details` row appear correctly in Supabase's Table Editor, with the money values exactly matching what was typed (no rounding drift).
- No repository-layer unit tests or PowerSync-specific integration tests this sprint (explicitly deferred, not an oversight).

## 8. Explicitly out of scope this sprint

- Dashboard, calendar, budgets — later sprints.
- Any navigation shell beyond the single accounts list screen.
- Recurring due-date logic (bills' `recurrence_rule` format is still undecided per `docs/HANDOFF.md` §5 — irrelevant to this sprint anyway since it's a `bills` concern, not `accounts`).
- Multi-currency, CSV import, debt payoff calculator — Phase 2.
