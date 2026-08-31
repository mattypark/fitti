# Animating Fitti in Rive

**Rive ships an official MCP server, and it is already running on this Mac** at
`127.0.0.1:9791`, registered as `rive`. It exposes 39 tools, including
`mesh_rigging_tool` — which does `generateMesh` (traced to the image silhouette),
`bindBones`, and `autoWeight`. That is the rigging this document previously said
had to be done by hand.

**So Claude can build `fitti.riv` directly.** The only manual step left is
creating the bones: no tool exposes bone creation, so a human presses **B** and
drags three times. About two minutes, once.

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
| Editor | **$9/seat/mo (Cadet) required — the Free tier cannot export at all.** Not "no production rights": you cannot get a `.riv` out for even a debug build |
| Min iOS | 14.0 — we're on 18, fine |
| Already in | `ios/project.yml`, resolved and building |

## Authoring the file

**The short version now:** open Rive, make a 512×512 artboard named `Fitti`, draw
three bones, and hand the rest to Claude through the MCP:

```
upload_asset       assets/logo/mascot-cutout.png     ← the one WITH alpha
assets_tool        addImageInstance
mesh_rigging_tool  generateMesh { trace: true, detail: 0.5, subdivisions: 2 }
mesh_rigging_tool  bindBones { boneNames: ["root", "squish", "lobe"] }
animation_editor   createStateMachine "Fitti"  (mood / level / lookX / poke)
export_file        { format: "riv", destination: "ios/Fitti/Resources" }
```

Two gotchas: binding a target the first time **auto-weights it**, so a separate
`autoWeight` call is only needed to re-run with different settings. And if
several overlapping shapes share bones, weight them in **one** call or the
artwork tears at the seam.

Use `mascot-cutout.png`, not `mascot.png` — the latter has no alpha channel.

The manual version, for reference:

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

Rive's MCP **does** rig the PNG — `mesh_rigging_tool` traces the mesh to the
silhouette and auto-computes vertex weights. Only bone creation is manual.

## App size — measured, and it is a non-issue

The xcframework is 397 MB on disk, but that is eight platform slices plus dSYMs.
The artifact that actually ships is `ios-arm64/RiveRuntime.framework/RiveRuntime`
= **6.0 MB**, and roughly **2–3 MB** after App Store thinning. This was listed as
the main reason to hesitate. It isn't one.

## What still needs a human

1. **Creating the bones** — no MCP tool exposes it. Press B, drag three times.
2. **The $9/mo Cadet seat** — the Free tier cannot export a `.riv` at all.
3. **Looking at it.** `simulateStateMachine` returns a console trace and does not
   render pixels. Nothing tells you whether the blob looks alive or looks like
   melting wax — which is exactly the judgment that killed the drawn version.
4. **Where the forced edges go.** `detail` and `subdivisions` are parameters;
   "put forced edges around the face so it doesn't smear" is a call about where
   the character's structure is.
