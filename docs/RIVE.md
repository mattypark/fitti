# Animating Fitti in Rive

The runtime is wired and building. Drop `fitti.riv` into
`ios/Fitti/Resources/` and `RiveMascot` picks it up automatically — no code
change. Until then it falls back to the Metal shader, so nothing is ever broken
by a missing file.

## Why both Rive and the shader

They do different jobs and neither replaces the other.

| | Owns |
|---|---|
| **Metal shader** | Physics — squash, touch response, the liquid fill. Anything wanting a value *per frame* rather than a state transition |
| **Rive** | Performance — blinking, looking around, reacting when an outfit is saved. Anything you'd otherwise hand-animate |

Running touch response through a state machine is the wrong shape; hand-coding a
blink is tedious. Use each for what it's good at.

## Setup

| | |
|---|---|
| Runtime | `RiveRuntime` 6.25.0, **MIT**, free forever |
| Editor | Free tier works; **$9/seat/mo** to ship to production |
| Min iOS | 14.0 — we're on 18, fine |
| Already in | `ios/project.yml`, resolved and building |

## Authoring the file

1. **New file** in the Rive editor, **512 × 512** artboard named `Fitti`.
2. **Import** `assets/logo/mascot-cutout.png` (already background-free).
   A layered PSD is better if you have one — face and body on separate layers
   means the face can stay put while the body deforms.
3. Select the image → **Create Mesh** → **New Contour** → click **12–20
   vertices** around the silhouette. Fewer is better; you weight them by hand
   afterwards and every extra vertex is more work.
4. **Subdivide** with a few interior vertices, and add **forced edges around the
   face** so it doesn't smear when the body squashes. This is the step that
   separates "alive" from "melting".
5. Add **3 bones**: a root at the base, a squish bone up the centre, and one
   lobe bone for asymmetry.
6. **Bind** the bones to the mesh — Rive **auto-generates initial weights**.
   Refine with the **Smooth** tool where the deformation looks pinched.

## Timelines to build

| Name | Length | What happens |
|---|---|---|
| `idle` | 2s loop | ±4% scale, slow bone wobble. Never stops |
| `blink` | 0.2s | Eyes close and open. Fire randomly every 3–7s |
| `poke` | 0.15s + 0.4s | Squash, then overshoot back. The release is the character |
| `happy` | 0.8s | Bounce, eyes curve up. For a good outfit |
| `sleepy` | 2s loop | Slower breath, eyes half. For an unworn closet |

## State machine — name it `Fitti`

Inputs the app already sends:

| Input | Type | Range | Meaning |
|---|---|---|---|
| `mood` | Number | 0–100 | How well the outfit works. Blends `sleepy` → `idle` → `happy` |
| `level` | Number | 0–100 | Closet fullness |
| `poke` | Trigger | — | Fired on tap |

`mood` as a **blend state** rather than three separate states is what makes it
feel continuous instead of switchy.

## Then

Export → **`fitti.riv`** → drop in `ios/Fitti/Resources/`. That's it.

```swift
RiveMascot(size: 130, mood: outfitScore, level: closetFullness)
```

## Learning

[Rive 101](https://rive101.com/) — **lessons 5.2 and 5.4** are the only two you
need (meshes, and bone binding/weighting). About **8–16 hours** to a shippable
blob if you've never used it.

Rive's **AI Agent** (free tier, hourly quota) is genuinely useful for the state
machine plumbing. It will **not** rig the PNG for you — that's still the manual
part, and it's the part worth learning.

## Before shipping it

**Measure the app-size delta.** The XCFramework zip is 115 MB all-platform-fat;
the thinned arm64 contribution is much smaller, but check an App Store size
report before committing. That's the single biggest reason a small app rejects
Rive, and it's better to know now than after the animation work is done.
