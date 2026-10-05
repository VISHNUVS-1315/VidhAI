'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { PhoneFrame } from '@/components/ui/PhoneFrame';
import { PROJECT_CONFIG } from '@/data/project';
import { MULTILINGUAL_DEMO_TEXTS } from '@/data/mockData';
import { Globe, Sparkles } from 'lucide-react';

export const LanguageBloom: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [selectedLang, setSelectedLang] = useState<string>('ta'); // Default to Tamil
  const [pulseActive, setPulseActive] = useState(false);

  const languages = PROJECT_CONFIG.languages;
  const currentLang = languages.find((l) => l.code === selectedLang) || languages[0];
  const demoText = MULTILINGUAL_DEMO_TEXTS[selectedLang] || MULTILINGUAL_DEMO_TEXTS['en'];
  const isRtl = currentLang.dir === 'rtl';

  const handleSelectLang = (code: string) => {
    setSelectedLang(code);
    setPulseActive(true);
    setTimeout(() => setPulseActive(false), 800);
  };

  return (
    <div
      data-context-label="SELECT LANGUAGE"
      className="p-6 sm:p-10 rounded-3xl bg-[#0E1C12]/95 border border-[#233E2B] glow-card mb-12 overflow-hidden relative"
    >
      {/* Background ambient radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[550px] h-[550px] bg-emerald-600/10 rounded-full blur-[140px] pointer-events-none" />

      {/* Section Sub-Header */}
      <div className="text-center max-w-2xl mx-auto mb-10">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-950/80 border border-emerald-500/30 text-xs font-mono text-emerald-300 mb-3">
          <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
          <span className="uppercase">Signature Motion Pattern: Language Bloom</span>
        </div>
        <h3 className="text-xl sm:text-2xl font-bold text-[#F1F7F2]">
          13 Indian Languages · Orbital Vernacular Architecture
        </h3>
        <p className="text-xs sm:text-sm text-[#A9BBAE] mt-2">
          Click any language petal to send an interactive localization pulse into the product frame.
        </p>
      </div>

      {/* Main Interactive Stage: Language Petal Ring + Central Genuine Screenshot */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center max-w-5xl mx-auto relative">
        {/* Left: Interactive Orbital Language Petals */}
        <div className="lg:col-span-7 space-y-3">
          <div className="flex items-center justify-between text-xs text-[#718776] font-mono border-b border-[#1E3626] pb-2">
            <span>SELECT VERNACULAR ORBIT:</span>
            <span className="text-emerald-400 font-semibold">{languages.length} Languages Ingested</span>
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            {languages.map((lang) => {
              const isSelected = selectedLang === lang.code;
              return (
                <button
                  key={lang.code}
                  onClick={() => handleSelectLang(lang.code)}
                  className={`px-3.5 py-2 rounded-2xl text-xs font-medium transition-all duration-300 cursor-pointer flex items-center gap-2 border relative ${
                    isSelected
                      ? 'bg-emerald-950/90 text-emerald-300 border-emerald-400 shadow-[0_0_15px_rgba(76,175,108,0.4)] scale-105 z-10'
                      : 'bg-[#14261A] text-[#A9BBAE] border-[#233E2B] hover:border-emerald-600/50 hover:text-[#F1F7F2]'
                  }`}
                >
                  <span className="font-semibold">{lang.native}</span>
                  <span className="text-[10px] font-mono opacity-60">({lang.name})</span>
                  {lang.dir === 'rtl' && (
                    <span className="text-[9px] font-mono px-1 py-0.2 rounded bg-amber-950 text-amber-300 border border-amber-500/30">
                      RTL
                    </span>
                  )}
                  {isSelected && (
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
                  )}
                </button>
              );
            })}
          </div>

          {/* Active Vernacular Translation Preview Card */}
          <div
            dir={isRtl ? 'rtl' : 'ltr'}
            className={`mt-6 p-5 rounded-2xl bg-[#09130B] border transition-all duration-500 ${
              pulseActive
                ? 'border-emerald-400 shadow-[0_0_20px_rgba(76,175,108,0.3)]'
                : 'border-[#233E2B]'
            }`}
          >
            <div className="flex items-center justify-between border-b border-[#1E3626] pb-3 mb-3">
              <div className="flex items-center gap-2">
                <Globe className="w-4 h-4 text-emerald-400" />
                <span className="text-xs font-bold text-[#F1F7F2]">
                  {currentLang.native} ({currentLang.name})
                </span>
              </div>
              <span className="text-[10px] font-mono text-[#718776]">
                Direction: {currentLang.dir.toUpperCase()}
              </span>
            </div>

            <div className="space-y-2">
              <div className="text-sm font-semibold text-emerald-300 font-serif">
                &ldquo;{demoText.tagline}&rdquo;
              </div>
              <div className="text-xs text-[#A9BBAE]">
                Greeting: <span className="text-[#F1F7F2] font-medium">{demoText.greeting}</span>
              </div>
              <div className="text-xs text-[#A9BBAE]">
                Weather: <span className="text-[#F1F7F2] font-medium">{demoText.weatherCondition}</span>
              </div>
              <div className="text-xs text-[#A9BBAE]">
                Recommendation:{' '}
                <span className="text-[#F1F7F2] font-medium">{demoText.recommendationTitle}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Right: Central Device Frame with Verified Real Screenshot */}
        <div className="lg:col-span-5 flex flex-col items-center justify-center relative">
          {/* Animated Connecting Pulse Rings */}
          <div
            className={`relative w-full max-w-[280px] sm:max-w-[300px] transition-all duration-500 ${
              pulseActive ? 'scale-[1.02]' : 'scale-100'
            }`}
          >
            <PhoneFrame
              src="/screenshots/farmer-home.jpg"
              alt="VidhAI Android UI Genuine Screenshot"
              statusBadge={`Active Locale: ${currentLang.code.toUpperCase()}`}
            />

            {/* Ripple Pulse Effect */}
            {pulseActive && !prefersReducedMotion && (
              <div className="absolute inset-0 rounded-[40px] border-2 border-emerald-400 animate-ping pointer-events-none opacity-50" />
            )}
          </div>

          <div className="mt-4 text-center">
            <span className="text-[11px] text-[#718776] font-mono">
              Verified Genuine Application Screen (Locale Anchored)
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
