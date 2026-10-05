'use client';

import React from 'react';
import { Button } from '@/components/ui/Button';
import { DownloadVidhaiButton } from '@/components/ui/DownloadVidhaiButton';
import { PROJECT_CONFIG } from '@/data/project';
import { usePrefersReducedMotion } from '@/lib/motion';
import { ExternalLink, Terminal, ArrowUp, Sparkles } from 'lucide-react';

export const FinalCta: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <section className="py-28 bg-gradient-to-b from-[#0A140D] via-[#102416] to-[#0A140D] relative overflow-hidden text-center">
      {/* Glow highlight */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] bg-emerald-600/10 rounded-full blur-[140px] pointer-events-none" />

      {/* Converging Signal Lines SVG */}
      <div className="absolute inset-0 pointer-events-none flex items-center justify-center opacity-60">
        <svg
          className="w-full h-full max-w-5xl"
          viewBox="0 0 1000 400"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          {/* Left Converging Signal */}
          <path
            d="M 50 100 C 250 120, 350 200, 500 200"
            stroke="#2E7D32"
            strokeWidth="1.5"
            strokeDasharray={prefersReducedMotion ? 'none' : '6 6'}
            className={prefersReducedMotion ? '' : 'animate-signal'}
          />
          {/* Right Converging Signal */}
          <path
            d="M 950 100 C 750 120, 650 200, 500 200"
            stroke="#4CAF50"
            strokeWidth="1.5"
            strokeDasharray={prefersReducedMotion ? 'none' : '6 6'}
            className={prefersReducedMotion ? '' : 'animate-signal'}
          />
          {/* Central Resolve Pulse */}
          <circle cx="500" cy="200" r="6" fill="#81C784" />
          <circle
            cx="500"
            cy="200"
            r="16"
            stroke="#81C784"
            strokeWidth="1"
            className={prefersReducedMotion ? '' : 'animate-ping opacity-50'}
          />
        </svg>
      </div>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10 space-y-6">
        {/* Resolve to Action Badge */}
        <div className="inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-emerald-950/90 border border-emerald-500/40 text-xs font-mono text-emerald-300">
          <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
          <span className="uppercase tracking-wider">Resolve to Action: Seed → Signal → System → Decision</span>
        </div>

        <h2 className="text-4xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-[#F1F7F2] leading-tight">
          FROM SEEDING
          <br />
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-300 via-[#4CAF6C] to-emerald-200">
            TO SELLING.
          </span>
        </h2>

        <p className="text-base sm:text-lg text-[#A9BBAE] max-w-2xl mx-auto font-normal leading-relaxed">
          VidhAI brings agricultural intelligence, farm records, predictive agronomy, and direct
          market connection into one unified, cached-resilient ecosystem.
        </p>

        <div className="pt-4 flex flex-wrap items-center justify-center gap-4">
          <Button
            variant="primary"
            size="lg"
            onClick={() => {
              const el = document.querySelector('#architecture');
              el?.scrollIntoView({ behavior: 'smooth' });
            }}
          >
            Explore Technical Architecture
          </Button>

          <DownloadVidhaiButton variant="primary" size="lg" />

          <a
            href={PROJECT_CONFIG.repositoryUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-2xl bg-[#14261A] hover:bg-[#1A3222] text-[#F1F7F2] border border-[#233E2B] text-base font-semibold transition-colors"
          >
            <Terminal className="w-4 h-4 text-emerald-400" />
            <span>Private Source Repository</span>
            <ExternalLink className="w-4 h-4 text-[#718776]" />
          </a>
        </div>

        {/* Small supporting label */}
        <div className="pt-3 text-center text-xs font-mono text-[#718776]">
          Android APK · v1.0.0
        </div>

        {/* Back to top shortcut */}
        <div className="pt-8">
          <button
            onClick={scrollToTop}
            className="inline-flex items-center gap-2 text-xs font-mono text-[#718776] hover:text-emerald-400 transition-colors cursor-pointer"
          >
            <ArrowUp className="w-3.5 h-3.5" />
            <span>Return to Top</span>
          </button>
        </div>
      </div>
    </section>
  );
};
