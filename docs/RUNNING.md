# Running Fitti locally

Honest status: stages 0–2 are done, so what runs today is the design system and
its tests. The iOS app and web app get scaffolded in stages 3 and 12.

## What works right now

### Design system tests

```bash
cd ios/FittiDesign
swift test
```

Verifies the colour system: that primary text clears AAA and that secondary text
and the accent clear AA against the ground, on all twelve ground colours, and
that gamut mapping never shifts a hue. 8 tests, 12 cases each where parameterised.

Needs nothing but Xcode, which you have.

### The database

Requires **Docker running** — that's the only prerequisite you're missing.

```bash
open -a Docker            # wait for the whale in the menu bar
cd /Users/matthewpark/Downloads/current-projects/appscurrent/fittie
supabase init             # once
supabase start            # prints your local URL + keys
supabase db reset         # applies supabase/migrations/*.sql
```

`supabase start` prints a URL and an anon key — paste those into `.env.local`.
Studio comes up at http://localhost:54323 for poking at tables by hand.

To verify RLS is actually doing its job (this is the test that matters):

```bash
supabase db reset && psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" \
  -c "select tablename, rowsecurity from pg_tables where schemaname='public';"
```

Every row must say `t`. A `f` means a table is readable by anyone.

## What doesn't exist yet

| | Stage | Will run with |
|---|---|---|
| iOS app | 3 | `open ios/Fitti.xcodeproj`, ⌘R |
| Web app | 12 | `cd web && npm run dev` → localhost:3000 |
| Ingest worker | 6 | `cd worker && npx wrangler dev` |

## Prerequisites, and which you already have

| | Status |
|---|---|
| Xcode 26.6, Swift 6.3.3 | installed |
| Node 22.23.1 | installed |
| Supabase CLI | installed |
| Docker | installed but **not running** |
| Apple Developer Program | needed at stage 4 for Sign in with Apple + StoreKit |
| `fitti.app` domain | needed at stage 8 for receipt forwarding |
