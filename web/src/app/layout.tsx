import type { Metadata, Viewport } from 'next';
import { Bagel_Fat_One, Gloria_Hallelujah } from 'next/font/google';
import './globals.css';

// Self-hosted at build time by next/font, so there is no render-blocking request
// to Google and no layout shift when the face arrives.
const bagel = Bagel_Fat_One({
  weight: '400',
  subsets: ['latin'],
  variable: '--ff-loud-font',
  display: 'swap',
});

const gloria = Gloria_Hallelujah({
  weight: '400',
  subsets: ['latin'],
  variable: '--ff-hand-font',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Fitti — the wardrobe app that knows what you already own',
  description:
    'Photograph your closet. Fitti catalogs every piece, builds outfits from what you own, and filters shopping through your real taste.',
  openGraph: {
    title: 'Fitti',
    description: 'The wardrobe app that knows what you already own.',
    images: ['/banner.png'],
  },
};

export const viewport: Viewport = {
  themeColor: '#EBD9B4',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-ground="butter">
      <body className={`${bagel.variable} ${gloria.variable}`}>{children}</body>
    </html>
  );
}
