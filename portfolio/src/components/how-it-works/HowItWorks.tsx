'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import { usePrefersReducedMotion } from '@/lib/motion';
import { PROCESS_STEPS, ProcessStep } from './ProcessStep';

export const HowItWorks: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();

  const containerVariants: Variants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: prefersReducedMotion ? 0 : 0.12,
        delayChildren: prefersReducedMotion ? 0 : 0.05,
      },
    },
  };

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

  const stepItemVariants: Variants = {
    hidden: { opacity: 0, y: prefersReducedMotion ? 0 : 16 },
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
      id="how-it-works"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-[#FAF8F5] border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        {/* SECTION HEADER */}
        <motion.div
          variants={headerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="text-center max-w-3xl mx-auto mb-14 sm:mb-16 lg:mb-20 space-y-4"
        >
          {/* Eyebrow */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
            <span className="text-xs font-semibold tracking-wider uppercase">
              HOW IT WORKS
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            From field telemetry to localized agronomic action.
          </h2>

          {/* Description */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            How VidhAI captures farmer input, routes it through an authenticated multi-tier AI gateway,
            and validates guidance against live mandi data in real time.
          </p>
        </motion.div>

        {/* DESKTOP TIMELINE (Horizontal Process: 01 -- 02 -- 03 -- 04) */}
        <div className="hidden md:block">
          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: '-50px' }}
            className="grid grid-cols-4 gap-6 lg:gap-8"
          >
            {PROCESS_STEPS.map((step, idx) => (
              <motion.div key={step.number} variants={stepItemVariants} className="h-full">
                <ProcessStep step={step} index={idx} total={PROCESS_STEPS.length} />
              </motion.div>
            ))}
          </motion.div>
        </div>

        {/* MOBILE TIMELINE (Vertical Process for Android & Smartphones) */}
        <div className="block md:hidden">
          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: '-40px' }}
            className="relative pl-7 sm:pl-8 space-y-8"
          >
            {/* Continuous Vertical Timeline Line */}
            <div
              className="absolute left-[13px] sm:left-[15px] top-3 bottom-3 w-[1.5px] bg-[#CDD9CF]"
              aria-hidden="true"
            />

            {PROCESS_STEPS.map((step, idx) => {
              const Icon = step.icon;
              return (
                <motion.div
                  key={step.number}
                  variants={stepItemVariants}
                  className="relative group pb-2"
                >
                  {/* Step Number Badge */}
                  <div className="mb-2">
                    <span className="font-mono text-xs font-bold text-[#1B432C] bg-[#E8F0EA] border border-[#C2D6C6] px-2 py-0.5 rounded-full inline-block">
                      {step.number}
                    </span>
                  </div>

                  {/* Vertical Node Dot (Positioned on the vertical line) */}
                  <div
                    className="absolute -left-[22px] sm:-left-[24px] top-1.5 w-6 h-6 rounded-full bg-white border-2 border-[#1B432C] flex items-center justify-center z-10 shadow-xs"
                    aria-hidden="true"
                  >
                    <div className="w-2 h-2 rounded-full bg-[#1B432C]" />
                  </div>

                  {/* Step Header: Icon + Title */}
                  <div className="flex items-start gap-2.5">
                    <div className="mt-0.5 p-1.5 rounded-lg bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] shrink-0">
                      <Icon className="w-4 h-4" />
                    </div>
                    <h3 className="text-base font-bold text-[#18201B] tracking-tight leading-snug">
                      {step.title}
                    </h3>
                  </div>

                  {/* Description */}
                  <p className="text-sm text-[#4F5D54] leading-relaxed mt-2.5 pl-0.5">
                    {step.description}
                  </p>

                  {/* Technical Proof Footnote */}
                  <div className="mt-3 pt-2.5 border-t border-[#E6ECE7]">
                    <span className="text-[11px] font-mono text-[#79877E] block leading-tight">
                      {step.technicalProof}
                    </span>
                  </div>
                </motion.div>
              );
            })}
          </motion.div>
        </div>
      </div>
    </section>
  );
};
