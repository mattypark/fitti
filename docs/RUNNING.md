# Running Fitti locally

Honest status: **the iOS app builds and runs.** Open `ios/Fitti.xcodeproj` and ⌘R on
an iPhone 17 Pro simulator. There is a DEBUG-only **Skip** button on the welcome
screen to get straight in. The web app is a landing page and is parked.

**Fitti runs on its own ports** (`54421`–`54429`) so it never collides with the
Supabase stacks of your other projects. `rit-web` holds the default `5432x`
range; both can be up at once.

## What works right now

### Design system tests

```bash
cd ios/FittiDesign
swift test
```

Verifies the colour system: primary text clears AAA on the butter ground, secondary
clears AA on all three surfaces, the accent clears AA on all twelve, gamut mapping
never shifts a hue, and the ground is asserted *warm* so a future inversion to
near-white fails here instead of shipping. 10 tests, 46 executed cases.

**This is the only way to run them.** `xcodebuild test -scheme Fitti` runs **zero**
tests — the scheme's `<Testables>` block is empty and the Xcode project has no test
target, so it compiles everything and asserts nothing.

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

### The iOS app

```bash
cd ios
xcodegen generate     # only after editing project.yml
xcodebuild build -project Fitti.xcodeproj -scheme Fitti -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The built product goes to **DerivedData**, not `ios/build/`. That directory holds a
stale husk containing nothing but a `PrivacyInfo.xcprivacy`, and installing it fails
with "Missing bundle ID" — which looks like a working install if you are not reading
the output. Find the real path with:

```bash
xcodebuild -project Fitti.xcodeproj -scheme Fitti -showBuildSettings \
  | grep BUILT_PRODUCTS_DIR
```

DEBUG launch arguments, for screenshots and UI runs:

```bash
xcrun simctl launch booted com.matthewpark.fitti -fittiSignedIn -fittiTab closet
xcrun simctl io booted screenshot closet.png
```

`-fittiSignedIn` · `-fittiTab closet|discover|outfits|you` · `-fittiEmpty`

`ios/Fitti/Secrets.xcconfig` is gitignored and absent, so `SUPABASE_URL` and
`SUPABASE_ANON_KEY` resolve empty and the app falls back to the local mock. That is a
working state, by design, rather than a broken one.

### The web tests

```bash
cd web && npm run verify      # lint + tsc --noEmit + 36 tests
```

## What doesn't exist yet

| | Stage | Will run with |
|---|---|---|
| Ingest worker | 6 | `cd worker && npx wrangler dev` |
| Catalogue adapters | 13 | not started |

## Prerequisites, and which you already have

| | Status |
|---|---|
| Xcode 26.6, Swift 6.3.3 | installed |
| Node 22.23.1 | installed |
| Supabase CLI | installed |
| Docker | installed but **not running** |
| Apple Developer Program | needed at stage 4 for Sign in with Apple + StoreKit |
| `fitti.app` domain | needed at stage 8 for receipt forwarding |
| fal.ai credit | needed at stage 9, and for the cloud cutout fallback |

There is **no CI**. Every check above is manual.
