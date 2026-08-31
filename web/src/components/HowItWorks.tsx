'use client';

import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

/**
 * The four ways clothes get in.
 *
 * Ordered by how many pieces per minute each one actually adds, because that
 * ordering IS the pitch: every competing app dies on how long it takes to enter a
 * wardrobe, so the fastest path goes first.
 */
const PATHS = [
  {
    label: 'Forward a receipt',
    detail:
      'Send an order confirmation to your Fitti address. Everything in it arrives with the brand, size, price and the shop’s own photo already attached.',
    rate: '~20 pieces a minute',
  },
  {
    label: 'Share from anywhere',
    detail:
      'See something in Instagram or TikTok, hit share, pick Fitti. You never open the app.',
    rate: 'one tap',
  },
  {
    label: 'Point and shoot',
    detail:
      'Snap, snap, snap. No name, no category, no save button. Your phone cuts the background out on its own.',
    rate: '20 pieces a minute',
  },
  {
    label: 'Pick from your photos',
    detail: 'Choose fifty at once and put your phone down.',
    rate: 'bulk',
  },
];

export function HowItWorks() {
  const root = useRef<HTMLElement>(null);

  useEffect(() => {
    const context = gsap.context(() => {
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        gsap.set('.step', { opacity: 1, y: 0 });
        return;
      }
      gsap.registerPlugin(ScrollTrigger);

      gsap.fromTo(
        '.step',
        { opacity: 0, y: 34 },
        {
          opacity: 1,
          y: 0,
          duration: 0.6,
          stagger: 0.12,
          ease: 'power3.out',
          scrollTrigger: { trigger: root.current, start: 'top 72%' },
        },
      );
    }, root);

    return () => context.revert();
  }, []);

  return (
    <section ref={root} id="how" className="mx-auto w-full max-w-3xl px-6 py-24 sm:py-32">
      <h2 className="font-loud text-3xl sm:text-4xl">Getting clothes in</h2>
      <p className="mt-3 max-w-[52ch] text-(--on-ground-soft)">
        Every other wardrobe app dies here. People spend five to fifteen minutes per
        item, give up around twenty, and delete it. So Fitti has four ways in, and
        none of them has a form.
      </p>

      <ol className="mt-12 flex flex-col gap-px overflow-hidden rounded-2xl bg-(--ground-sunk)">
        {PATHS.map((path, index) => (
          <li key={path.label} className="step reveal bg-(--ground-lift) p-6 sm:p-7">
            <div className="flex items-baseline gap-4">
              <span className="font-loud text-lg text-(--on-ground-soft) tabular-nums">
                {String(index + 1).padStart(2, '0')}
              </span>
              <div className="flex-1">
                <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                  <h3 className="font-loud text-xl">{path.label}</h3>
                  <span className="text-xs uppercase tracking-[0.09em] text-(--accent)">
                    {path.rate}
                  </span>
                </div>
                <p className="mt-2 text-(--on-ground-soft)">{path.detail}</p>
              </div>
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}
