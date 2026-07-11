-- Investment Dashboards: schema + historical seed data
-- Dashboards: Attila (HUF), Heather (GBP)

create table if not exists dashboards (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  display_name text not null,
  currency text not null check (currency in ('HUF', 'GBP')),
  header_date text,
  created_at timestamptz not null default now()
);

create table if not exists funds (
  id uuid primary key default gen_random_uuid(),
  dashboard_id uuid not null references dashboards(id) on delete cascade,
  code text not null check (code in ('A', 'B')),
  badge text not null,          -- e.g. 'Option A', 'Fund B'
  name text not null,           -- section heading, e.g. 'Capital Protected Fixed Coupon'
  -- fixed_coupon: monthly coupon at fixed_coupon_rate, action per month
  -- variable_pct: monthly return recorded as a percentage (return_pct)
  -- variable_gain: monthly return recorded as an absolute amount (gain_amount)
  strategy text not null check (strategy in ('fixed_coupon', 'variable_pct', 'variable_gain')),
  initial_capital numeric not null,
  fixed_coupon_rate numeric,    -- % per month, only for fixed_coupon
  unique (dashboard_id, code)
);

create table if not exists monthly_entries (
  id uuid primary key default gen_random_uuid(),
  fund_id uuid not null references funds(id) on delete cascade,
  month date not null,          -- first day of the month
  action text check (action in ('Reinvested', 'Paid Out')),
  deposit numeric,              -- additional capital deposited that month
  return_pct numeric,           -- variable_pct funds
  gain_amount numeric,          -- variable_gain funds
  created_at timestamptz not null default now(),
  unique (fund_id, month)
);

create index if not exists monthly_entries_fund_month_idx on monthly_entries (fund_id, month);

-- Read-only public access (dashboards are static pages using the anon key)
alter table dashboards enable row level security;
alter table funds enable row level security;
alter table monthly_entries enable row level security;

drop policy if exists "public read dashboards" on dashboards;
create policy "public read dashboards" on dashboards for select using (true);
drop policy if exists "public read funds" on funds;
create policy "public read funds" on funds for select using (true);
drop policy if exists "public read monthly_entries" on monthly_entries;
create policy "public read monthly_entries" on monthly_entries for select using (true);

-- ============================================================
-- Seed: Attila (HUF)
-- ============================================================
with d as (
  insert into dashboards (slug, display_name, currency, header_date)
  values ('attila', 'Attila''s Investment Dashboard', 'HUF', 'May 2026')
  on conflict (slug) do update set display_name = excluded.display_name
  returning id
),
fa as (
  insert into funds (dashboard_id, code, badge, name, strategy, initial_capital, fixed_coupon_rate)
  select id, 'A', 'Option A', 'Capital Protected Fixed Coupon', 'fixed_coupon', 1800000, 2.2 from d
  on conflict (dashboard_id, code) do update set name = excluded.name
  returning id
),
fb as (
  insert into funds (dashboard_id, code, badge, name, strategy, initial_capital)
  select id, 'B', 'Option B', 'Variable High-Risk Strategy', 'variable_pct', 500000 from d
  on conflict (dashboard_id, code) do update set name = excluded.name
  returning id
),
ea as (
  insert into monthly_entries (fund_id, month, action, deposit)
  select fa.id, v.month, v.action, v.deposit
  from fa, (values
    ('2026-03-01'::date, 'Reinvested', null::numeric),
    ('2026-04-01'::date, 'Reinvested', 1680000::numeric),
    ('2026-05-01'::date, 'Reinvested', null::numeric)
  ) as v(month, action, deposit)
  on conflict (fund_id, month) do nothing
)
insert into monthly_entries (fund_id, month, return_pct, deposit)
select fb.id, v.month, v.return_pct, v.deposit
from fb, (values
  ('2026-03-01'::date, 7.2::numeric, null::numeric),
  ('2026-04-01'::date, 5.4::numeric, 500000::numeric),
  ('2026-05-01'::date, 1.2::numeric, 300000::numeric)
) as v(month, return_pct, deposit)
on conflict (fund_id, month) do nothing;

-- ============================================================
-- Seed: Heather (GBP)
-- ============================================================
with d as (
  insert into dashboards (slug, display_name, currency, header_date)
  values ('heather', 'Heather''s Investment Dashboard', 'GBP', 'June 2026')
  on conflict (slug) do update set display_name = excluded.display_name
  returning id
),
fa as (
  insert into funds (dashboard_id, code, badge, name, strategy, initial_capital, fixed_coupon_rate)
  select id, 'A', 'Fund A', 'Stable 2.5% per Month', 'fixed_coupon', 2000, 2.5 from d
  on conflict (dashboard_id, code) do update set name = excluded.name
  returning id
),
fb as (
  insert into funds (dashboard_id, code, badge, name, strategy, initial_capital)
  select id, 'B', 'Fund B', 'Floating Return', 'variable_gain', 6000 from d
  on conflict (dashboard_id, code) do update set name = excluded.name
  returning id
),
ea as (
  insert into monthly_entries (fund_id, month, action)
  select fa.id, v.month, 'Reinvested'
  from fa, (values
    ('2025-05-01'::date), ('2025-06-01'::date), ('2025-07-01'::date),
    ('2025-08-01'::date), ('2025-09-01'::date), ('2025-10-01'::date),
    ('2025-11-01'::date), ('2025-12-01'::date), ('2026-01-01'::date),
    ('2026-02-01'::date), ('2026-03-01'::date), ('2026-04-01'::date),
    ('2026-05-01'::date)
  ) as v(month)
  on conflict (fund_id, month) do nothing
)
insert into monthly_entries (fund_id, month, gain_amount)
select fb.id, v.month, v.gain
from fb, (values
  ('2025-05-01'::date, 672::numeric),
  ('2025-06-01'::date, 642::numeric),
  ('2025-07-01'::date, 220::numeric),
  ('2025-08-01'::date, 297::numeric),
  ('2025-09-01'::date, 341::numeric),
  ('2025-10-01'::date, 217::numeric),
  ('2025-11-01'::date, 312::numeric),
  ('2025-12-01'::date, 0::numeric),
  ('2026-01-01'::date, 148::numeric),
  ('2026-02-01'::date, 274::numeric),
  ('2026-03-01'::date, 0::numeric),
  ('2026-04-01'::date, 219::numeric),
  ('2026-05-01'::date, 117::numeric)
) as v(month, gain)
on conflict (fund_id, month) do nothing;
