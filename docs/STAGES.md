# Build stages

Live checklist. Updated as each stage lands; each one is committed on completion.

- [x] **0 — Repo + logo**
  - Repo scaffolded, pushed to `mattypark/fittie`, `.gitignore` covering Xcode/Next/Supabase/Wrangler/SwiftPM
  - `ip-as-logo` skill installed; six mascot prompts written to `assets/logo/PROMPTS.md`
  - Mascot supplied by Matthew → `assets/logo/mascot.png`, exported to 12 iOS icon sizes + web favicons

- [x] **1 — Brand + design system**
  - Six color roles derived from one hue angle in OKLCH, twelve grounds
  - Gamut mapping by chroma reduction so hue never drifts
  - Type (SF Pro / Bagel Fat One / Gloria Hallelujah), spring motion set, spacing, radii
  - Mirrored in `ios/FittiDesign` and `web/src/styles/tokens.css`
  - 8 tests passing: AAA primary text, AA secondary and accent, on all twelve grounds

- [x] **2 — Supabase schema + security**
  - 14 tables: garments, assets, embeddings, outfits, wears, catalog, events, entitlements, jobs
  - RLS deny-by-default on every table, `force row level security` so even the owning role obeys
  - Free-tier ceiling enforced by database trigger, not by route handlers
  - Explicit table grants — a policy without a GRANT still yields "permission denied"
  - **Applied and verified locally**: 7 RLS isolation tests passing (`./scripts/test-db.sh`)
  - Runs on ports 54421–54429 so it never collides with other projects' stacks

- [ ] **3 — iOS shell + motion**
  - Xcode project, five tabs with the oversized centre capture button
  - 120fps enabled via `CADisableMinimumFrameDurationOnPhone`
  - Blob physics, drifting dots, mascot idle animation
  - Mock data only. **This is the stage to review the feel.**

- [ ] **4 — Auth + paywall**
  - Sign in with Apple, email magic link, Google
  - StoreKit 2 subscription; 25-garment ceiling verified server-side
  - Limit meter blob that tightens as it fills

- [ ] **5 — Capture core**
  - Rapid-fire camera, zero forms
  - On-device Vision cutout, aesthetics gate, on-device quick tags
  - GRDB job queue + background upload that survives app termination

- [ ] **6 — Server ingest pipeline**
  - EXIF/GPS strip → moderation → attribute extraction → color naming → embedding
  - Cloudflare Queue consumer, retries, dead-letter, per-user spend ceiling

- [ ] **7 — Share extension + library import**
  - App Group container, enqueue-only extension (120MB limit means never decode)
  - `PHPickerViewController` bulk import with ImageIO downsampling

- [ ] **8 — Email receipt import**
  - Per-user inbound address, VLM parse, product image fetch, dedupe

- [ ] **9 — Bulk photo split**
  - SAM 3 with a mandatory review grid. Never auto-commits.

- [ ] **10 — Closet + Outfits**
  - Grid, filters, detail sheet, wear tracking
  - Outfit engine: SQL filter → colour/pattern/novelty ranking → LLM pass with the reason

- [ ] **11 — Discover feed**
  - Seeded catalog, five retrieval pools, MMR diversity, fixed explore slots
  - Full event logging, press-and-hold worn-photo peek

- [ ] **12 — Web app**
  - Landing page, auth, read-only closet

- [ ] **13 — Catalog adapters**
  - Affiliate feed ingestion behind one adapter interface, VLM caption enrichment

- [ ] **14 — Hardening + submission**
  - Privacy manifest, usage strings, account deletion, TestFlight
