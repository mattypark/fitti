'use client';

import { useEffect, useRef } from 'react';
import Image from 'next/image';
import gsap from 'gsap';

/**
 * The opening sequence.
 *
 * The mascot lands first and squashes — that overshoot is the whole brand, and
 * putting it before the words means the personality arrives before the pitch.
 * Everything starts hidden via .reveal so the page never flashes its finished
 * state before the timeline runs.
 */
export function Hero() {
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const context = gsap.context(() => {
      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        gsap.set('.reveal', { opacity: 1, y: 0, scale: 1 });
        return;
      }

      const timeline = gsap.timeline({ defaults: { ease: 'power3.out' } });

      timeline
        .fromTo(
          '.hero-mascot',
          { opacity: 0, y: -90, scaleY: 1.25, scaleX: 0.8 },
          { opacity: 1, y: 0, scaleY: 1, scaleX: 1, duration: 0.75, ease: 'elastic.out(1, 0.55)' },
        )
        // The squash on landing. Reads as weight rather than as a fade-in.
        .to('.hero-mascot', { scaleY: 0.9, scaleX: 1.1, duration: 0.12 }, '-=0.45')
        .to('.hero-mascot', { scaleY: 1, scaleX: 1, duration: 0.5, ease: 'elastic.out(1, 0.4)' })
        .fromTo('.hero-word', { opacity: 0, y: 26 }, { opacity: 1, y: 0, duration: 0.6 }, '-=0.7')
        .fromTo('.hero-line', { opacity: 0, y: 18 }, { opacity: 1, y: 0, duration: 0.55, stagger: 0.09 }, '-=0.35')
        .fromTo('.hero-cta', { opacity: 0, y: 14 }, { opacity: 1, y: 0, duration: 0.5 }, '-=0.25');
    }, root);

    return () => context.revert();
  }, []);

  return (
    <div ref={root} className="relative z-10 flex flex-col items-center gap-6 px-6 text-center">
      <Image
        src="/mascot.png"
        alt=""
        width={168}
        height={154}
        priority
        className="hero-mascot reveal h-auto w-[132px] origin-bottom sm:w-[168px]"
      />

      <h1 className="hero-word reveal font-loud text-[clamp(3.2rem,13vw,6.5rem)] leading-[0.9] tracking-tight">
        Fitti
      </h1>

      <p className="hero-line reveal max-w-[22ch] font-hand text-lg text-(--on-ground-soft) sm:text-xl">
        your closet, but it knows what&rsquo;s in it
      </p>

      <p className="hero-line reveal max-w-[46ch] text-base leading-relaxed text-(--on-ground) sm:text-lg">
        Photograph what you own. Fitti cuts each piece out, remembers it, and builds
        outfits from your actual wardrobe — not a catalogue of clothes you don&rsquo;t have.
      </p>

      <div className="hero-cta reveal flex flex-col items-center gap-3 sm:flex-row">
        <a
          href="/login"
          className="rounded-full bg-(--brand-yellow) px-7 py-3.5 font-semibold text-(--ink) transition-transform duration-200 hover:scale-[1.03] active:scale-[0.97]"
        >
          Start your closet
        </a>
        <a
          href="#how"
          className="rounded-full px-7 py-3.5 font-medium text-(--on-ground-soft) underline-offset-4 hover:underline"
        >
          See how it works
        </a>
      </div>
    </div>
  );
}
