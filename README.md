# Jackpot

A personal finance app for tracking credit cards, loans, income, bills and monthly category budgets in one place. It is meant to replace the spreadsheet I used for this, and it runs on Windows and Android from a single Flutter codebase.

**Status: early development.** Sign up and login work against Supabase. The accounts screen (credit cards and loans) is specified and is the next piece of work. The rest of the roadmap is planned but not built yet, so please read this as a project in progress rather than a finished app.

## What it is aiming for

- Credit cards and loans with limits, balances, APRs and due dates.
- Income sources and recurring bills.
- A dashboard with total debt, credit utilization and upcoming payments.
- Category budgets by month, showing target against actual spending.
- A debt payoff calculator (snowball and avalanche) and cash-flow forecasting in a later phase.

Data is entered by hand. There is no bank aggregator, on purpose, for the first version.

## How it is built

| Part | Choice |
|---|---|
| Client | Flutter and Dart |
| State | Riverpod |
| Backend | Supabase (Postgres, Auth, Row Level Security) |
| Offline sync | PowerSync, mirroring Postgres into local SQLite |
| Local storage | SQLCipher under PowerSync, so the on-device cache is encrypted |
| Money | `money2`, never floating point |

A few decisions I made on purpose:

- **Offline first.** The app reads and writes a local database and syncs in the background, so it stays usable with no connection.
- **Row Level Security is the write boundary.** Every table has a policy that scopes rows to the signed-in user. PowerSync's own replication bypasses RLS, so what syncs to a device is limited separately in `powersync/sync-streams.yaml`, and both files are reviewed together.
- **Computed values are never stored.** Utilization, days until due and payoff dates are calculated when they are read, so two devices can never disagree.
- **Money is exact.** Amounts are stored as text in the local schema and parsed into a decimal type at the edge, so a float never touches a balance.

## Project layout

```
lib/
  features/auth/    sign up, login, session gate
  features/home/    accounts list (next sprint)
  data/             secure token storage
supabase/schema.sql         tables and Row Level Security policies
powersync/sync-streams.yaml what replicates to each device
docs/                       full specification and sprint roadmap
test/                       widget tests
```

More detail is in [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md), [docs/ROADMAP.md](docs/ROADMAP.md) and [SPEC.md](SPEC.md) (the Sprint 1 spec).

## Running it

You need Flutter and a Supabase project with `supabase/schema.sql` applied. Keys are passed at build time and are never committed.

```bash
flutter pub get
flutter run -d windows --dart-define-from-file=env.json
flutter test
flutter analyze
```

`env.json` holds your Supabase URL and anon key and is ignored by git.

## Author

Gianlexis Quiñones Candelaria. [LinkedIn](https://www.linkedin.com/in/gianquinones21/) · [GitHub](https://github.com/ohitsgian21)
