import { BlobField } from '@/components/BlobField';
import { Hero } from '@/components/Hero';
import { HowItWorks } from '@/components/HowItWorks';
import { SmoothScroll } from '@/components/SmoothScroll';

export default function Home() {
  return (
    <>
      <SmoothScroll />

      <main className="min-h-dvh">
        <section className="relative flex min-h-dvh items-center justify-center overflow-hidden">
          <BlobField seed="landing-hero" count={5} />
          <Hero />
        </section>

        <HowItWorks />

        <section className="relative overflow-hidden border-t border-(--on-ground-soft)/15">
          <BlobField seed="landing-close" count={3} />
          <div className="relative z-10 mx-auto flex max-w-2xl flex-col items-center gap-6 px-6 py-24 text-center sm:py-32">
            <h2 className="font-loud text-3xl sm:text-4xl">
              Your colour, not ours
            </h2>
            <p className="max-w-[46ch] text-(--on-ground-soft)">
              Fitti takes on the colour you actually wear most. Every screen is that
              colour, edge to edge, with the text derived from it — so the app looks
              like your wardrobe rather than like an app.
            </p>
            <a
              href="/login"
              className="rounded-full bg-(--brand-yellow) px-7 py-3.5 font-semibold text-(--ink) transition-transform duration-200 hover:scale-[1.03] active:scale-[0.97]"
            >
              Start your closet
            </a>
            <p className="font-hand text-(--on-ground-soft)">
              free for your first 25 pieces
            </p>
          </div>
        </section>

        <footer className="border-t border-(--on-ground-soft)/15 px-6 py-10 text-center text-sm text-(--on-ground-soft)">
          Fitti
        </footer>
      </main>
    </>
  );
}
