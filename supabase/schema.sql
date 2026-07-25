-- Jackpot — initial Supabase schema
-- Run this in the Supabase SQL editor (or via `supabase db push`) before starting Phase 0.
-- Every table has Row Level Security enabled with no exceptions — see CLAUDE.md.
--
-- Money columns use numeric(12,2): exact decimal in Postgres, not floating point.
-- The risk of rounding error is in the Dart client, not here — never deserialize these
-- into a Dart `double`; use an integer-cents or fixed-point decimal type instead.

create extension if not exists "pgcrypto";

-- ── accounts ────────────────────────────────────────────────────────────────
-- Parent record for anything tracked: credit card, loan, bank account, cash.
-- Adding a new type later (e.g. 'investment' for Phase 3 asset tracking) is
-- additive — it does not require restructuring this table.
create table accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  type text not null check (type in ('credit_card', 'loan', 'bank_account', 'cash')),
  name text not null,
  institution text,
  created_at timestamptz not null default now()
);

create table credit_card_details (
  account_id uuid primary key references accounts(id) on delete cascade,
  credit_limit numeric(12,2) not null,
  current_balance numeric(12,2) not null default 0,
  apr numeric(5,2),
  statement_date date,
  due_date date,
  minimum_payment numeric(12,2)
);

create table loan_details (
  account_id uuid primary key references accounts(id) on delete cascade,
  original_principal numeric(12,2) not null,
  remaining_balance numeric(12,2) not null,
  interest_rate numeric(5,2),
  term_months integer,
  monthly_payment numeric(12,2),
  due_date date,
  start_date date
);

-- ── income ──────────────────────────────────────────────────────────────────
create table income_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  name text not null,
  amount numeric(12,2) not null,
  frequency text not null check (frequency in ('weekly', 'biweekly', 'monthly', 'custom')),
  next_expected_date date
);

-- ── categories ──────────────────────────────────────────────────────────────
create table categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  name text not null,
  type text not null check (type in ('income', 'expense')),
  color text,
  icon text
);

-- ── bills ───────────────────────────────────────────────────────────────────
create table bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  category_id uuid references categories(id),
  name text not null,
  amount numeric(12,2) not null,
  due_date date not null,
  recurrence_rule text,
  autopay boolean not null default false,
  status text not null default 'upcoming' check (status in ('paid', 'unpaid', 'upcoming'))
);

-- ── budgets ─────────────────────────────────────────────────────────────────
-- Category x month x target. This is the core feature — not a single total.
create table budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  category_id uuid references categories(id) not null,
  month date not null, -- store as the first of the month, e.g. 2026-08-01
  target_amount numeric(12,2) not null,
  rollover boolean not null default false,
  unique (user_id, category_id, month)
);

-- ── row level security ─────────────────────────────────────────────────────
alter table accounts enable row level security;
alter table credit_card_details enable row level security;
alter table loan_details enable row level security;
alter table income_sources enable row level security;
alter table categories enable row level security;
alter table bills enable row level security;
alter table budgets enable row level security;

create policy "own accounts" on accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own card details" on credit_card_details
  for all using (
    exists (select 1 from accounts a where a.id = credit_card_details.account_id and a.user_id = auth.uid())
  )
  with check (
    exists (select 1 from accounts a where a.id = credit_card_details.account_id and a.user_id = auth.uid())
  );

create policy "own loan details" on loan_details
  for all using (
    exists (select 1 from accounts a where a.id = loan_details.account_id and a.user_id = auth.uid())
  )
  with check (
    exists (select 1 from accounts a where a.id = loan_details.account_id and a.user_id = auth.uid())
  );

create policy "own income sources" on income_sources
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own categories" on categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own bills" on bills
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own budgets" on budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
