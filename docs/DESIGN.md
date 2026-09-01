# Fitti design system

Black, white, and yellow — with the whole screen taking a color.

---

## The idea

**Paper, not pigment.** The screen is near-white with a trace of the user's hue —
a temperature rather than a colour — and the clothes supply everything else.

This replaced a full-bleed saturated field on every screen, and the reason is
functional rather than aesthetic. Simultaneous contrast shifts the perceived hue
of anything sitting on a coloured ground. Butter sits at H≈85; garments cluster
at H≈220–255 — every navy, blue and denim. The old field maximised perceptual
error exactly where the wardrobe lives, which is a colour-judgement bug in an app
whose one irreplaceable job is colour judgement. It also made the pale matting
halo on every cutout visible, where paper hides it.

Yellow survives, but as a **mark rather than a field**: the app icon, the launch
screen, the capture button, the mascot. Scarcity is what makes a brand colour
read as branding.

Historical note — the original intent was: Text is a deep tone of that
same hue, not black. This comes straight from the sneaker reference: a full butter-yellow
field, brown type, one crimson accent, product floating with no card behind it.

Yellow is the default and the brand color. But the ground is per-user: today it is
assigned at random on signup, later it becomes the dominant color of the clothes you
actually own, and it is always overridable in **You → Appearance**.

That means every color on screen has to be *derived*, not hand-picked — otherwise
twelve grounds means twelve hand-tuned palettes and eleven of them are wrong.

## One hue, six roles

Everything on a screen comes from a single hue angle, in OKLCH, at fixed
lightness/chroma. OKLCH because it is perceptually uniform: the same L means the same
apparent lightness at every hue, so a green ground and a red ground get text with
identical contrast. In HSL they would not.

| Role | L | C | H | What it is |
|---|---|---|---|---|
| `ground` | 0.890 | 0.052 | H | The whole screen |
| `ground-sunk` | 0.830 | 0.052 | H | Recessed wells, the tab bar, pressed states |
| `ground-lift` | 0.955 | 0.020 | H | Sheets and cards that must sit above the ground |
| `on-ground` | 0.320 | 0.052 | H | All primary text. Reads as brown on butter, ink-teal on jade |
| `on-ground-soft` | 0.470 | 0.050 | H | Secondary text, metadata, counts |
| `accent` | 0.460 | 0.085 | H + 25 | Price, destructive, the one thing that must be seen |

### Why the chroma is so low, and identical everywhere

sRGB is not evenly shaped. At L 0.89 the most chroma you can hold is **0.21 at moss and
0.054 at blue** — a four-fold difference for the same apparent lightness.

The tempting move is to give each hue a fixed *fraction* of its own ceiling, so every
ground is as colorful as it can be. Don't: a moss user's app comes out neon next to a
blue user's washed-out one, and the twelve grounds stop feeling like one system.

So blue sets the budget for everyone. `ground` is 0.052 because that is the most chroma
every hue can hold at L 0.89. `accent` is the single exception — it is a small emphasis
color rather than a surface, so it asks for 0.085 and lets gamut mapping pull it back
per hue, which costs saturation but never hue.

Gamut mapping reduces chroma only, never clamps RGB channels. Clamping shifts hue — a
clipped teal drifts visibly green — and that would quietly destroy the premise that the
twelve grounds are evenly spaced.

The accent sits 25° off the ground hue on purpose. In the reference the price is
crimson against yellow — near enough to feel intentional, far enough to jump. A
complementary 180° accent would read as a second brand color rather than an emphasis.

`on-ground` against `ground` clears **9.1:1** at its worst hue — comfortably AAA
everywhere, which is the reason the roles are pinned to lightness rather than to
swatches. Secondary text clears 4.9:1 and the accent 5.0:1, both AA. These are asserted
in `FittiDesignTests/PaletteTests.swift` across all twelve grounds, so a future palette
tweak that breaks one hue fails the build instead of shipping.

### The grounds

Twelve hues, evenly spaced enough to be told apart at a glance:

| Name | H | | Name | H |
|---|---|---|---|---|
| **butter** (default) | 85 | | orchid | 320 |
| amber | 55 | | violet | 285 |
| terracotta | 30 | | blue | 255 |
| rose | 15 | | sky | 220 |
| blush | 350 | | teal | 195 |
| jade | 160 | | moss | 130 |

## The fixed three

The derived hue system covers screens. Three colors never move:

```
ink       #0E0E0C   the mascot's marks, the app icon, pure statements
paper     #FBFAF6   the Discover grid, where clothes are the only color
yellow    #EFC53F   the brand mark — the logo, the launch screen, the App Store icon
```

Discover is deliberately **paper**, not the user's ground. Everywhere else in Fitti is
your color; the shopping grid is a white gallery so the only color on screen belongs to
the clothes.

## Rainbow blob dots

Two to four irregular colored blobs per screen. Not decoration that repeats — they are
seeded from the screen's route name so a given screen always has the same dots in the
same places, and they drift on a slow loop.

- Drawn as a superellipse with per-vertex jitter from the seed. Never a circle.
- Size 14–46 pt, opacity 0.85, sitting behind content.
- Colors pulled from the twelve ground hues at L 0.72 / C 0.17 — saturated enough to
  register against any ground, never competing with a garment.
- They squish toward the scroll direction while scrolling and settle back with the
  standard spring.
- On success (item saved, outfit built) the nearest dot pops once.

## Type

**SF Pro** does the work. It is the system font, it ships at every optical size, and it
makes the app feel native by default.

**Bagel Fat One** carries the loud moments — the logotype, section headers, big counts.
Used at size, never below 20 pt, never for more than four words.

**Gloria Hallelujah** is the handwriting. Your note on an outfit, the empty states, the
mascot's speech. It is a voice, not a typeface for UI, and it never labels a control.

| Style | Face | Size / Weight | Tracking |
|---|---|---|---|
| `display` | Bagel Fat One | 34 | −0.5 |
| `title` | Bagel Fat One | 22 | −0.2 |
| `headline` | SF Pro | 17 semibold | 0 |
| `body` | SF Pro | 17 regular | 0 |
| `callout` | SF Pro | 15 regular | 0 |
| `label` | SF Pro | 12 medium | +0.8, uppercase |
| `numeral` | Bagel Fat One | 44 | −1 |
| `hand` | Gloria Hallelujah | 16 | 0 |

Both Google faces ship bundled (OFL). Nothing is fetched at runtime.

## Shape and depth

Radii `6 / 12 / 20 / 32 / 999`. Garment tiles use 20; sheets use 32; the capture button
is a full circle.

There are no drop shadows. Depth comes from the ground/sunk/lift lightness triplet —
a card is lighter than the ground, a well is darker, and that is the whole system. It
survives every hue, and it never produces the gray haze that a shadow over saturated
yellow does.

## Motion

Everything is spring physics. No duration-and-easing curves anywhere in the app, because
a spring interrupted mid-flight continues from its current velocity and a curve snaps.

| Spring | Response | Damping | Used for |
|---|---|---|---|
| `blob` | 0.55 | 0.62 | The signature. Tab changes, mascot, dots. Visibly overshoots |
| `snappy` | 0.32 | 0.86 | Buttons, toggles, chips. Fast, barely overshoots |
| `settle` | 0.45 | 1.0 | Sheets and navigation. No overshoot at all |
| `pour` | 0.90 | 0.75 | The limit meter filling. Slow and liquid |

**120 fps is a build setting, not a hope.** `CADisableMinimumFrameDurationOnPhone` must
be `true` in `Info.plist` or ProMotion caps the app at 60 and every spring above looks
like a cheaper version of itself.

Squash-and-stretch is the house move: pressing anything scales it to 0.96 on the press
axis and 1.03 on the cross axis, and it wobbles back. The mascot does it on launch. The
dots do it on scroll. The capture button does it on every shot.

All of it is gated on `prefers-reduced-motion` / `UIAccessibility.isReduceMotionEnabled`,
which drops to opacity crossfades and holds the dots still.

## Spacing

A 4 pt base: `4 8 12 16 24 32 48 64`. Screen gutters are 20. The garment grid is a
3-column adaptive grid with a 2 pt gap — the tiles nearly touch, so the closet reads as
one continuous surface rather than a set of cards.
