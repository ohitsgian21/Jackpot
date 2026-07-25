# Jackpot — product & technical specification

This supersedes the earlier planning doc. `CLAUDE.md` at the repo root is the concise, load-every-session version of the decisions below — this file is the full reasoning, for whenever you or Claude Code need the "why," not just the "what."

## 1. Vision

Jackpot replaces spreadsheet-based budget tracking with a single, cross-platform home for credit cards, loans, income, bills, and a genuinely detailed budget — not a toy summary screen. Manual entry, cloud-synced, offline-capable, built to grow into a commercial product without a rewrite.

## 2. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Client | Flutter (Dart) | One codebase for Windows desktop and Android now; iOS is a near-free add later |
| State | Riverpod | Predictable, testable, scales per-feature |
| Backend | Supabase (Postgres + Auth + Realtime + Row Level Security) | Relational data model fits SQL; RLS is the security boundary from day one |
| Offline sync | PowerSync | Mirrors Supabase Postgres into local SQLite automatically — the app reads/writes locally and syncs in the background, so it stays fully usable with no connection. This is a maintained sync engine, not hand-rolled sync logic. |
| Local encryption | SQLCipher (under PowerSync's local DB) | Encrypts the on-device cache at rest — financial data shouldn't sit in plaintext SQLite even locally |
| Notifications | Firebase Cloud Messaging | Due-date reminders on both platforms |
| Payments (Phase 3) | Stripe + Google Play Billing | Only needed once subscriptions ship |

## 3. Architecture pattern

Research into current (2026) Flutter practice confirms a specific tradeoff: full Clean Architecture (domain/data/presentation layers, use-case objects, dependency injection graphs) earns its cost on apps with 5+ features, multiple developers, or long maintenance windows. Below that, it's boilerplate for its own sake.

Jackpot starts with **feature-first folders + a lightweight repository pattern**:

```
lib/
  features/
    dashboard/
    cards/
    loans/
    bills/
    budgets/
    calendar/
  data/       # Supabase/PowerSync models and repositories
  shared/     # shared widgets, theme, utils
```

Riverpod providers call repositories directly — no use-case layer. If a feature's business logic outgrows a single repository method (this becomes likely around Phase 2's debt-payoff engine), introduce use-cases for *that feature only*, not as a blanket rewrite.

## 4. Data model

Core entities (full SQL in `supabase/schema.sql`):

| Entity | Purpose |
|---|---|
| `accounts` | Parent record for any tracked account — type discriminates card/loan/bank/cash |
| `credit_card_details` | Limit, balance, APR, statement/due dates, minimum payment |
| `loan_details` | Principal, remaining balance, rate, term, monthly payment, due date |
| `income_sources` | Name, amount, frequency, next expected date |
| `categories` | User-defined income/expense categories |
| `bills` | Recurring or one-time bills, linked to a category |
| `budgets` | **Category × month × target amount** — the core differentiator |

Computed values — utilization %, days-until-due, debt payoff date, budget remaining — are calculated in Dart at read time and never stored as columns. Storing them would drift between synced replicas the moment two devices calculate at different times.

## 5. Feature roadmap by phase

Full sprint-level breakdown lives in `docs/ROADMAP.md`. Summary:

**Phase 1 — MVP**: manual CRUD for cards/loans/income/bills, dashboard, calendar, category budgets (target vs. actual), due-date notifications.

**Phase 2 — Growth**: debt payoff calculator (snowball + avalanche, user's choice), cash-flow forecast, spending/utilization reports, CSV import, recurring-bill automation, multi-currency, PDF/Excel export.

**Phase 3 — Commercial**: subscriptions, **asset tracking** (opt-in paid tier — additive `Account` type, not a schema rework), optional Plaid bank sync (opt-in paid tier), family/shared accounts, compliance pass, app store submission.

## 6. UX principles

Drawn from current fintech UX research, deliberately weighed against Jackpot's specific context:

- **Minimalism over density.** Budgeting apps fail when every screen tries to show everything. Dashboard shows summary + urgency; detail lives one tap deeper.
- **Calm, trustworthy tone — not gamified.** Progress bars and color coding (green/amber/red) communicate status without streaks, confetti, or point systems. This matters more than usual given the app's name — "Jackpot" should read as a wink, not a signal that the app treats finances as a game.
- **Cross-device consistency.** Same visual language and data on Windows and Android — someone should be able to start reviewing bills on their phone and finish on the desktop without relearning the UI.
- **Progress visibility without pressure.** Show "$240 of $600 budgeted" plainly; avoid alarmist framing on categories that are merely tracking, not over.
- **Accessibility from the start.** Sufficient contrast on all status colors (not color alone — pair with numbers/labels), scalable text, screen-reader labels on icon-only controls.

## 7. Security & compliance

- Row Level Security on every table, enforced at the database layer — never rely on client-side filtering alone.
- Local SQLite cache encrypted at rest via SQLCipher.
- **No bank credentials stored, no aggregator integration, in Phase 1 or 2.** This is what keeps Jackpot out of PCI-adjacent compliance obligations early — a deliberate, not accidental, scope decision.
- Secrets (Supabase URL/anon key) come from `--dart-define` at build time, never hardcoded or committed.
- Before any public release — even a friends-and-family beta — write a privacy policy and terms of service.

## 8. Money handling — non-negotiable

Never use `double` for currency anywhere in the Dart codebase; floating-point rounding errors are unacceptable in a finance app. Use an integer minor-unit (cents) representation or a fixed-point decimal package for all in-app math. Postgres's `numeric(12,2)` type is exact decimal (not floating point), so it's safe as the storage type — the risk is entirely on the Dart side. Round only at display time.

## 9. Debt payoff math (Phase 2, worth deciding now)

- **Snowball**: order debts by lowest remaining balance first.
- **Avalanche**: order debts by highest APR first.
- Let the user choose — don't hardcode one as "correct."
- Monthly interest accrual on a balance: `balance × (APR / 12)`.

## 10. Monetization (Phase 3)

Freemium: free tier covers manual entry, a capped number of accounts, and the core dashboard/calendar/budget. Pro tier (subscription) unlocks bank sync, asset tracking, unlimited accounts, multi-currency, advanced reports, and family sharing. Price against Monarch Money, YNAB, and Copilot before setting a number.

## 11. Branding

App name: **Jackpot**. Tone: calm and trustworthy — see UX principles above.

## 12. Decisions log

| Decision | Status |
|---|---|
| Cross-platform via single Flutter codebase | Settled |
| Manual entry only (no bank API) at MVP | Settled |
| Cloud-synced, offline-first via PowerSync | Settled |
| Detailed category-level budgeting | Settled — core feature, not secondary |
| Asset tracking | Deferred — Phase 3 paid feature |
| iOS support | Deferred — architecture keeps the door open |
| App name | Settled — Jackpot |
