import type { Metadata, Viewport } from 'next';
import { Plus_Jakarta_Sans, Playfair_Display, JetBrains_Mono } from 'next/font/google';
import './globals.css';
import { PROJECT_CONFIG } from '@/data/project';
import { assetPath } from '@/lib/assets';

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000/';

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
});

const playfair = Playfair_Display({
  subsets: ['latin'],
  variable: '--font-serif',
  display: 'swap',
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: `${PROJECT_CONFIG.name} — AI-Powered Agriculture Ecosystem`,
  description:
    'VidhAI is an AI-powered agriculture platform combining contextual crop intelligence, farm management, market information, multilingual assistance and farmer–consumer connectivity.',
  keywords: [
    'VidhAI',
    'AI Agriculture',
    'Flutter Agriculture App',
    'Groq AI Chat',
    'NVIDIA NIM Nemotron',
    'AGMARKNET 2.0',
    'Crop Recommendation',
    'Mandi Prices India',
  ],
  authors: [{ name: PROJECT_CONFIG.creator.name, url: PROJECT_CONFIG.creator.github }],
  openGraph: {
    title: 'VidhAI — AI-Powered Agriculture Ecosystem',
    description:
      'An AI-powered agricultural ecosystem connecting crop decisions, farm management, market intelligence and farmer–consumer interaction.',
    url: siteUrl,
    siteName: 'VidhAI Project Case Study',
    images: [
      {
        url: '/screenshots/farmer-home.jpg',
        width: 1200,
        height: 630,
        alt: 'VidhAI Agricultural Platform Interface',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'VidhAI — AI-Powered Agriculture Ecosystem',
    description:
      'Contextual AI, farm management, normalized AGMARKNET market prices, and 13-language rural accessibility.',
    images: ['/screenshots/farmer-home.jpg'],
  },
  icons: {
    icon: assetPath('/brand/vidhai-logo.png'),
    apple: assetPath('/brand/vidhai-logo.png'),
  },
};

export const viewport: Viewport = {
  themeColor: '#FAF8F5',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'VidhAI',
    operatingSystem: 'Android',
    applicationCategory: 'AgriculturalBusinessApplication',
    description: PROJECT_CONFIG.subtagline,
    author: {
      '@type': 'Person',
      name: PROJECT_CONFIG.creator.name,
      url: PROJECT_CONFIG.creator.github,
    },
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'INR',
    },
  };

  return (
    <html lang="en" className="scroll-smooth">
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body
        className={`${plusJakarta.variable} ${playfair.variable} ${jetbrainsMono.variable} antialiased bg-[#FAF8F5] text-[#18201B] min-h-screen selection:bg-[#E8F0EA] selection:text-[#1B432C]`}
      >
        {children}
      </body>
    </html>
  );
}
