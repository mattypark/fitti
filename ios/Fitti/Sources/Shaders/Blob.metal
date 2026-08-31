#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Fitti's mascot, deformed on the GPU.
//
// The alternative approaches all bake pixels at author time: a sprite sheet for a
// 2-second loop at 120fps is 240 frames and ~390MB decompressed, and transparent
// video plays at its own frame rate and cannot react to a finger at all. A shader
// evaluates the deformation every frame, so it runs at whatever the display is
// doing and takes the touch position as an argument.
//
// It also keeps the soft 3D shading already baked into the PNG, which is the part
// that would be lost by redrawing the character as vectors.

// ---------------------------------------------------------------------------
// jelly — squash, touch-sourced wobble, and an idle breath.
//
// distortionEffect maps DESTINATION -> SOURCE: given a pixel we are about to
// draw, return where to read from. So every transform here is the INVERSE of the
// motion you see, which is the single most confusing thing about these shaders.
// ---------------------------------------------------------------------------
[[ stitchable ]] float2 jelly(float2 pos,
                              float2 size,
                              float  time,
                              float  squash,   // 0 at rest, 1 fully pressed
                              float2 touch,
                              float  amplitude)
{
    float2 centre = size * 0.5;
    float2 p = pos - centre;

    // Squash and stretch, with sx * sy == 1 so apparent volume is preserved.
    // Scaling one axis without the other is the difference between jelly and a
    // balloon deflating.
    float sy = 1.0 - 0.22 * squash;
    float sx = 1.0 / sy;
    p = float2(p.x / sx, p.y / sy);

    // A wave running outward from the finger, decaying with distance so the far
    // side of the blob barely moves.
    float2 delta = pos - touch;
    float radius = length(delta) / max(size.x, size.y);
    float wave = sin(radius * 18.0 - time * 9.0) * exp(-radius * 3.5);
    p += normalize(delta + 1e-4) * wave * amplitude * squash;

    // Idle breathing. Always on, costs nothing, and its absence is what makes a
    // static mascot feel dead.
    p /= (1.0 + sin(time * 1.9) * 0.012);

    return p + centre;
}

// ---------------------------------------------------------------------------
// liquidFill — the closet limit meter, using the blob's own alpha as the vessel.
// ---------------------------------------------------------------------------
[[ stitchable ]] half4 liquidFill(float2 pos, half4 colour,
                                  float2 size, float level,
                                  float time, half4 liquid)
{
    if (colour.a < 0.01h) return colour;   // outside the blob, leave it alone

    float surface = size.y * (1.0 - level);
    // Two sines at unrelated frequencies read as non-repeating slosh; one sine
    // reads as a machine.
    surface += sin(pos.x * 0.045 + time * 2.30) * 6.0
             + sin(pos.x * 0.021 - time * 1.40) * 3.0;

    float submerged = smoothstep(surface + 1.5, surface - 1.5, pos.y);

    // Multiply the tint by the PNG's own luminance rather than replacing it, so
    // the baked highlight and shadow survive being coloured in.
    float luminance = dot(float3(colour.rgb), float3(0.299, 0.587, 0.114));
    float3 tinted = float3(liquid.rgb) * (0.55 + 0.75 * luminance);
    return half4(half3(mix(float3(colour.rgb), tinted, 0.88 * submerged)), colour.a);
}

// ---------------------------------------------------------------------------
// metaballs — two blobs that genuinely merge and separate.
//
// The one effect no other technique can do: a vector runtime cannot boolean two
// shapes per frame, and a video can only replay a merge someone already drew.
// Signed distance fields merge for free, because a smooth minimum of two
// distances IS the merged surface.
// ---------------------------------------------------------------------------

// Quadratic polynomial smooth minimum (Íñigo Quílez). Avoids the distance
// overestimation of the exponential variant and is cheaper.
inline float smoothMin(float a, float b, float k) {
    k *= 4.0;
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

[[ stitchable ]] half4 metaballs(float2 pos, half4 unused,
                                 float2 a, float radiusA,
                                 float2 b, float radiusB,
                                 float smoothing, float time)
{
    float d = smoothMin(length(pos - a) - radiusA,
                        length(pos - b) - radiusB,
                        smoothing);

    // Analytic antialiasing: fwidth gives the distance change across one pixel,
    // so this is exactly one pixel of edge regardless of scale.
    float aa = fwidth(d);
    float coverage = 1.0 - smoothstep(-aa, aa, d);
    if (coverage <= 0.0) return half4(0.0h);

    // The field's gradient is the surface normal, which buys cheap 3D shading
    // that matches the mascot's baked look.
    float2 gradient = float2(dfdx(d), dfdy(d));
    float3 normal = normalize(float3(gradient * 14.0, 1.0));
    float3 lightDir = normalize(float3(-0.40, -0.72, 0.57));

    float lambert = saturate(dot(normal, lightDir));
    float rim = pow(1.0 - saturate(normal.z), 3.0) * 0.35;
    float spec = pow(lambert, 28.0) * 0.60;

    float3 base = mix(float3(0.93, 0.72, 0.10),
                      float3(1.00, 0.94, 0.55), lambert);

    return half4(half3(base + spec + rim) * half(coverage), half(coverage));
}
