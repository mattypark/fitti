# Where things stand, and what's next

Handoff notes. Read this first in a new session.

---

## State: the app builds and runs

```bash
open ios/Fitti.xcodeproj    # ⌘R, iPhone 17 Pro simulator
```

There's a **Skip** button top-right on the welcome screen (DEBUG only) to get
straight into the app. Two launch arguments exist for automation, both DEBUG-only:
`-fittiSignedIn` and `-fittiTab closet|discover|outfits|you`.

**Tests: 20 Swift + 7 RLS + 36 web, all passing.**

| Stage | State |
|---|---|
| 0 Repo & logo | done |
| 1 Design system | done, 8 tests |
| 2 Database & RLS | done, 7 isolation tests, applied locally |
| 3 iOS shell & motion | done, running |
| 4 Auth & paywall | done, mock + Supabase behind a protocol |
| 5 Capture | built, not yet exercised on a device |
| 6 Ingest pipeline | done, 36 web tests |
| 7 Share sheet & bulk import | built, needs a device |
| 8 Receipt parser | done; needs a domain to receive mail |
| 9 Bulk photo split | **skipped** — needs fal credit |
| 10 Outfit engine | done, 12 Swift tests |
| 11 Feed ranking | done, 14 web tests |
| 12 Web app | landing page built; parked, app-first for now |
| 13 Catalogue adapters | not started |
| 14 Submission | checklist + `scripts/pre-submit.sh`, 13 checks passing |

---

## Fixed this session

- **The back button.** There was no back control anywhere in the app, and the AI
  consent sheet combined `interactiveDismissDisabled()` with no exit — tapping
  **+** for the first time trapped you. Every sheet now has the same back chevron
  in the same place (`SheetChrome`), and swipe-to-dismiss counts as declining.
- **Haptics.** `Haptics.shared` wraps the feedback generators and Core Haptics.
  Tab changes get selection feedback, the shutter gets the heaviest impact in the
  app, and the blob has a real two-stage `squish` pattern — a firm hit, then a
  softer rebound 110ms later, which reads as something soft compressing rather
  than as a button click. Welcome landing has its own `land` pattern.
  Generators are prepared ahead of use; an unprepared one fires late, and a late
  haptic reads as a glitch.

## Done: the visual pass

The research came back and the diagnosis was specific. Executed:

- **Ground inverted to paper** (L 0.985 / C 0.004). The hue survives as a
  temperature. All 20 tests still pass — contrast holds.
- **Cards deleted from garment tiles.** A cutout has its own silhouette; a
  rounded rect behind it is a second shape competing with the first.
- **Forced 1:1 deleted.** A coat is tall, a belt is wide. Normalising them was
  what made the grid read as algorithmic rather than curated.
- **Ambient blob dots deleted** from every screen — decoration with no
  information role.
- **Per-tile entrance animation deleted** — it fired on scroll-in, so every tile
  popped as you scrolled. One container fade now.
- **Radii tightened** — 20→12 on tiles, 32→28 on sheets.
- **Tab indicator blob removed**; selection is weight and opacity.
- **Overshoot reserved for the mascot alone.** It only reads as alive because
  nothing else in the app bounces.

### Still open from the research

| Change | Impact | Effort |
|---|---|---|
| One type family + Cosmos's scale; demote Bagel/Gloria to wordmark + speech bubble only | 9 | 1.5 half-days |
| Demote the 12 grounds to accent-only | 6 | 1 |
| Garment-native staggered grid | 8 | 2 |
| Edge-to-edge + minimizing tab bar (iOS 26) | 6 | 1.5 |
| **Design the empty / loading / error / offline states** | 7 | 2.5 |
| Alta's month-strip: the streak as a growing visual artifact you own | 8 | 4 |

The type change is the biggest remaining one. Both Alta and Cosmos ship exactly
two faces — a licensed text family plus its own mono — and **no display face at
all**. Alta's 100px hero is weight 500, not black. That restraint is most of what
"expensive" means.

## Open: the UI does not look designed yet

Matthew's verdict: *"I don't like how the entire app looks, it looks AI-coded."*
Research is in flight on this. The targets he named:

- **Alta** (altadaily.com, and the Mobbin teardown) — the direct competitor and
  the visual reference. Near-monochrome, product photography as the only colour,
  heavy condensed wordmark, dense but calm.
- **Cosmos** (cosmos.so) — "Pinterest but much more aesthetic." Copy its grid,
  spacing and restraint.
- **What makes feeds addictive** without dark patterns — Instagram, TikTok,
  YouTube, Google.

The open question the research must answer: **is the full-bleed butter yellow a
mistake?** Alta is nearly monochrome and the clothes supply all the colour. Fitti
currently paints every screen, which may be exactly the tell that reads as
AI-generated. `docs/DESIGN.md` has the whole colour system, so changing this is a
token-level change, not a rewrite.

## The next task: the welcome-screen mascot

**What Matthew asked for, precisely:** on the **welcome page only** — not the home
screen — Fitti scans through a series of outfits and reacts to each one, happy or
not. It's an attract loop that shows what the app does before you sign in.

**What was tried and rejected:** drawing the character procedurally in SwiftUI
(hand-authored silhouette + radial gradient + drawn eyes and mouth). It builds and
animates fine but **reads as a flat vector emoji, not the soft 3D clay creature the
artwork is**. Removed in `a4329ea`. Don't rebuild it that way.

The lesson: the PNG's appeal is its *rendering* — subsurface-ish shading, soft
specular, real depth. A gradient-filled vector path cannot reach that, and the gap
is obvious side by side.

**The research came back with a clear answer: use Rive, driven by its official
MCP.** That MCP exists, is already running on this Mac at `127.0.0.1:9791`, and
is registered with Claude as `rive`. Its `mesh_rigging_tool` traces a mesh to the
image silhouette, binds bones and auto-computes weights — the step previously
believed to be manual.

This is the only route that **deforms the actual approved artwork** rather than
redrawing it, which is precisely why it cannot repeat the flat-vector failure.

**Do this next:**

1. Open Rive, new file, **512×512 artboard named `Fitti`**.
2. Draw **three bones** — root at the base, a squish bone up the centre, one lobe
   bone. This is the only manual step; no MCP tool creates bones.
3. Hand the rest to Claude via the `rive` MCP — see `docs/RIVE.md` for the exact
   tool sequence.
4. Export to `ios/Fitti/Resources/fitti.riv`. `RiveMascot` already loads it and
   already sends `mood` / `level` / `poke`; add `lookX` for the gaze.

**Matthew does not want to pay for Rive.** So the Cadet seat is off the table for
now, and the alternatives are: the third-party `rive-mcp` (writes `.riv` binaries
directly, no plan needed — but 4 stars, single maintainer, validates against the
*web* runtime not `rive-ios`, so treat as a prototype-only escape hatch), or stay
on the Metal shader, which already deforms the real artwork and costs nothing.

For reference, if that changes — **$9/mo Cadet.** Rive's Free tier cannot export a `.riv` at
all — not even for a debug build. That is the one purchase this route requires.
App size is **6 MB** arm64, ~2–3 MB after thinning, so the size worry is dead.

Rejected alternatives, with reasons, are in `docs/ANIMATION.md`: Lottie can't
mesh-deform (same flat-vector failure), Blender means rebuilding a character we
already have, and a RealityKit route keeps a render loop awake for a mascot on
every screen. SceneKit is now hard-deprecated, and `Model3D` is visionOS-only.

---

## What still works and should be kept

- **`FittiBlob`** — the Metal shader deforming the real PNG. Squash, touch-sourced
  wobble, idle breath, liquid fill. This *does* preserve the clay look, because it
  deforms the actual artwork instead of redrawing it. It is the limit meter.
- **`WelcomeSequence`** — the code-authored intro (drop, squash, blobs scatter,
  wordmark, tagline writes on, controls last). Matthew called this "smooth". Keep.
- **`docs/ANIMATION.md`** — why shaders beat sprite sheets and transparent video.

---

## The figures have to stop being blobs

`OutfitFigure` draws a head, a top, a bottom and shoes as four stacked shapes in
the house jelly material. That is honest as a proportion study and it is now
rendered like everything else in the app, but it is still a placeholder standing
where the product's whole promise goes.

Two routes, and they are not exclusive:

1. **The real garments, stacked.** Once capture is producing Vision cutouts, an
   outfit is its own pieces layered on a figure — no generation, no cost, no
   latency, and it is literally your clothes. This is the honest default and it
   is gated only on stage 5 running on a physical device, since the Vision
   cutout does not work in the Simulator at all.
2. **A person wearing them, generated.** A model shot from the cutouts. Higher
   ceiling and the thing people actually screenshot, but it needs a provider, a
   budget, a consent story beyond the Gemini labelling disclosure already
   shipped, and an answer for what the body looks like — whose body, and who
   decides.

Route 1 first. Route 2 is the upgrade, not the foundation, and shipping it first
would mean the app cannot show you an outfit without spending money.

---

## Open items that need Matthew

| | Needed for |
|---|---|
| Apple Developer Program / App Store Connect | Real Sign in with Apple, StoreKit, TestFlight |
| A domain | Receipt forwarding (stage 8) — parser is done and tested |
| fal.ai credit | Stage 9 bulk photo split, and the cloud cutout fallback |
| Privacy policy URL | App Store submission |

He has said: **buy nothing** until the app works and looks right.

---

## Known rough edges

- Outfit figures on the home screen are placeholder shapes, not real cutouts.
- Discover shows mock listings; the catalogue adapters (stage 13) aren't built.
- Capture and the share extension have never run on a physical device — the
  Vision cutout does not work in the Simulator at all, so that path is unverified.
- `docs/STAGES.md` tracks the same list with more detail.

---

## Traps already hit, so they aren't hit twice

- **XcodeGen regenerates `Info.plist` and `.entitlements` from `project.yml`.**
  Hand-editing those files silently loses the changes. It cost an entitlements
  wipe and a share extension with no `NSExtension` dict, which made the whole app
  fail to install with "Invalid placeholder attributes".
- **`Font.custom` matches the PostScript name, not the filename, and falls back
  silently.** Gloria's is `GloriaHallelujah`, not `GloriaHallelujah-Regular`.
- **`UserDefaults` throws on non-property-list values.** `nil as Any` crashed
  sign-in, because Apple returns no email after the first authorization.
- **`distortionEffect` maps destination → source** — transforms inside are the
  inverse of the motion you see.
- **Shader-deformed artwork needs transparent margin** or it clips.
- The simulator runtime and Metal toolchain are separate downloads from Xcode.
