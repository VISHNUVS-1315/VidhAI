'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Variants } from 'framer-motion';
import { usePrefersReducedMotion } from '@/lib/motion';
import { ProductScreenshot, type ProductScreenshotData } from './ProductScreenshot';

const SHOWCASE_SCREENS: ProductScreenshotData[] = [
  {
    id: 'farmer-home',
    file: '/screenshots/farmer-home.jpg',
    title: 'Compiled Android Application',
    category: 'Compiled Android Application',
    description:
      'Clean VidhAI application launch screen featuring the official sprout insignia, centered title, and Agriculture Ecosystem brand architecture running on a compiled Android build.',
    width: 896,
    height: 1200,
    featured: true,
  },
  {
    id: 'ai-assistant',
    file: '/screenshots/ai-assistant.jpg',
    title: 'Contextual AI Farm Assistant',
    category: 'Conversational Intelligence',
    description:
      'ChatGPT-style drawer conversation interface demonstrating contextual farm anchoring, Groq fast streaming text response, and voice speech-to-text input capability.',
    width: 1376,
    height: 768,
  },
  {
    id: 'tools-dashboard',
    file: '/screenshots/tools-dashboard.jpg',
    title: 'Agricultural Tools Suite',
    category: 'Field Utilities & Calculators',
    description:
      'Integrated utilities launcher featuring Crop Recommendation, Foliage Disease Detection, Mandi Price Explorer, and Fertilizer Calculators.',
    width: 1376,
    height: 768,
  },
  {
    id: 'government-schemes',
    file: '/screenshots/government-schemes.jpg',
    title: 'Government Schemes Directory',
    category: 'Subsidies & Applications',
    description:
      'Genuine Android screen cataloging verified Central and State government agricultural schemes, criteria filters, and direct application links.',
    width: 768,
    height: 1376,
  },
];

export const ProductShowcase: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [selectedId, setSelectedId] = useState<string>(SHOWCASE_SCREENS[0].id);

  const mainScreen =
    SHOWCASE_SCREENS.find((s) => s.id === selectedId) || SHOWCASE_SCREENS[0];
  const supportingScreens = SHOWCASE_SCREENS.filter((s) => s.id !== mainScreen.id);

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
      id="showcase"
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
              PRODUCT SHOWCASE
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            A closer look at VidhAI in action.
          </h2>

          {/* Description */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            Explore authentic application interfaces captured directly from the compiled Android build,
            demonstrating contextual agronomy, live telemetry, and government scheme access.
          </p>
        </motion.div>

        {/* DESKTOP LAYOUT (Main Screen on top + Supporting screens below) */}
        <div className="hidden md:block">
          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: '-40px' }}
            className="space-y-8"
          >
            {/* MAIN VIDHAI SCREEN */}
            <motion.div variants={itemVariants} className="max-w-4xl mx-auto">
              <AnimatePresence mode="wait">
                <motion.div
                  key={mainScreen.id}
                  initial={{ opacity: prefersReducedMotion ? 1 : 0, y: prefersReducedMotion ? 0 : 8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: prefersReducedMotion ? 1 : 0, y: prefersReducedMotion ? 0 : -8 }}
                  transition={{ duration: prefersReducedMotion ? 0.01 : 0.3 }}
                >
                  <ProductScreenshot screenshot={mainScreen} isMain={true} />
                </motion.div>
              </AnimatePresence>
            </motion.div>

            {/* SUPPORTING SCREENS GRID */}
            <div>
              <div className="flex items-center justify-between mb-4">
                <span className="text-xs font-semibold uppercase tracking-wider text-[#79877E]">
                  Supporting Application Modules (Click to focus)
                </span>
                <span className="text-xs text-[#1B432C] font-medium">
                  {supportingScreens.length} additional verified modules
                </span>
              </div>
              <div className="grid grid-cols-3 gap-6">
                {supportingScreens.map((screen) => (
                  <motion.div key={screen.id} variants={itemVariants}>
                    <ProductScreenshot
                      screenshot={screen}
                      isMain={false}
                      onClick={() => setSelectedId(screen.id)}
                      isActive={selectedId === screen.id}
                    />
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        </div>

        {/* ANDROID / MOBILE LAYOUT (Vertical Gallery: Main ↓ Supporting ↓ Supporting) */}
        <div className="block md:hidden">
          <motion.div
            variants={containerVariants}
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: '-40px' }}
            className="space-y-6"
          >
            {SHOWCASE_SCREENS.map((screen, idx) => (
              <motion.div key={screen.id} variants={itemVariants}>
                <ProductScreenshot
                  screenshot={screen}
                  isMain={idx === 0}
                />
              </motion.div>
            ))}
          </motion.div>
        </div>
      </div>
    </section>
  );
};
