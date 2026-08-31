'use client';

import { useEffect, useRef } from 'react';

/**
 * The drifting colour blobs, on canvas.
 *
 * Canvas rather than SVG because these are organic shapes redrawn every frame —
 * a few hundred path updates a second through the DOM is the kind of thing that
 * quietly costs you a smooth scroll.
 *
 * Seeded from the section name, so a given section always has the same blobs in
 * the same places. Scenery, not noise.
 */
export function BlobField({ seed, count = 4 }: { seed: string; count?: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext('2d');
    if (!context) return;

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    // FNV-1a: stable across reloads, unlike anything seeded from Math.random.
    let hash = 0x811c9dc5;
    for (const char of seed) {
      hash ^= char.charCodeAt(0);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    const random = () => {
      hash = (Math.imul(hash, 1664525) + 1013904223) >>> 0;
      return hash / 0xffffffff;
    };

    const hues = [85, 55, 30, 15, 350, 320, 285, 255, 220, 195, 160, 130];
    // Spread across columns rather than sampling x freely. Pure random clusters:
    // with four blobs there is a real chance all four land on one side, which is
    // exactly what it did.
    const blobs = Array.from({ length: count }, (_, index) => ({
      x: (index + 0.5) / count + (random() - 0.5) * (0.6 / count),
      y: 0.08 + random() * 0.84,
      radius: 20 + random() * 34,
      hue: hues[Math.floor(random() * hues.length)],
      phase: random() * Math.PI * 2,
      speed: 0.15 + random() * 0.25,
      // Six points reads as a blob; more averages back out into a circle.
      wobble: Array.from({ length: 6 }, () => 0.78 + random() * 0.42),
    }));

    let frame = 0;
    let width = 0;
    let height = 0;

    const resize = () => {
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.getBoundingClientRect();
      width = rect.width;
      height = rect.height;
      canvas.width = width * ratio;
      canvas.height = height * ratio;
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    };

    const draw = (time: number) => {
      context.clearRect(0, 0, width, height);

      for (const blob of blobs) {
        const t = reduced ? 0 : (time / 1000) * blob.speed + blob.phase;
        const cx = blob.x * width;
        const cy = blob.y * height + Math.sin(t) * 14;

        // Vertices first, each at its own radius so no two sides match — that
        // unevenness is what stops it reading as a circle.
        const points = blob.wobble.length;
        const vertices: Array<[number, number]> = [];
        for (let i = 0; i < points; i += 1) {
          const angle = (i / points) * Math.PI * 2;
          const breathe = reduced ? 1 : 1 + Math.sin(t * 1.6 + i) * 0.05;
          const r = blob.radius * blob.wobble[i] * breathe;
          vertices.push([cx + Math.cos(angle) * r, cy + Math.sin(angle) * r]);
        }

        // Then curve THROUGH them. Joining vertices with straight lines draws a
        // heptagon, not a blob — the curve is the entire difference between the
        // two, and it was the bug here.
        //
        // Quadratic segments anchored at edge midpoints, with each vertex as the
        // control point: the classic smooth-closed-shape construction, and it
        // needs no special case to close the loop.
        context.beginPath();
        const midpoint = (a: [number, number], b: [number, number]): [number, number] =>
          [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];

        let start = midpoint(vertices[points - 1], vertices[0]);
        context.moveTo(start[0], start[1]);
        for (let i = 0; i < points; i += 1) {
          const control = vertices[i];
          const end = midpoint(vertices[i], vertices[(i + 1) % points]);
          context.quadraticCurveTo(control[0], control[1], end[0], end[1]);
        }
        context.closePath();
        context.fillStyle = `oklch(0.72 0.17 ${blob.hue})`;
        context.fill();
      }

      if (!reduced) frame = requestAnimationFrame(draw);
    };

    resize();
    window.addEventListener('resize', resize);
    frame = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener('resize', resize);
    };
  }, [seed, count]);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="pointer-events-none absolute inset-0 h-full w-full"
    />
  );
}
