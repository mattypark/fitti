# The design system

Written from the Swift, which is the only source of truth. `ios/FittiDesign` is a
local SPM package with no dependencies, so every token below is testable on macOS
without a simulator: `cd ios/FittiDesign && swift test`.

---

## Colour

### One ground, twelve accents

The app is butter for everybody. The personal hue — assigned at signup, overridable
in You — survives as the **accent alone**: a selected swatch, an active tab, a price.

This replaced a system where the ground itself was personal. That version had a real
argument behind it (simultaneous contrast shifts the perceived hue of anything on a
coloured field, and butter at H 85 sits near the opposite of where garments actually
cluster, H 220–255 — every navy, blue and denim) and it was answered by taking the
ground to L 0.985 / C 0.004. Paper.

The result was that all twelve grounds rendered within about five RGB points of
`#FAFAFA` and the brand left the screen entirely. The launch screen still opened on
butter and then flashed to white.

The answer is scarcity, not neutrality: one warm ground, and the two screens where
garment colour genuinely has to be judged opt out by hand. **Discover** runs on
`Fixed.paper` and **Capture** on `Fixed.ink`.

### The six roles

Five are pinned to the brand hue. Only `accent` rotates.

| Role | L | C | Hue | Renders |
|---|---|---|---|---|
| `ground` | 0.900 | 0.075 | 85 | `#F5DBA5` |
| `groundSunk` | 0.855 | 0.075 | 85 | `#E6CC97` |
| `groundLift` | 0.945 | 0.055 | 85 | `#FEEBC4` |
| `onGround` | 0.180 | 0.012 | 85 | `#14110C` |
| `onGroundSoft` | 0.460 | 0.010 | 85 | `#5B5852` |
| `accent` | 0.460 | 0.170 | **hue − 40** | per user |

`onGroundFaint` is `onGround` at 0.38 opacity — never a different colour, because
opacity composites correctly over the ground, over a lifted sheet and over a garment
photograph, where a fixed grey goes muddy on one and vanishes on another.

### Measured contrast

| Pair | Ratio |
|---|---|
| `onGround` on `ground` | **13.93:1** |
| `onGround` on `groundLift` | 16.00:1 |
| `onGround` on `groundSunk` | 12.07:1 |
| `onGroundSoft` on `ground` | 5.28:1 |
| `onGroundSoft` on `groundSunk` | 4.57:1 — the tightest pair in the system |
| `accent` on `ground` | 4.99:1 worst (teal) → 5.82:1 best (terracotta) |
| `accent` on `groundLift` | 5.73:1 worst |

### Why the accent is −40°, not +25°

At +25 butter's accent lands on 110°, which gamut-maps to a muddy olive `#6D6E00`
that loses to the very ground it is supposed to jump off, and fails AA at 3.92:1.

At −40 butter's accent is a burnt orange near `#913900` — the crimson-against-yellow
the sneaker reference always described — and the worst case across all twelve rises
to 4.99:1. A 180° complement was tried and reads as a second brand colour rather
than as emphasis.

### The twelve

butter 85 (default) · amber 55 · terracotta 30 · rose 15 · blush 350 · orchid 320 ·
violet 285 · blue 255 · sky 220 · teal 195 · jade 160 · moss 130

Assigned randomly at signup by `handle_new_user()`, persisted locally in
`GroundStore`, overridable in You. The enum is still called `Ground` because the
value is stored as `profiles.ground` and the raw strings are that column's check
constraint.

### Fixed

| | |
|---|---|
| `ink` | `rgb(0.055, 0.055, 0.047)` — the mascot's marks, the app icon, Capture |
| `paper` | `rgb(0.984, 0.980, 0.965)` — Discover, a white gallery |
| `yellow` | `#EFC53F` — the brand mark, the shutter, the liquid meter |
| `yellowPigment` | the same yellow as `OKLCH(0.838, 0.152, 91)` |

`yellowPigment` exists because `JellyBlob` builds its ramp by moving lightness, and
that only holds the colour if the hue is stated. Darkening an sRGB triple drags it
toward orange.

### Gamut mapping

`OKLCH.gamutMapped()` is a 20-iteration binary search on **chroma alone**. Lightness
and hue come out exactly as requested. Naive RGB clamping shifts hue — a clipped teal
drifts green — which would break the premise that the twelve are evenly spaced.

---

## The material

Every coloured form in Fitti is a blob of the same stuff, lit by one key light from
the upper left. `JellyBlob` wraps any `Shape`:

1. **Subsurface ramp** — light gathers at the crown (L +0.13, chroma ×0.82) and pools
   darker at the base (L −0.12, chroma ×1.08). The deep end gains chroma because that
   is what translucent material does: the light that survives the longest path through
   it is the most saturated.
2. **Specular** — an elliptical highlight at `(0.33, 0.20)`, soft-edged. A hard edge
   reads as a sticker; this reads as a wet surface catching a window.
3. **Rim** — a diagonal stroke, bright top-left where the key grazes it and bright
   again bottom-right where the ground bounces back up, **clipped to the silhouette**.
   An unclipped stroke straddles the path and its outer half reads as a drawn outline.
4. **Glow** — a coloured shadow beneath, so the blob sits *in* the scene rather than
   on it.

All gradients and one shadow. Never `.blur()` on the shape — these live in scroll
views on an animated path, where a blur costs a full offscreen pass per frame.

`LiquidBlob` adds the breath: a `TimelineView` at 30fps driving `BlobShape.phase` at
0.055 cycles/second, offset per seed so no two blobs pulse in step. The clock is **per
blob, not per screen** — one wrapped around the grid would invalidate packing and
columns sixty times a second, where one around a tile invalidates only that tile, and
a tile scrolled out of a lazy stack does not tick at all. It pauses on background and
on Reduce Motion.

`jellySurface(_:base:glow:)` puts the same material behind a control, so a primary
button is made of the app rather than pasted onto it.

The room gets the same key light: a soft elliptical bloom at `(0.18, 0.04)` in
`softLight` over the ground, and a top-edge sheen on the tab bar.

---

## Type

SF Pro carries all text. Bagel Fat One appears exactly once. Gloria Hallelujah is a
human voice — Fitti's or yours — and never chrome.

Both Alta and Cosmos ship one licensed text family and no display face at all; Alta's
100px hero is weight 500, not black. That restraint is most of what "expensive" means,
and a display face carrying section headers across five screens is what does not.

| Style | Face | Text style | Weight | Tracking |
|---|---|---|---|---|
| `fittiDisplay` | Bagel Fat One 34 | `.largeTitle` | — | −0.5 |
| `fittiTitle` | SF Pro | `.title` (28) | medium | −0.2 |
| `fittiHeadline` | SF Pro | `.headline` (17) | medium | 0 |
| `fittiBody` | SF Pro | `.body` (17) | regular | 0 |
| `fittiCallout` | SF Pro | `.subheadline` (15) | regular | 0 |
| `fittiFootnote` | SF Pro | `.footnote` (13) | regular | 0 |
| `fittiLabel` | SF Pro | `.caption` (12) | medium | +0.8 upper |
| `fittiFine` | SF Pro | `.caption2` (11) | regular | 0 |
| `fittiHand` | Gloria Hallelujah 16 | `.callout` | — | 0 |

Everything is a Dynamic Type style, so the app scales with the system setting. Use
`fittiDisplayStyle()`, `fittiTitleStyle()` and `fittiLabelStyle()` rather than `.font`
directly — the tracking lives in the modifier.

**Gloria's rule:** a human voice. The welcome tagline, Fitti's line in an empty state,
your own note on an outfit. Not instructions, not weather chrome, not labels.

The only remaining raw `Font.system(size:)` calls are SF Symbols, which are sized
rather than typeset.

Both `.ttf` files ship bundled under the OFL and are registered in **two** places that
must stay in sync: `ios/project.yml` and `ios/Fitti/Info.plist`. Gloria's PostScript
name is `GloriaHallelujah`, not `GloriaHallelujah-Regular`, and `Font.custom` falls
back to the system font silently on a mismatch.

---

## Space, radius, motion

```
Space   xxs 4 · xs 8 · sm 12 · md 16 · gutter 20 · lg 24 · xl 32 · xxl 48
Radius  sm 8 · tile 12 · pill 999
```

The closet is a **two-column waterfall** (`StaggeredGrid`), not a `LazyVGrid`. Grid
rows align to the tallest cell, so a belt beside a coat left a band of dead space —
and evenly-gapped ragged whitespace is a large part of what makes a grid read as
generated. Each item drops into whichever column is currently shortest, packed on the
declared aspect ratios with no measurement pass. A garment's shape lives on
`MockGarment.tileAspectRatio` because the grid must know it before it lays anything
out.

Two columns, not three: three at iPhone width turns a wall of clothes into a
spreadsheet.

```
Motion  blob   0.55 / 0.62   the mascot, and nothing else
        snappy 0.32 / 0.86   buttons, toggles, chips
        settle 0.45 / 1.00   sheets and navigation, critically damped
```

Every animation is a spring, because a spring interrupted mid-flight continues from
its current velocity and a curve restarts — and this app is built to be tapped fast.
Requires `CADisableMinimumFrameDurationOnPhone` in Info.plist, without which ProMotion
caps at 60fps and every spring looks like a cheaper version of itself.

`Motion.blob` visibly overshoots and is reserved for the mascot. Overshoot on ordinary
chrome reads dated; it only reads as alive because nothing else in the app does it.
`Motion.respecting(_:reduceMotion:)` collapses to a 0.12s crossfade rather than to
nothing — a control that answers a tap with silence feels broken.

No drop shadows as depth. Depth is the ground/sunk/lift lightness triplet, plus each
blob's own glow.

---

## The four states

`StateView` draws empty, loading, failed and offline: Fitti, one line in his voice,
and at most one way out. Loading raises the mascot's wobble rather than adding a
`ProgressView` — he is already a per-frame shader, and a spinner beside him is a
second, duller animation competing for the same attention. Offline is real
(`NWPathMonitor` behind `Reachability`), and only Discover needs it, because it is the
only screen whose content comes from outside.

Copy never says "Error".
