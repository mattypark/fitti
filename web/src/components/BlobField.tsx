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
    const blobs = Array.from({ length: count }, () => ({
      x: 0.05 + random() * 0.9,
      y: 0.05 + random() * 0.9,
      radius: 22 + random() * 46,
      hue: hues[Math.floor(random() * hues.length)],
      phase: random() * Math.PI * 2,
      speed: 0.15 + random() * 0.25,
      wobble: Array.from({ length: 7 }, () => 0.82 + random() * 0.36),
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

        context.beginPath();
        const points = blob.wobble.length;
        for (let i = 0; i <= points; i += 1) {
          const angle = (i / points) * Math.PI * 2;
          // Each vertex sits at its own radius, so no two sides match — this is
          // what stops it reading as a circle.
          const wobble = blob.wobble[i % points];
          const breathe = reduced ? 1 : 1 + Math.sin(t * 1.6 + i) * 0.05;
          const r = blob.radius * wobble * breathe;
          const x = cx + Math.cos(angle) * r;
          const y = cy + Math.sin(angle) * r;
          if (i === 0) context.moveTo(x, y);
          else context.lineTo(x, y);
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
