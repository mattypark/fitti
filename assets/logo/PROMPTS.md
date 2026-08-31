# Fitti mascot — six candidate prompts

Generated from the `ip-as-logo` skill (`s1dashu/ip-as-logo-skill`), one approved
direction, six controlled variants.

**Direction:** a squishy irregular jello blob with a face — small closed-arc eyes,
one soft smirk. The defining feature is the wobbling, deliberately uneven silhouette:
no two sides match.

**Palette rule from the skill:** exactly three semantic colors per image — two IP
base colors plus one background. The six variants deliberately rotate which of
black / white / yellow plays which role.

| # | Corner | IP colors | Background |
|---|---|---|---|
| A1 | lower-left | golden yellow body, near-black marks | muted deep charcoal |
| A2 | lower-right | golden yellow body, near-black marks | muted warm cream |
| A3 | lower-left | off-white body, near-black marks | muted golden yellow |
| A4 | lower-right | near-black body, golden yellow marks | muted warm cream |
| A5 | lower-left | deep golden yellow + pale butter (two-tone body) | muted deep charcoal |
| A6 | lower-right | off-white body, golden yellow marks | muted deep charcoal |

## Running them

Any top-tier image model: GPT Image 2, Nano Banana Pro / Gemini 3 Pro Image, or
Seedance 5.0 Pro. Square, ~1536x1536. Generate each independently — never as a
contact sheet or grid.

Drop the winners in `assets/logo/` as `mascot-a1.png` ... `mascot-a6.png`, then the
chosen one becomes `assets/logo/mascot.png` and gets exported to the iOS asset
catalog and `web/public/`.

The prompts are reproduced below verbatim. Only the **Background**, **Color
behavior**, and **Composition** lines differ between them.

---

## Shared skeleton

Every prompt is this, with the three marked lines swapped per variant:

```text
Create one complete full-bleed 1:1 square image.
Background: fill the entire square with solid <BACKGROUND>. Keep <BACKGROUND> visible in every open area and in the corners not occupied by the character; the assigned emergence corner must be occupied by the character.
Subject: place one extremely simplified, cute, endearing squishy jelly blob creature on the background, reduced to one soft rounded continuous silhouette whose outline is deliberately uneven and wobbling so no two sides match, and one defining feature which is that irregular jiggling jelly body itself.
Complexity: use only 4-7 large basic shapes and at most two broad internal color regions. Use two simple closed-arc smiling eyes and add one tiny soft smirk mouth. Remove every nonessential line, outline, anatomical detail, texture, and decoration. Keep the character readable at 32 x 32.
Color behavior: <COLOR BEHAVIOR>
Composition: keep the character upright and emerging from the assigned <CORNER>, filling about 85-95% of the square so it remains visually dominant. Cropping at the bottom or assigned side is welcome when it strengthens the corner emergence. Never center or bottom-center the character.
Style: make simplification, cuteness, and lovable baby-like appeal the strongest qualities. Use large soft forms, compact proportions, thick rounded contours, and an ultra-clean graphic treatment. Prefer one clear shape over several explanatory details. Add an extremely, extremely subtle, almost imperceptible sense of depth through a barely-there neo-skeuomorphic treatment.
Finish: show only the character on the full-canvas background, with clean surfaces and normal square outer corners.
Constraints: Use no text or watermark. Add no borders, frames, cards, or presentation masks. Include one character only, with no extra subjects or scenery. Use no fragile lines, sharp tips, unnecessary outlines, tiny details, or decorative marks. Add no photorealistic material, dramatic bevel, glossy hotspot, deep occlusion, extrusion, strong three-dimensional rendering, or external cast shadow. Keep the background solid and uniform, with no texture, vignette, or lighting variation.
```

---

## A1 — lower-left

- `<BACKGROUND>`: `muted deep charcoal black`
- `<CORNER>`: `lower-left`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a warm golden yellow body and soft near-black facial marks, plus the muted deep charcoal black background. Organize both IP colors into broad purposeful masses and reuse them for facial marks. Lower the background saturation slightly so it feels gently muted and restrained while remaining clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```

## A2 — lower-right

- `<BACKGROUND>`: `muted warm cream off-white`
- `<CORNER>`: `lower-right`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a warm golden yellow body and soft near-black facial marks, plus the muted warm cream off-white background. Organize both IP colors into broad purposeful masses and reuse them for facial marks. Lower the background saturation slightly so it feels gently muted and restrained while remaining clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```

## A3 — lower-left

- `<BACKGROUND>`: `gently muted golden yellow`
- `<CORNER>`: `lower-left`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a soft warm off-white body and deep near-black facial marks, plus the gently muted golden yellow background. Organize both IP colors into broad purposeful masses and reuse them for facial marks. Keep the background clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```

## A4 — lower-right

- `<BACKGROUND>`: `muted warm cream off-white`
- `<CORNER>`: `lower-right`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a deep soft near-black body and warm golden yellow facial marks, plus the muted warm cream off-white background. Organize both IP colors into broad purposeful masses and reuse them for facial marks. Keep the background clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```

## A5 — lower-left

- `<BACKGROUND>`: `muted deep charcoal black`
- `<CORNER>`: `lower-left`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a deep saturated golden yellow lower body and a pale soft butter yellow upper body, plus the muted deep charcoal black background. Organize both IP colors into two broad purposeful horizontal masses and reuse the deep golden yellow for the facial marks. Keep the background clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```

## A6 — lower-right

- `<BACKGROUND>`: `muted deep charcoal black`
- `<CORNER>`: `lower-right`
- `<COLOR BEHAVIOR>`:

```text
use exactly three semantic colors in the complete image: exactly two IP base colors, a soft warm off-white body and warm golden yellow facial marks, plus the muted deep charcoal black background. Organize both IP colors into broad purposeful masses and reuse them for facial marks. Keep the background clean and intentional rather than gray or muddy. Keep the IP, facial marks, and background clearly separated.
```
