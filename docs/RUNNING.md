# Running Fitti locally

Honest status: stages 0–2 are done, so what runs today is the design system and
the database. The iOS app and web app get scaffolded in stages 3 and 12.

**Fitti runs on its own ports** (`54421`–`54429`) so it never collides with the
Supabase stacks of your other projects. `rit-web` holds the default `5432x`
range; both can be up at once.

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
supabase start            # already init'd; prints your local URL + keys
supabase db reset         # applies supabase/migrations/*.sql
```

- API → http://127.0.0.1:54421
- Studio → http://127.0.0.1:54423
- Postgres → `postgresql://postgres:postgres@127.0.0.1:54422/postgres`
- Mail catcher → http://127.0.0.1:54424

`supabase start` prints the anon and service-role keys; paste them into `.env.local`.

### The test that actually matters

```bash
./scripts/test-db.sh
```

Seven checks, run inside the database: a user sees only their own garments;
looking one up by primary key still returns nothing; an insert with a forged
`user_id` is rejected; update and delete of someone else's row touch zero rows;
entitlements are readable but not self-grantable; the 25-garment ceiling is
enforced by trigger; and every public table has RLS on.

It runs in a transaction that rolls back, so it never leaves test data behind.

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
