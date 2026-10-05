'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import { Cpu, Database, Layers, Languages } from 'lucide-react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { HighlightCard, type HighlightItemData } from './HighlightCard';

const PROJECT_HIGHLIGHTS_DATA: HighlightItemData[] = [
  {
    icon: Cpu,
    category: 'AI Integration',
    title: 'Dual-Tier AI Routing Gateway',
    explanation:
      'Directs conversational chat queries to Groq (openai/gpt-oss-20b) for fast streaming responses, while routing complex agronomic planning and pest diagnosis to NVIDIA NIM Nemotron models.',
    sourceProof: 'functions/src/aiGateway.ts',
  },
  {
    icon: Database,
    category: 'API Integration',
    title: 'Normalized Mandi Price Telemetry',
    explanation:
      'Ingests live commodity feeds from the official data.gov.in AGMARKNET 2.0 API, automatically converts non-standard trade units into uniform ₹/kg, and maintains a 1-hour snapshot cache.',
    sourceProof: 'functions/src/marketService.ts',
  },
  {
    icon: Layers,
    category: 'Architecture',
    title: 'Offline-First Farm Workspace',
    explanation:
      'Persists user profiles, multi-parcel land boundaries, crop records, and recent market prices in SharedPreferences so rural farmers can review data even during field signal blackouts.',
    sourceProof: 'lib/services/offline_service.dart',
  },
  {
    icon: Languages,
    category: 'User Experience',
    title: '13 Vernacular Languages & Urdu RTL',
    explanation:
      'Engineered complete localization across 13 Indian regional languages with bidirectional layout switching for Urdu, supplemented by speech-to-text input and native audio speech synthesis.',
    sourceProof: 'lib/l10n/ & pubspec.yaml',
  },
];

export const ProjectHighlights: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();

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

  const containerVariants: Variants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: prefersReducedMotion ? 0 : 0.08,
      },
    },
  };

  const itemVariants: Variants = {
    hidden: { opacity: 0, y: prefersReducedMotion ? 0 : 12 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: prefersReducedMotion ? 0.01 : 0.4,
        ease: 'easeOut',
      },
    },
  };

  return (
    <section
      id="highlights"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-[#FAF8F5] border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        {/* SECTION HEADER */}
        <motion.div
          variants={headerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="text-center max-w-3xl mx-auto mb-12 sm:mb-14 lg:mb-16 space-y-4"
        >
          {/* Eyebrow */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
            <span className="text-xs font-semibold tracking-wider uppercase">
              PROJECT HIGHLIGHTS
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            Architectural decisions behind VidhAI.
          </h2>

          {/* Description */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            Key technical implementations engineered to solve real-world constraints in rural
            connectivity, inference latency, and multilingual agricultural access.
          </p>
        </motion.div>

        {/* HIGHLIGHT CARDS GRID */}
        {/* Responsive layout:
            Desktop: 4 columns (lg:grid-cols-4)
            Tablet: 2x2 grid (sm:grid-cols-2 lg:grid-cols-4)
            Android / Mobile: 1 card per row (grid-cols-1)
        */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-40px' }}
          className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 sm:gap-6"
        >
          {PROJECT_HIGHLIGHTS_DATA.map((highlight) => (
            <motion.div key={highlight.title} variants={itemVariants} className="h-full">
              <HighlightCard highlight={highlight} />
            </motion.div>
          ))}
        </motion.div>

        {/* Verification Footer Note */}
        <div className="mt-12 text-center">
          <p className="text-xs text-[#79877E] inline-flex items-center gap-1.5 font-medium">
            <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
            Every claim grounded in repository files documented in the Verified Claims Matrix.
          </p>
        </div>
      </div>
    </section>
  );
};
