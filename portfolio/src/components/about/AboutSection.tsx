'use client';

import React from 'react';
import Image from '@/components/ui/PortfolioImage';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import {
  Layers,
  Cpu,
  Globe,
  Smartphone,
  TrendingUp,
  Database,
  Languages,
  CheckCircle2,
} from 'lucide-react';
import { PROJECT_CONFIG } from '@/data/project';
import { usePrefersReducedMotion } from '@/lib/motion';

export const AboutSection: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();

  const containerVariants: Variants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: prefersReducedMotion ? 0 : 0.08,
        delayChildren: prefersReducedMotion ? 0 : 0.05,
      },
    },
  };

  const itemVariants: Variants = {
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
      id="about"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-[#FAF8F5] border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="grid grid-cols-1 lg:grid-cols-12 gap-10 lg:gap-12 items-center"
        >
          {/* LEFT COLUMN: Eyebrow, Heading, Description, Supporting Points */}
          <div className="lg:col-span-7 flex flex-col items-start space-y-6">
            {/* 1. Eyebrow */}
            <motion.div variants={itemVariants}>
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C]">
                <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
                <span className="text-xs font-semibold tracking-wider uppercase">
                  About VidhAI
                </span>
              </div>
            </motion.div>

            {/* 2. Large Heading */}
            <motion.div variants={itemVariants}>
              <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
                A unified digital backbone for modern Indian agriculture.
              </h2>
            </motion.div>

            {/* 3. Concise Description (2-4 sentences explaining what VidhAI actually does) */}
            <motion.p
              variants={itemVariants}
              className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl font-normal"
            >
              VidhAI is an AI-powered agricultural ecosystem engineered to bridge fragmented
              farming workflows into a single cohesive platform. It connects real-time
              agronomic reasoning, hyperlocal weather telemetry, AGMARKNET mandi pricing, and
              farm workspace management into one responsive mobile application. Built specifically
              for Indian farmers and buyers, it delivers localized intelligence across 13 Indian
              languages with offline-resilient local caching.
            </motion.p>

            {/* 4. Supporting Points (compact, professional, based on actual VidhAI functionality) */}
            <motion.div
              variants={itemVariants}
              className="w-full pt-2 grid grid-cols-1 sm:grid-cols-3 gap-4"
            >
              {/* Point 1: Purpose */}
              <div className="flex flex-col p-4 rounded-xl bg-white border border-[#E6ECE7] shadow-[0_1px_3px_rgba(24,32,27,0.03)] space-y-2">
                <div className="w-8 h-8 rounded-lg bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] flex items-center justify-center">
                  <Layers className="w-4 h-4 text-[#1B432C]" />
                </div>
                <h3 className="text-sm font-bold text-[#18201B] tracking-tight">
                  Unified Consoles
                </h3>
                <p className="text-xs text-[#4F5D54] leading-relaxed">
                  Dedicated Farmer and Consumer consoles sharing unified land and market intelligence.
                </p>
              </div>

              {/* Point 2: Solution */}
              <div className="flex flex-col p-4 rounded-xl bg-white border border-[#E6ECE7] shadow-[0_1px_3px_rgba(24,32,27,0.03)] space-y-2">
                <div className="w-8 h-8 rounded-lg bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] flex items-center justify-center">
                  <Cpu className="w-4 h-4 text-[#1B432C]" />
                </div>
                <h3 className="text-sm font-bold text-[#18201B] tracking-tight">
                  Tiered AI Gateway
                </h3>
                <p className="text-xs text-[#4F5D54] leading-relaxed">
                  Low-latency Groq streaming chat paired with NVIDIA NIM models for deep agronomic reasoning.
                </p>
              </div>

              {/* Point 3: Experience */}
              <div className="flex flex-col p-4 rounded-xl bg-white border border-[#E6ECE7] shadow-[0_1px_3px_rgba(24,32,27,0.03)] space-y-2">
                <div className="w-8 h-8 rounded-lg bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] flex items-center justify-center">
                  <Globe className="w-4 h-4 text-[#1B432C]" />
                </div>
                <h3 className="text-sm font-bold text-[#18201B] tracking-tight">
                  Vernacular & Offline
                </h3>
                <p className="text-xs text-[#4F5D54] leading-relaxed">
                  13 Indian vernaculars with Urdu RTL layout and SharedPreferences local caching for field use.
                </p>
              </div>
            </motion.div>
          </div>

          {/* RIGHT COLUMN: Visual Card using real project information & architectural facts */}
          <motion.div
            variants={itemVariants}
            className="lg:col-span-5 w-full flex flex-col items-center"
          >
            <div className="w-full max-w-lg rounded-2xl bg-white border border-[#E6ECE7] p-6 sm:p-7 shadow-[0_4px_24px_-4px_rgba(24,32,27,0.06)] relative overflow-hidden">
              {/* Card Header */}
              <div className="flex items-center justify-between pb-5 border-b border-[#E6ECE7]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-[#E8F0EA] border border-[#C2D6C6] flex items-center justify-center p-1.5">
                    <Image
                      src="/brand/vidhai-logo.png"
                      alt="VidhAI"
                      width={28}
                      height={28}
                      className="object-contain"
                    />
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-[#18201B] tracking-tight">
                      VidhAI Architecture
                    </h4>
                    <span className="text-[11px] font-mono text-[#79877E]">
                      System Fact Sheet
                    </span>
                  </div>
                </div>

                <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[10px] font-semibold text-[#1B432C]">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
                  <span>v1.0.0+1 Build</span>
                </div>
              </div>

              {/* Factual Specification Rows */}
              <div className="py-4 space-y-3.5">
                <div className="flex items-start gap-3 text-xs">
                  <div className="w-6 h-6 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] flex items-center justify-center text-[#1B432C] shrink-0 mt-0.5">
                    <Smartphone className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-[#18201B]">Client Architecture: </span>
                    <span className="text-[#4F5D54]">
                      Flutter cross-platform client with BLoC and Provider state separation.
                    </span>
                  </div>
                </div>

                <div className="flex items-start gap-3 text-xs">
                  <div className="w-6 h-6 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] flex items-center justify-center text-[#1B432C] shrink-0 mt-0.5">
                    <Cpu className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-[#18201B]">Dual AI Routing: </span>
                    <span className="text-[#4F5D54]">
                      Groq (openai/gpt-oss-20b) streaming dialogue + NVIDIA NIM agronomic reasoning.
                    </span>
                  </div>
                </div>

                <div className="flex items-start gap-3 text-xs">
                  <div className="w-6 h-6 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] flex items-center justify-center text-[#1B432C] shrink-0 mt-0.5">
                    <TrendingUp className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-[#18201B]">Market Normalization: </span>
                    <span className="text-[#4F5D54]">
                      AGMARKNET 2.0 government data automatically converted to uniform ₹/kg.
                    </span>
                  </div>
                </div>

                <div className="flex items-start gap-3 text-xs">
                  <div className="w-6 h-6 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] flex items-center justify-center text-[#1B432C] shrink-0 mt-0.5">
                    <Database className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-[#18201B]">Offline Resilience: </span>
                    <span className="text-[#4F5D54]">
                      SharedPreferences local caching ensures farm data remains accessible offline.
                    </span>
                  </div>
                </div>

                <div className="flex items-start gap-3 text-xs">
                  <div className="w-6 h-6 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] flex items-center justify-center text-[#1B432C] shrink-0 mt-0.5">
                    <Languages className="w-3.5 h-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-[#18201B]">Vernacular Reach: </span>
                    <span className="text-[#4F5D54]">
                      13 Indian regional languages with bidirectional layout support for Urdu RTL.
                    </span>
                  </div>
                </div>
              </div>

              {/* Bottom Metrics Pill Strip */}
              <div className="pt-4 border-t border-[#E6ECE7] grid grid-cols-2 sm:grid-cols-4 gap-2 text-center">
                <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                  <div className="text-base font-extrabold text-[#1B432C]">13</div>
                  <div className="text-[10px] text-[#79877E] font-medium">Languages</div>
                </div>
                <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                  <div className="text-base font-extrabold text-[#1B432C]">43</div>
                  <div className="text-[10px] text-[#79877E] font-medium">App Screens</div>
                </div>
                <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                  <div className="text-base font-extrabold text-[#1B432C]">2</div>
                  <div className="text-[10px] text-[#79877E] font-medium">Consoles</div>
                </div>
                <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                  <div className="text-base font-extrabold text-[#1B432C]">₹/kg</div>
                  <div className="text-[10px] text-[#79877E] font-medium">Price Standard</div>
                </div>
              </div>

              {/* Factual Note */}
              <div className="mt-4 pt-3 border-t border-[#E6ECE7] flex items-center justify-between text-[11px] text-[#79877E]">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-[#1B432C]" />
                  <span>Verified Repository Source Code</span>
                </span>
                <span className="font-mono text-[10px] text-[#4F5D54]">
                  {PROJECT_CONFIG.backendDeployment.split(' ')[0]} Backend
                </span>
              </div>
            </div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
};
