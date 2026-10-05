'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { PhoneFrame } from '@/components/ui/PhoneFrame';
import { Modal } from '@/components/ui/Modal';
import { VERIFIED_SCREENSHOTS } from '@/data/screenshots';
import { Eye, ArrowRight, ArrowLeft } from 'lucide-react';
import { assetPath } from '@/lib/assets';

export const ScreenshotCascade: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeIndex, setActiveIndex] = useState<number>(0);
  const [lightboxOpen, setLightboxOpen] = useState<boolean>(false);

  const activeScreen = VERIFIED_SCREENSHOTS[activeIndex] || VERIFIED_SCREENSHOTS[0];

  const handleNext = () => {
    setActiveIndex((prev) => (prev + 1) % VERIFIED_SCREENSHOTS.length);
  };

  const handlePrev = () => {
    setActiveIndex((prev) => (prev - 1 + VERIFIED_SCREENSHOTS.length) % VERIFIED_SCREENSHOTS.length);
  };

  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight') {
        setActiveIndex((prev) => (prev + 1) % VERIFIED_SCREENSHOTS.length);
      } else if (e.key === 'ArrowLeft') {
        setActiveIndex((prev) => (prev - 1 + VERIFIED_SCREENSHOTS.length) % VERIFIED_SCREENSHOTS.length);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  return (
    <div
      data-context-label="VIEW SCREEN"
      className="p-6 sm:p-10 rounded-3xl bg-[#0E1C12]/95 border border-[#233E2B] glow-card mb-12 overflow-hidden relative"
    >
      {/* Background ambient radial glow */}
      <div className="absolute top-1/2 right-1/4 -translate-y-1/2 w-96 h-96 bg-emerald-600/10 rounded-full blur-[120px] pointer-events-none" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#233E2B] pb-4 mb-8">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold tracking-wider">
              Signature Motion Pattern: Screenshot Cascade
            </span>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 border border-emerald-500/30 text-emerald-300">
              {VERIFIED_SCREENSHOTS.length} Genuine Screens Verified
            </span>
          </div>
          <h3 className="text-xl sm:text-2xl font-bold text-[#F1F7F2] mt-1">
            Real Engineered Product Proof
          </h3>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handlePrev}
            aria-label="Previous screenshot"
            className="p-2 rounded-xl bg-[#14261A] border border-[#233E2B] text-[#A9BBAE] hover:text-[#F1F7F2] transition-colors cursor-pointer"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
          <button
            onClick={handleNext}
            aria-label="Next screenshot"
            className="p-2 rounded-xl bg-[#14261A] border border-[#233E2B] text-[#A9BBAE] hover:text-[#F1F7F2] transition-colors cursor-pointer"
          >
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* 2-Column Cascade Layout: Left (Feature Story Navigator) | Right (Stacked Device Perspective) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center max-w-5xl mx-auto">
        {/* Left: Synchronized Feature Story Navigator */}
        <div className="lg:col-span-6 space-y-3">
          {VERIFIED_SCREENSHOTS.map((screen, idx) => {
            const isSelected = activeIndex === idx;
            return (
              <div
                key={screen.id}
                onClick={() => setActiveIndex(idx)}
                className={`p-4 rounded-2xl border transition-all duration-300 cursor-pointer text-left relative ${
                  isSelected
                    ? 'bg-[#14261A] border-emerald-400 shadow-[0_0_20px_rgba(76,175,108,0.3)] scale-[1.02]'
                    : 'bg-[#0B170E]/80 border-[#233E2B] hover:border-emerald-600/40'
                }`}
              >
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-mono text-emerald-400 font-semibold">
                      0{idx + 1}
                    </span>
                    <h4 className="text-sm font-bold text-[#F1F7F2]">{screen.screenName}</h4>
                  </div>
                  {isSelected && (
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 text-emerald-300 border border-emerald-500/40">
                      ACTIVE
                    </span>
                  )}
                </div>

                <p className="text-xs text-[#A9BBAE] leading-relaxed">{screen.description}</p>

                <div className="flex items-center gap-3 pt-2 text-[10px] font-mono text-[#718776]">
                  <span>Device: {screen.device}</span>
                  <span>•</span>
                  <span>Lang: {screen.language}</span>
                  <span>•</span>
                  <span className="text-emerald-400">Verified Ground Truth</span>
                </div>
              </div>
            );
          })}
        </div>

        {/* Right: Stacked Cascade Device Display */}
        <div className="lg:col-span-6 flex flex-col items-center justify-center relative">
          <div className="relative w-full max-w-[290px] sm:max-w-[310px] h-[580px] flex items-center justify-center">
            {/* Background layered card */}
            <div
              className={`absolute top-4 w-full h-[520px] rounded-[42px] bg-[#0A140D] border border-[#1E3626] transition-all duration-500 pointer-events-none opacity-40 scale-90 ${
                prefersReducedMotion ? '' : 'translate-y-6'
              }`}
            />

            {/* Active Foreground PhoneFrame */}
            <div
              onClick={() => setLightboxOpen(true)}
              className="relative z-20 w-full cursor-pointer transition-all duration-500 transform hover:scale-[1.02]"
            >
              <PhoneFrame
                src={assetPath(activeScreen.file)}
                alt={activeScreen.screenName}
                statusBadge="Verified Genuine Screenshot"
                onImageClick={() => setLightboxOpen(true)}
              />
            </div>
          </div>

          <button
            onClick={() => setLightboxOpen(true)}
            className="mt-4 inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-emerald-950/80 border border-emerald-500/40 text-xs font-mono text-emerald-300 hover:bg-emerald-900 transition-colors cursor-pointer"
          >
            <Eye className="w-3.5 h-3.5" />
            <span>Open High-Res Lightbox</span>
          </button>
        </div>
      </div>

      {/* Accessible Full-Screen Lightbox Modal */}
      <Modal isOpen={lightboxOpen} onClose={() => setLightboxOpen(false)} title={activeScreen.screenName}>
        <div className="space-y-4">
          <div className="relative max-h-[70vh] flex items-center justify-center bg-[#070D08] rounded-2xl p-4 overflow-hidden">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={assetPath(activeScreen.file)}
              alt={activeScreen.screenName}
              className="max-h-[65vh] w-auto object-contain rounded-xl shadow-2xl"
            />
          </div>

          <div className="p-4 rounded-2xl bg-[#0E1C12] border border-[#233E2B] space-y-2">
            <div className="flex items-center justify-between text-xs font-mono text-emerald-400">
              <span>{activeScreen.feature}</span>
              <span>Captured: {activeScreen.capturedAt}</span>
            </div>
            <p className="text-xs sm:text-sm text-[#A9BBAE] leading-relaxed">
              {activeScreen.description}
            </p>
          </div>

          <div className="flex items-center justify-between pt-2">
            <button
              onClick={handlePrev}
              className="px-3 py-1.5 rounded-xl bg-[#14261A] border border-[#233E2B] text-xs text-[#F1F7F2] hover:bg-[#182F20] transition-colors cursor-pointer"
            >
              ← Previous Screen
            </button>
            <span className="text-xs text-[#718776] font-mono">
              {activeIndex + 1} / {VERIFIED_SCREENSHOTS.length}
            </span>
            <button
              onClick={handleNext}
              className="px-3 py-1.5 rounded-xl bg-[#14261A] border border-[#233E2B] text-xs text-[#F1F7F2] hover:bg-[#182F20] transition-colors cursor-pointer"
            >
              Next Screen →
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
};
