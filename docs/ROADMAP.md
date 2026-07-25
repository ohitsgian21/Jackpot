# Jackpot — roadmap & how we'll work with Claude Code

## The workflow, not just the task list

This is based on Anthropic's own published guidance for working with Claude Code effectively, adapted to a solo-developer project. The pattern that matters most:

**Explore → Plan → Implement → Verify → Commit.** Don't let Claude jump straight from a request to code. For anything that touches more than one feature or the database schema, start a session in plan mode: let Claude read the relevant files and ask questions first, review the plan it proposes (edit it directly if needed), *then* switch to implementation. Skip this ceremony for genuinely small changes — a one-line fix doesn't need a plan.

**Spec first, for anything non-trivial.** Before starting a real feature (a full sprint item below, not a bug fix), open with something like: *"I want to build [feature]. Interview me using AskUserQuestion — ask about implementation, edge cases, and UI/UX I might not have considered. Write the result to SPEC.md."* Then start a **fresh session** to implement from that spec. The fresh session has clean context focused only on building, and you have a written reference instead of relying on scrollback.

**Always give Claude something to verify against.** "Looks done" isn't a real signal. Before starting a feature, decide what proves it works: a widget test, `flutter analyze` passing clean, a specific manual check ("balances update correctly after editing a card"), or — for UI work — a screenshot compared against the mockup. Ask Claude to run the check and iterate against it in the same session rather than asserting success.

**Manage context deliberately.** Run `/clear` between unrelated tasks — don't let a budgeting-feature session drift into fixing an unrelated calendar bug. For broad investigation ("how should recurring bills interact with the calendar?"), ask Claude to use a subagent so the exploration doesn't fill your main context window. If you correct the same mistake twice in one session, that's the signal to `/clear` and restate the prompt with what you learned, rather than continuing to correct in place.

**Commit at the level of a working slice**, not at the end of a multi-feature session. Small, reviewable commits make it easy to roll back one bad decision without losing the rest of the session's work.

## Phase 0 — Setup (week 1)

- [ ] `flutter create jackpot --platforms=windows,android`
- [ ] Create the Supabase project; run `supabase/schema.sql`; manually verify RLS by querying as two different test users and confirming neither sees the other's rows
- [ ] Set up PowerSync, connect it to the Supabase project per their integration guide
- [ ] Wire Supabase Auth — signup/login screen, session persistence
- [ ] Drop `CLAUDE.md`, `docs/PROJECT_PLAN.md`, `docs/ROADMAP.md`, and `supabase/schema.sql` into the repo before the first real Claude Code session
- [ ] Once real code exists, run `/init` in Claude Code — it reads the actual generated project and proposes refinements to `CLAUDE.md` (it won't overwrite the hand-written one, only suggest additions)
- [ ] **Verify**: app builds and launches on both Windows and an Android emulator; a signup/login round-trips against Supabase

## Phase 1 — MVP (weeks 2–7)

| Sprint | Scope | Verify |
|---|---|---|
| 1 | Accounts — CRUD for credit cards and loans (data layer, repository, forms) | Widget tests for validation; a card/loan created in the UI appears correctly in Supabase |
| 2 | Income + bills — CRUD, basic recurrence | Recurring bill instances generate correctly for a test month |
| 3 | Dashboard — net cash flow, total debt, utilization, upcoming payments | Matches the mockup already built; numbers computed correctly against seed data |
| 4 | Calendar — every due date plotted | All seeded due dates appear on the correct day |
| 5 | Budgets — category budgets, target vs. actual, monthly rollover toggle | Unit tests on the budget-remaining calculation, including rollover on/off |
| 6 | Notifications — local + push reminders for due dates | Reminder fires at the configured offset in a manual test |
| 7 | Polish + private beta | Dark/light theme, empty states, error handling reviewed manually; you use it daily instead of the spreadsheet |

## Phase 2 — Growth (months 3–4)

- Debt payoff calculator (snowball + avalanche, user's choice)
- Cash-flow forecast / timeline
- Reports: spending by category, utilization history
- CSV import for bank/card exports
- Recurring-bill automation
- Multi-currency support
- Export to PDF/Excel

## Phase 3 — Commercial (months 5–6+)

- Subscriptions (Stripe + Google Play Billing)
- Asset tracking (opt-in paid tier)
- Optional Plaid bank sync (opt-in paid tier)
- Family/shared accounts
- Compliance pass: privacy policy, ToS, security review
- App store submission (Google Play + Microsoft Store)

## Definition of done, every item

Before marking anything complete: it has an explicit verification step (test, build, or documented manual check), it's committed with a descriptive message, and — for anything beyond a small fix — it started from a short spec rather than an ad hoc prompt.
