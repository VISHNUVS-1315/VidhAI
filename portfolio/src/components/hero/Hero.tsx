'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import { Button } from '@/components/ui/Button';
import { PhoneFrame } from '@/components/ui/PhoneFrame';
import { GithubIcon } from '@/components/ui/GithubIcon';
import { PROJECT_CONFIG } from '@/data/project';
import { usePrefersReducedMotion } from '@/lib/motion';
import { ArrowRight, Sprout, CheckCircle2 } from 'lucide-react';

export const Hero: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();

  const containerVariants: Variants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: prefersReducedMotion ? 0 : 0.08,
        delayChildren: prefersReducedMotion ? 0 : 0.04,
      },
    },
  };

  const itemVariants: Variants = {
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

  const scrollToSection = (id: string) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <section
      id="home"
      className="relative pt-24 sm:pt-28 md:pt-32 pb-16 sm:pb-20 md:pb-24 overflow-hidden topo-pattern-subtle"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          animate="visible"
          className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-8 items-center"
        >
          {/* LEFT COLUMN: Branding, Headline, Description, CTAs (approx 45-50% width on desktop) */}
          <div className="lg:col-span-6 flex flex-col items-start text-left space-y-5 sm:space-y-6">
            {/* 1. Vidhai Branding Badge */}
            <motion.div variants={itemVariants}>
              <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border border-[#E6ECE7] text-[#1B432C] shadow-sm">
                <span className="w-2 h-2 rounded-full bg-[#1B432C]" />
                <Sprout className="w-3.5 h-3.5 text-[#1B432C]" />
                <span className="text-xs font-semibold tracking-wide">
                  VidhAI · AI-Powered Agriculture Ecosystem
                </span>
              </div>
            </motion.div>

            {/* 2. Headline */}
            <motion.div variants={itemVariants} className="space-y-2">
              <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-[64px] font-extrabold text-[#18201B] tracking-tight leading-[1.08]">
                Intelligence for{' '}
                <span className="text-[#1B432C] font-serif font-normal italic">
                  every field.
                </span>
              </h1>
            </motion.div>

            {/* 3. Description */}
            <motion.p
              variants={itemVariants}
              className="text-base sm:text-lg text-[#4F5D54] max-w-xl leading-relaxed font-normal"
            >
              {PROJECT_CONFIG.subtagline}
            </motion.p>

            {/* 4. CTA Buttons */}
            <motion.div
              variants={itemVariants}
              className="flex flex-wrap items-center gap-3 pt-1 w-full sm:w-auto"
            >
              <Button
                variant="primary"
                size="lg"
                onClick={() => scrollToSection('features')}
                className="w-full sm:w-auto"
              >
                <span>View Project</span>
                <ArrowRight className="w-4 h-4 ml-1.5" />
              </Button>

              {PROJECT_CONFIG.repositoryUrl && (
                <a
                  href={PROJECT_CONFIG.repositoryUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full sm:w-auto min-h-[48px] inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-white hover:bg-[#F4F6F4] text-[#18201B] border border-[#E2E8F0] text-sm font-semibold transition-all duration-200 shadow-sm hover:shadow"
                >
                  <GithubIcon className="w-4 h-4 text-[#4F5D54]" />
                  <span>GitHub</span>
                </a>
              )}
            </motion.div>

            {/* Subtle Verified Metrics Strip */}
            <motion.div
              variants={itemVariants}
              className="pt-3 flex flex-wrap items-center gap-y-2 gap-x-5 text-xs text-[#79877E]"
            >
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[#1B432C]" />
                <span className="font-medium text-[#18201B]">13 Indian Languages</span>
              </div>
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[#1B432C]" />
                <span className="font-medium text-[#18201B]">Groq + NVIDIA NIM</span>
              </div>
              <div className="flex items-center gap-1.5">
                <CheckCircle2 className="w-3.5 h-3.5 text-[#1B432C]" />
                <span className="font-medium text-[#18201B]">AGMARKNET 2.0 Normalized</span>
              </div>
            </motion.div>
          </div>

          {/* RIGHT COLUMN / MOBILE BOTTOM: Product Preview (approx 50-55% width on desktop) */}
          <motion.div
            variants={itemVariants}
            className="lg:col-span-6 w-full flex flex-col items-center justify-center pt-2 lg:pt-0"
          >
            <div className="relative w-full max-w-[320px] sm:max-w-[340px] md:max-w-[360px] mx-auto">
              {/* Subtle back ambient glow card */}
              <div className="absolute -inset-2 rounded-[42px] bg-gradient-to-b from-[#E8F0EA] to-[#F4F0E8] -z-10 blur-sm opacity-70 transform rotate-1" />

              {/* Central Genuine Phone Frame */}
              <PhoneFrame
                src="/screenshots/farmer-home.jpg"
                alt="VidhAI Compiled Android Application Screen"
                priority
                statusBadge="Compiled Android Application"
              />
            </div>

            <div className="mt-4 text-center">
              <span className="text-xs font-mono text-[#79877E]">
                Genuine Android capture · Compiled Application
              </span>
            </div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
};
