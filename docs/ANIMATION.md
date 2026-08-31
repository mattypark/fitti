# Animating Fitti

Research notes on making the mascot move, and what we actually built.

---

## The question

> Do you have to make multiple images for 120fps, or is there a framework where
> you can get a transparent video or something?

**Neither.** Both bake fixed pixels at author time. The reason 120fps matters is
that geometry updates every **8.33 ms** — a pre-baked asset can't do that, and it
can't react to a finger at all.

| Approach | Real cost |
|---|---|
| Sprite sheet, 2s idle at 120fps | 240 frames ≈ **390 MB** decompressed, ~100 MB even ASTC-compressed |
| HEVC-with-alpha video | ~250 KB — but plays at **its own** frame rate, keeps the video decoder awake for a loop that never ends, **cannot respond to touch** |
| Naive `Image("blob_042")` sequence | 1–3 ms decode per frame into a ~5 ms usable budget. Guaranteed hitching |
| **Metal shader on the existing PNG** | **0 KB**, ~0.1% GPU, per-frame, touch-aware |

Transparent video on iOS is real and well-supported — HEVC with alpha, hardware
decoded since iOS 13. It's just the wrong tool for anything interactive. Keep it
for a one-shot celebration.

**WebM/VP9 alpha is impossible on iOS.** AVFoundation has no WebM demuxer, there
is no VP9 hardware decoder on any Apple silicon, and multiple `<video>` elements
reproducibly crash mobile Safari. It exists only because Chrome and Firefox on
desktop don't do HEVC alpha.

## The one line that matters more than everything else

```xml
<key>CADisableMinimumFrameDurationOnPhone</key><true/>
```

Without this, **iPhone caps third-party animation at 60fps even on ProMotion
hardware** — Apple made it opt-in for battery. Already set in `project.yml`.

---

## What we built

Three shaders in `ios/Fitti/Sources/Shaders/Blob.metal`, driven by
`Components/FittiBlob.swift`. No new assets.

### `jelly` — squash, wobble, breath

- **Volume-preserving squash**: `sx × sy = 1`. Scaling one axis without the other
  is the difference between jelly and a balloon deflating.
- **A wave running outward from the finger**, decaying with distance so the far
  side of the blob barely moves.
- **An always-on idle breath** at ~1.9 rad/s, ±1.2%. Its absence is what makes a
  static mascot feel dead.

### `liquidFill` — the limit meter

Uses the blob's **own alpha as the vessel**, so the liquid can only exist inside
him. Two sines at unrelated frequencies read as non-repeating slosh; one sine
reads as a machine. The tint **multiplies** the PNG's luminance rather than
replacing it, so the baked highlight survives being coloured in.

The mascot *is* the meter — he fills up as your closet does.

### `metaballs` — two blobs merging

The one effect nothing else can do. A vector runtime cannot boolean two shapes
per frame; a video can only replay a merge somebody already drew. A **signed
distance field** merges for free, because a smooth minimum of two distances *is*
the merged surface. Íñigo Quílez's quadratic polynomial `smin`.

Cost: ~40–50 ALU ops per pixel. Bound to a 240pt region on a 3× device that's
~518k fragment invocations — **about 0.1% of the GPU**.

---

## Two things that cost an afternoon each if nobody tells you

**1. `distortionEffect` maps destination → source.** Given a pixel you're about
to draw, you return where to *read from*. So every transform inside is the
**inverse** of the motion you see. This is the single most confusing thing about
these shaders.

**2. The artwork needs transparent margin.** The shader samples the rasterized
layer. If the blob touches the image edge, squashing pushes pixels outside the
bounds and they're simply gone — visible clipping. `mascot.png` is re-exported at
768×768 with **15% margin on every side** to deform into.

Others worth knowing:

- `ShaderLibrary.jelly(...)` uses dynamic member lookup — **no compile-time
  check**. A typo in the function name gives you a silently unmodified view.
  Nothing in Xcode warns you.
- **Xcode Previews are unreliable** for these modifiers. Test on device.
- `TimelineView(.animation)` re-evaluates its body every frame — keep the subtree
  tiny. Ours is one `Image` plus modifiers.
- **Pause when offscreen.** The `paused:` parameter is what keeps this from being
  a battery bug.
- Never put `.blur()` or `.shadow()` on a per-frame-changing path — that's an
  offscreen render pass every frame, and the #1 killer in practice.

---

## Where SwiftUI `Shape` stops being enough

Our `BlobShape` (closed Catmull-Rom through jittered control points) is fine for:

- **1 animated blob, ≤32 control points, one gradient fill, no blur** — sustains
  120fps comfortably.

Move to `Canvas` at **≥5 simultaneous animated shapes**. The benchmark: 500
`Circle()` views in a `ForEach` render at **12fps**; the same 500 drawn in one
`Canvas` render smoothly.

Move to a **Metal shader** for any per-pixel shading, real merging, or
touch-reactive deformation.

The bottleneck is never `path(in:)` — a 24-point curve is microseconds. It's that
a *changing path* must be re-tessellated and re-rasterized every frame by Core
Animation, whereas a transform-only animation is executed by the render server
for free.

**iOS 26 gives us `@Animatable`**, which synthesises `animatableData` from stored
properties and kills the `AnimatablePair` nesting. Worth adopting.

---

## Outfit-reactive animation — how this scales

The shader takes **arguments**, which is exactly what makes reacting to an outfit
possible without new art:

| Signal | Shader argument | Reads as |
|---|---|---|
| Outfit colour harmony score | tint + `amplitude` | bouncier and warmer when the fit works |
| Formality | `squash` rest value | slouches in loungewear, stands up in tailoring |
| Warmth vs weather | breath rate | puffs up when overdressed |
| Never-worn piece surfaced | one-shot wobble burst | notices something new |
| Closet fullness | `level` | already wired |

All of it is a `Double` fed into an existing uniform. **No new assets, no new
animation files.** This is the argument for shaders over any pre-baked format:
the character can respond to data that didn't exist when the art was made.

For *performance* — blinks, expressions, looking at a garment, a reaction when an
outfit is saved — that's where **Rive** earns its place.

---

## Rive — the plan when we want character performance

| | |
|---|---|
| Runtime | `RiveRuntime` 6.25.0 (Aug 2026), **MIT**, free forever |
| Install | SPM `https://github.com/rive-app/rive-ios` |
| Min iOS | 14.0, Swift 5.9 |
| Editor | Free tier usable; **$9/seat/mo** to ship to production |
| Renderer | Custom Metal vector rasterizer, dirty-rect, **~0% idle CPU** |

Benchmarks (Android, architecturally indicative): **Rive ~60fps at 31.8% CPU vs
Lottie 17fps at 91.8%** on the same complex animation.

**How you'd rig our mascot — concretely:**

1. Import `mascot.png` (or a PSD with face/body/highlight on separate layers).
2. Select it → **Create Mesh** → **New Contour** → click ~12–20 vertices around
   the silhouette. Fewer is better; you weight them by hand after.
3. **Subdivide** with interior vertices, plus forced edges around the face so it
   doesn't smear when the body deforms.
4. Add 2–4 **bones**: a root, a squish bone, optionally left/right lobes.
5. **Bind** bones to the mesh — Rive **auto-generates initial weights**; refine
   with the Smooth tool.
6. Timelines: `idle` (2s loop), `press` (0.15s squash), `release` (0.4s
   overshoot), `react` (per outfit event).
7. **State machine** with inputs: `isPressed: Bool`, `level: Number`,
   `mood: Number`, `celebrate: Trigger`.

```swift
import RiveRuntime

final class FittiRive: ObservableObject {
    let rive = RiveViewModel(fileName: "fitti", stateMachineName: "Fitti")
    func setMood(_ v: Double) { rive.setInput("mood", value: v) }   // outfit score
    func celebrate()          { rive.triggerInput("celebrate") }
}
```

**Learning path:** [Rive 101](https://rive101.com/) lessons **5.2 and 5.4** cover
meshes and bone binding — the only two you need. **8–16 hours** to a shippable
blob for someone who isn't an animator.

**Before committing, measure the app-size delta.** The XCFramework zip is 115 MB
all-platform-fat; the thinned arm64 contribution is far smaller, but check an App
Store size report. That's the single biggest reason a small app rejects Rive.

**Keep the shader layer either way.** Rive does character performance; the shader
does physics-y touch response, and going through a state machine for something a
uniform does directly is the wrong trade.

---

## What we rejected, and why

- **Lottie** — no mesh deformation, so the blob would have to be redrawn as
  vectors and the baked 3D shading lost. After Effects **Puppet Pin does not
  export** through Bodymovin, which kills the one AE tool that could deform a
  raster image. Known gradient-with-alpha gaps silently fall back to main-thread
  rendering. Interactivity is segment playback, not state.
- **Sprite sheets** — 98–390 MB. Only defensible if the hand-drawn cel look *is*
  the aesthetic.
- **3D (RealityKit / Spline)** — SceneKit is soft-deprecated as of WWDC25;
  RealityKit is a full ECS engine; and a live 3D view keeps a render loop awake
  for **3–8% sustained CPU** on a mascot that appears on every screen. We already
  have the 3D *look*, baked into the PNG, free.
- **AI image-to-video** — Veo doesn't export alpha at all; Kling and Seedance
  "alpha" is post-process matting. Characters drift (face slides, hue shifts,
  gloss wanders), **nothing loops**, and 20–50 generations at $0.35–2.00 each
  gets you $10–200 of a video you still can't interact with.

---

## If we ever do want transparent video

For a one-shot hero moment only.

```bash
# PNG sequence → ProRes 4444 with alpha
ffmpeg -framerate 30 -i frame_%04d.png -c:v prores_ks -profile:v 4444 \
       -pix_fmt yuva444p10le -alpha_bits 16 -f mov prores.mov

# ProRes → HEVC with alpha. This is the reliable path.
avconvert --preset PresetHEVCHighestQualityWithAlpha \
          --source prores.mov --output blob.mov
```

**ffmpeg cannot do this via libx265** — there is no `yuva420p` support, full
stop. `hevc_videotoolbox -alpha_quality` sometimes works and sometimes silently
drops the alpha. Always verify:

```swift
let tracks = try await asset.loadTracks(withMediaCharacteristic: .containsAlphaChannel)
print(tracks.isEmpty ? "no alpha" : "alpha present")
```

Playback: **SwiftUI's `VideoPlayer` cannot do this** — its backing view is opaque
and you get black. Use `AVPlayerLayer` in a `UIViewRepresentable` with
`pixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]`,
which is the documented workaround that forces alpha through the compositing path.

---

## Sources

- [Apple: Optimizing for ProMotion](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays)
- [Apple: distortionEffect](https://developer.apple.com/documentation/swiftui/view/distortioneffect(_:maxsampleoffset:isenabled:))
- [Íñigo Quílez — smooth minimum](https://iquilezles.org/articles/smin/)
- [twostraws/Inferno](https://github.com/twostraws/Inferno) — 30+ MIT shaders worth reading
- [rive-app/rive-ios](https://github.com/rive-app/rive-ios) · [Rive meshes](https://rive.app/docs/editor/manipulating-shapes/meshes) · [Rive 101](https://rive101.com/)
- [Callstack — Lottie vs Rive benchmarks](https://www.callstack.com/blog/lottie-vs-rive-optimizing-mobile-app-animation)
- [WWDC19 — HEVC Video with Alpha](https://asciiwwdc.com/2019/sessions/506)
- [Jake Archibald — Video with alpha transparency on the web](https://jakearchibald.com/2024/video-with-transparency/)
- [SwiftUI 240fps guide](https://dipendrasharma.com/articles/swiftui-240fps-performance-guide/)
- [WWDC25 — Bring your SceneKit project to RealityKit](https://developer.apple.com/videos/play/wwdc2025/288/)
