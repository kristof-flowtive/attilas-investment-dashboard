# Investment Dashboard

## Overview
Static investment dashboards (single-file HTML, Chart.js 4.x, no build tools) that load their data from Supabase at page load. Two dashboards:

- `attila-dashboard.html` — Attila, HUF (Hungarian Forint)
- `heather-dashboard.html` — Heather, GBP

(There is deliberately no `index.html` — it was a duplicate of Attila's page and was removed in July 2026.)

## Data Layer — Supabase (source of truth)
Project **investment-dashboard**, ref `kjcjrvjghozpbzwkkmzi`, URL `https://kjcjrvjghozpbzwkkmzi.supabase.co`. Schema lives in `supabase/migrations/20260711000000_investment_dashboards.sql`. Tables (RLS: public read-only via anon key; writes need the Management API or dashboard):

- **`dashboards`** — `slug` (`attila` / `heather`), `display_name`, `currency` (`HUF` / `GBP`), `header_date` (display string, e.g. `"May 2026"`)
- **`funds`** — per dashboard, `code` (`A` / `B`), `badge`, `name`, `strategy`, `initial_capital`, `fixed_coupon_rate`
  - `fixed_coupon` — monthly coupon at `fixed_coupon_rate`, per-month `action` (`Reinvested` / `Paid Out`)
  - `variable_pct` — monthly `return_pct` (Attila's Option B)
  - `variable_gain` — monthly absolute `gain_amount` (Heather's Fund B)
- **`monthly_entries`** — `fund_id`, `month` (date, first of month), `action`, `deposit`, `return_pct`, `gain_amount`; unique on (`fund_id`, `month`)

Each HTML file has a `loadData()` at the top of its `<script>` that fetches `dashboards?slug=eq.<slug>&select=...funds(...monthly_entries(...))` via PostgREST with the anon key (hardcoded in the file), maps rows into the legacy `OPTION_A`/`OPTION_B` (or `FUND_A`/`FUND_B`) shape, then calls `render()`. Balances/coupons are still computed client-side.

### Adding Monthly Data
Insert into `monthly_entries` and update `header_date` — no HTML edits needed. Run SQL via the Management API (`POST https://api.supabase.com/v1/projects/kjcjrvjghozpbzwkkmzi/database/query`, needs a personal access token from the user) or the Supabase dashboard SQL editor:

```sql
-- Attila Option A (coupon month, optional deposit)
insert into monthly_entries (fund_id, month, action, deposit)
select f.id, '2026-06-01', 'Reinvested', null
from funds f join dashboards d on d.id = f.dashboard_id
where d.slug = 'attila' and f.code = 'A';

-- Attila Option B (return %, optional deposit)
insert into monthly_entries (fund_id, month, return_pct, deposit)
select f.id, '2026-06-01', 3.5, null
from funds f join dashboards d on d.id = f.dashboard_id
where d.slug = 'attila' and f.code = 'B';

-- Heather Fund A / Fund B analogous (Fund B uses gain_amount in £)

update dashboards set header_date = 'June 2026' where slug = 'attila';
```

### Rendering Pipeline
1. `loadData()` — fetches dashboard + funds + entries from Supabase, fills config objects
2. `buildOptionA()` / `buildFundA()` — calculates coupons, compounds if reinvested, applies deposits
3. `buildOptionB()` / `buildFundB()` — applies return % (Attila) or absolute gains (Heather)
4. `render()` — header date, summary cards, detail cards, tables, then `renderCharts()`
5. `renderCharts()` — three Chart.js line charts (A, B, Combined)

On fetch failure the header shows "Failed to load data — …" (check the browser console).

## UI Sections
- **Summary cards** — total invested, current value, total P&L, coupons earned
- **Option/Fund A section** — details grid, line chart, monthly returns table
- **Option/Fund B section** — details grid, line chart, monthly returns table
- **Combined chart** — overlaid portfolio value over time

## Styling
- Dark theme: background `#0f1117`, cards `#161822`
- Color coding: `.positive` green `#4ade80`, `.negative` red `#f87171`
- Option A accent: purple `#6c63ff`
- Option B accent: amber `#f59e0b`
- Combined chart: green `#4ade80`
- Responsive grid layout, mobile breakpoint at 600px

## Currency
Attila displays HUF via `formatHUF()` (`hu-HU` locale, e.g. "1 800 000 Ft"); Heather displays GBP via `formatGBP()` (`en-GB`, e.g. "£2,000"). Currency formatting is per-file, not driven by the `currency` column.

## Common Tasks

### Create a new dashboard for a different person
1. Copy `attila-dashboard.html` (or Heather's for absolute-gain funds)
2. Change `<h1>`, `<title>`, fund badges/names in the HTML
3. Insert a new `dashboards` row + `funds` rows in Supabase
4. Set `DASHBOARD_SLUG` in the script to the new slug

### Change the investment structure
- Coupon rate: update `funds.fixed_coupon_rate` in Supabase
- Fund names/labels: edit the HTML `<section>` blocks (display names in `funds` are not currently read by the pages)
- Third option: duplicate a fund section, add a `funds` row with a new code, extend `loadData()` and `render()`

### Verification
`node verify-dashboards.mjs` (see scratchpad/session history) executed each page's script against live Supabase with a stubbed DOM and compared computed balances with the pre-migration figures.
