'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import {
  Bot,
  Sprout,
  TrendingUp,
  Languages,
  CloudSun,
  Database,
} from 'lucide-react';
import { FeatureCard } from './FeatureCard';
import { usePrefersReducedMotion } from '@/lib/motion';

interface FeatureItem {
  icon: typeof Bot;
  category: string;
  title: string;
  description: string;
}

const FEATURES: FeatureItem[] = [
  {
    icon: Bot,
    category: 'Conversational AI',
    title: 'Conversational Farm Assistant',
    description:
      'Dedicated low-latency streaming chat powered by Groq (openai/gpt-oss-20b) with dynamic farm context injection, speech-to-text input, and native speech synthesis.',
  },
  {
    icon: Sprout,
    category: 'Agronomy Reasoning',
    title: 'Agronomic Reasoning & Diagnosis',
    description:
      'Multi-factor crop planning, rotation advice, and leaf symptom inspection orchestrating NVIDIA NIM Nemotron Ultra 550B and multimodal vision models.',
  },
  {
    icon: TrendingUp,
    category: 'Market Intelligence',
    title: 'Mandi Market Intelligence',
    description:
      'Official AGMARKNET 2.0 price feeds normalized into standardized ₹/kg with historical trends and localized commodity tracking.',
  },
  {
    icon: Languages,
    category: 'Accessibility',
    title: '13 Indian Languages & Urdu RTL',
    description:
      'Complete vernacular interface across 13 Indian regional languages with dedicated bidirectional RTL layout support for Urdu.',
  },
  {
    icon: CloudSun,
    category: 'Telemetry',
    title: 'Hyperlocal Weather Telemetry',
    description:
      'Hourly rain forecasts, temperature tracking, and precipitation alerts from Open-Meteo integrated directly into farm task schedules.',
  },
  {
    icon: Database,
    category: 'Field Reliability',
    title: 'Offline-First Farm Workspace',
    description:
      'Multi-parcel land mapping and task management backed by SharedPreferences local caching for reliable access during field signal loss.',
  },
];

export const FeaturesSection: React.FC = () => {
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
      id="features"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-white border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        {/* Section Header */}
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
              Key Features
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            Purpose-built intelligence for every farming stage.
          </h2>

          {/* Subtitle */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            Every feature in VidhAI is engineered directly from verified repository source
            code to resolve critical challenges across agronomic guidance, price transparency,
            and rural connectivity.
          </p>
        </motion.div>

        {/* Feature Grid: 3 cols desktop, 2 cols tablet, 1 col mobile */}
        <motion.div
          variants={containerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 sm:gap-7 lg:gap-8"
        >
          {FEATURES.map((feature) => (
            <FeatureCard
              key={feature.title}
              icon={feature.icon}
              category={feature.category}
              title={feature.title}
              description={feature.description}
            />
          ))}
        </motion.div>
      </div>
    </section>
  );
};
