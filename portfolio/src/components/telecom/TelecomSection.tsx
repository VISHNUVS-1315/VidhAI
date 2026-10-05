'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import {
  PhoneCall,
  Radio,
  ArrowRight,
  Headphones,
  CheckCircle2,
  Sparkles,
  Smartphone,
  Layers,
} from 'lucide-react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { TELECOM_STEPS } from './telecomData';
import { TelecomDesktopDiagram } from './TelecomDesktopDiagram';
import { TelecomMobileTimeline } from './TelecomMobileTimeline';
import { TechProviderGrid } from './TechProviderGrid';

export const TelecomSection: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeStepId, setActiveStepId] = useState<string>('05'); // Default to prominent AI layer
  const [hoveredStepId, setHoveredStepId] = useState<string | null>(null);

  // Active step determining highlighted technology provider cards
  const currentStep =
    TELECOM_STEPS.find((s) => s.id === (hoveredStepId || activeStepId)) ||
    TELECOM_STEPS[4]; // Default to Step 05

  const headerVariants: Variants = {
    hidden: { opacity: 0, y: prefersReducedMotion ? 0 : 14 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: prefersReducedMotion ? 0.01 : 0.45,
        ease: 'easeOut',
      },
    },
  };

  return (
    <section
      id="telecom"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-[#FAF8F5] border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        {/* SECTION HEADER */}
        <motion.div
          variants={headerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="text-center max-w-3xl mx-auto mb-12 sm:mb-16 space-y-4"
        >
          {/* Eyebrow */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C]">
            <Radio className="w-3.5 h-3.5" />
            <span className="text-xs font-semibold tracking-wider uppercase">
              VidhAI Telecom — Complete Call Flow
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            Agronomy over a phone call.
          </h2>

          {/* Description */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            Rural farmers interact with VidhAI directly through a regular phone call without an app or mobile data. Trace how voice streams through bidirectional WebSockets, regional speech recognition, conversational reasoning, and telephony playback.
          </p>
        </motion.div>

        {/* QUICK SEQUENCE BADGES SUMMARY BAR */}
        <div className="hidden lg:flex items-center justify-between p-3.5 rounded-2xl bg-white border border-[#E6ECE7] text-xs font-mono text-[#4F5D54] mb-8 overflow-x-auto shadow-xs">
          <span className="font-bold text-[#1B432C] uppercase tracking-wider text-[11px] shrink-0">
            Pipeline Sequence:
          </span>
          <div className="flex items-center gap-2 overflow-x-auto scrollbar-none">
            {TELECOM_STEPS.map((s, idx) => (
              <React.Fragment key={s.id}>
                <button
                  onClick={() => setActiveStepId(s.id)}
                  className={`px-2.5 py-1 rounded-lg transition-all cursor-pointer whitespace-nowrap text-[11px] ${
                    (hoveredStepId || activeStepId) === s.id
                      ? 'bg-[#1B432C] text-white font-bold'
                      : 'hover:bg-[#FAF8F5] text-[#18201B]'
                  }`}
                >
                  <span className="text-[#79877E] mr-1">{s.number}</span>
                  {s.shortTitle}
                </button>
                {idx < TELECOM_STEPS.length - 1 && (
                  <span className="text-[#C2D6C6]">→</span>
                )}
              </React.Fragment>
            ))}
          </div>
        </div>

        {/* ============================================================== */}
        {/* DESKTOP ARCHITECTURE VIEW (Visible on md/lg screens) */}
        {/* ============================================================== */}
        <div className="hidden md:block">
          <TelecomDesktopDiagram
            activeStepId={activeStepId}
            onSelectStep={setActiveStepId}
            hoveredStepId={hoveredStepId}
            onHoverStep={setHoveredStepId}
          />
        </div>

        {/* ============================================================== */}
        {/* MOBILE TIMELINE VIEW (Visible on small screens / Android) */}
        {/* ============================================================== */}
        <div className="block md:hidden">
          <TelecomMobileTimeline
            activeStepId={activeStepId}
            onSelectStep={setActiveStepId}
          />
        </div>

        {/* ============================================================== */}
        {/* TECHNOLOGY PROVIDER CARDS AREA */}
        {/* ============================================================== */}
        <TechProviderGrid highlightedTechIds={currentStep.relatedTechIds} />
      </div>
    </section>
  );
};
