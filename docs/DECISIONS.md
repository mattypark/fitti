# Decisions

Why the stack looks the way it does. Each entry records what was chosen, what it
was chosen over, and the number or constraint that settled it.

---

## Native SwiftUI, not Expo / React Native

The hardest technical requirement in the product is a clean garment cutout. On iOS
that is `VNGenerateForegroundInstanceMaskRequest` (Vision, iOS 17+) — a first-party
API that runs on the Neural Engine in roughly 100–300 ms, offline, at zero cost per
image. In React Native the same capability is a community wrapper with a single
maintainer.

The usual counter-argument for Expo is one codebase. That was never available here:
the web design language (Tailwind v4 `@theme` tokens, GSAP, Lenis, CSS hard-shadow
pops) has no `react-native-web` port, so "sharing" would have meant sharing types
and business logic — which any two projects can do.

The machine is also Swift-ready and Expo-empty: Xcode 26.6, Swift 6.3.3, iOS 26
simulator, four existing SwiftUI projects, and no `eas-cli`.

**Revisit if** Android becomes a requirement inside 12 months.

## Supabase for data and auth, not Convex

Convex has no native vector support, so it would have meant a second datastore for
embeddings and a second consistency problem. Postgres + `pgvector` puts the garment
row and its embedding one join apart.

The deciding factor is not vectors though — it is that this app stores photographs of
people's bedrooms. Postgres RLS is enforced *inside the database*, so a bug in a route
handler cannot leak another user's closet. In Convex every authorization decision is
TypeScript someone wrote. For personal-photo data that is the wrong default.

## Cloudflare R2 for images, NOT Supabase Storage

This one reversed during planning.

Supabase Storage is a fine bucket. Supabase **image transformations** are not:
billing is **$5 per 1,000 origin images per month** — per distinct source image
touched, not per transform. A 100-user closet at 300 garments each is 30,000 origin
images, which is **$150/month at 100 users** and $15,000/month at 10,000.

So: pre-generate every derivative at ingest, never transform on read, and put the
objects in R2 — where egress is **$0.00**. That last number is worth more than the
storage price delta, because it deletes an entire category of unbounded bill: one
user restoring a 6 GB library to a new phone costs $0.54 on CloudFront and nothing
on R2, and you don't control how often that happens.

| | 100 users | 1,000 users | 10,000 users |
|---|---|---|---|
| R2 + Workers | **$5.38** | **$8.70** | **$45.60** |
| Supabase Storage | $25 | $26 | ~$127–160 |
| ↳ with transforms on | +$150 | +$1,500 | +$15,000 |
| S3 + CloudFront | ~$1.50 | ~$13 | ~$130 |

Postgres still lives in Supabase. Images do not.

## Cloudflare Queues + Workers for the ingest pipeline

The consumer needs to read the uploaded master, derive four sizes, tag, embed, and
write a row. Running that in a Worker means it sits in the same network as R2 (zero
egress, ~5 ms to fetch), has no cold start so a 50-photo burst starts immediately,
gets native retries and a dead-letter queue, and uses the `IMAGES` binding instead of
shipping `sharp` in a container. R2 event notifications feed the queue directly, so
the "storage webhook" is configuration rather than an HTTP endpoint to secure.

Cost above the $5/mo Workers Paid plan: $0 at every scale modeled.

## Background removal on-device — the single largest cost decision

At 10,000 users adding 60 garments a month, server-side matting at fal.ai rates is
**~$9,000/month**. The same work via Vision on the user's phone is **$0**, and it is
faster and more private.

Cloud matting (`fal-ai/birefnet/v2`) stays wired as a fallback for web uploads and
for the case where Vision returns no instances or the user rejects the result.

This makes ML inference — not storage, not bandwidth — the thing worth optimizing,
and it is already optimized to zero for the common path.

## GRDB for the on-device queue, not SwiftData

SwiftData model classes are `@MainActor`-isolated by default. Bulk-importing several
hundred rows without a `ModelActor` marshals every insert onto the main thread, which
is exactly the freeze this app exists to avoid. GRDB gives `DatabasePool` (WAL,
non-blocking concurrent reads), works across the App Group boundary for the share
extension, and has the highest raw write throughput of the three options.

## ThumbHash, not BlurHash

BlurHash cannot represent alpha. Every image in this app is a transparent-background
cutout, so a BlurHash placeholder is a smear of whatever the matte color was and looks
nothing like the tile that replaces it. ThumbHash encodes alpha and aspect ratio,
produces sharper edges, and is ~23 bytes — small enough to live in the garment row
and paint instantly with zero network requests.

## WebP with alpha for cutouts, not AVIF or PNG

AVIF is 30–40% smaller, but encode is 5–20× slower (which matters when a worker is
chewing through a 200-photo import) and alpha-channel AVIF is the weakest corner of
AVIF support. PNG is 8–15× larger than WebP for a cutout.

WebP is canonical. The 2048 px master — which has no alpha — is AVIF. HEIC is
device-local only and is never served to the web, because Chrome, Edge, and Firefox
cannot decode it on any platform.

## Embeddings in their own table

A 1152-dim vector is ~4.6 KB. Inline on `garments` it blows past the TOAST threshold,
so every row gets TOASTed and the grid query — the hottest query in the app — pays
detoast overhead on data it never reads. Narrow rows mean ~25 per 8 KB page instead
of ~1.

A separate `garment_embeddings` table also carries a `model` column, so swapping
embedding models is a rewrite of one table rather than a churn of every user's
metadata, and `halfvec` (float16) halves storage at <1% recall cost.

## Keyset pagination, never OFFSET

`OFFSET 5000` re-scans 5,000 rows on every page — measured at 704 ms vs 41 ms for
keyset on a million-row table. It is also *wrong* under concurrent deletes: removing
a garment mid-scroll shifts every subsequent page and the user silently never sees
some items.

## Seeded catalog first, then affiliate feeds. No scraping.

Retailer product photographs are copyrighted works, and "publicly accessible" is not
a licence. `hiQ v. LinkedIn` settled that scraping public pages isn't a CFAA
violation — and hiQ then *lost* on breach of contract. Neither question touches
copyright, which is the one that actually bites.

Affiliate product feeds (Rakuten, Awin/ShareASale, Impact) grant an express, if
revocable, licence to display merchant imagery alongside a tracked link. That is the
only scalable licensed source. eBay's Browse API covers secondhand. Direct permission
from indie brands is the differentiated tail.

Stripping the affiliate link would breach the program terms *and* destroy the only
defence to a copyright claim. The link always stays.
