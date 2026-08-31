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

**Research is in flight** on the right pipeline: Blender MCP driven headlessly,
OpenUSD authored in Python (`UsdSkel` blend shapes), image-to-3D services (Tripo,
Meshy, Rodin, Hunyuan3D), programmatic Lottie generation, and whether any MCP can
author a `.riv`. The question is which of these an agent can drive end to end
versus which need a human in a GUI.

**Constraint that shaped the question:** Rive has no MCP, and `.riv` is a compiled
binary its editor produces — so it cannot be authored from a coding session. Rive
remains wired in the app (`RiveMascot`, falls back to the shader) if we later
decide a human should rig it. `docs/RIVE.md` has that path.

---

## What still works and should be kept

- **`FittiBlob`** — the Metal shader deforming the real PNG. Squash, touch-sourced
  wobble, idle breath, liquid fill. This *does* preserve the clay look, because it
  deforms the actual artwork instead of redrawing it. It is the limit meter.
- **`WelcomeSequence`** — the code-authored intro (drop, squash, blobs scatter,
  wordmark, tagline writes on, controls last). Matthew called this "smooth". Keep.
- **`docs/ANIMATION.md`** — why shaders beat sprite sheets and transparent video.

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
