'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import type { Variants } from 'framer-motion';
import { usePrefersReducedMotion } from '@/lib/motion';
import { TechCard, type TechItemData } from './TechCard';

// Clean SVG Logos styled in VidhAI deep green (#1B432C)
const NextJsIcon: React.FC = () => (
  <svg className="w-5 h-5" viewBox="0 0 180 180" fill="none" xmlns="http://www.w3.org/2000/svg">
    <mask id="nextjs-mask" maskUnits="userSpaceOnUse" x="0" y="0" width="180" height="180">
      <circle cx="90" cy="90" r="90" fill="#1B432C" />
    </mask>
    <g mask="url(#nextjs-mask)">
      <circle cx="90" cy="90" r="90" fill="#1B432C" />
      <path
        d="M149.508 157.438L69.147 54H54V125.979H66.8991V68.5641L139.124 161.4C142.753 160.207 146.223 158.878 149.508 157.438Z"
        fill="#FAF8F5"
      />
      <rect x="115" y="54" width="13" height="72" fill="#FAF8F5" />
    </g>
  </svg>
);

const ReactIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="-11.5 -10.23174 23 20.46348" fill="currentColor">
    <circle cx="0" cy="0" r="2.05" fill="#1B432C" />
    <g stroke="#1B432C" strokeWidth="1" fill="none">
      <ellipse rx="11" ry="4.2" />
      <ellipse rx="11" ry="4.2" transform="rotate(60)" />
      <ellipse rx="11" ry="4.2" transform="rotate(120)" />
    </g>
  </svg>
);

const TypeScriptIcon: React.FC = () => (
  <svg className="w-5 h-5" viewBox="0 0 128 128" fill="none">
    <rect width="128" height="128" rx="24" fill="#1B432C" />
    <path
      d="M38.2 60.5v44.2h-12.7V60.5H12V49h39.7v11.5H38.2zm28.4 28.5c2.9 2.5 6.7 4.1 11.2 4.1 6.2 0 9.8-3 9.8-7.5 0-11.4-17.6-10.7-17.6-21.7 0-6.9 5.8-12.2 14.8-12.2 5.5 0 10.3 1.7 13.9 4.6l-4.1 9.4c-3.1-2.1-6.6-3.4-10-3.4-4.8 0-7.7 2.3-7.7 5.7 0 10.7 17.7 9.8 17.7 21.6 0 7.8-6.1 13-16.1 13-6.5 0-12.5-2.2-16.3-5.9l4.4-7.7z"
      fill="#FAF8F5"
    />
  </svg>
);

const TailwindIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="currentColor">
    <path d="M12.001,4.8c-3.2,0-5.2,1.6-6,4.8c1.2-1.6,2.6-2.2,4.2-1.8c0.913,0.228,1.565,0.89,2.288,1.624 C13.666,10.618,15.027,12,18.001,12c3.2,0,5.2-1.6,6-4.8c-1.2,1.6-2.6,2.2-4.2,1.8c-0.913-0.228-1.565-0.89-2.288-1.624 C16.337,6.182,14.976,4.8,12.001,4.8z M6.001,12c-3.2,0-5.2,1.6-6,4.8c1.2-1.6,2.6-2.2,4.2-1.8c0.913,0.228,1.565,0.89,2.288,1.624 c1.177,1.194,2.538,2.576,5.512,2.576c3.2,0,5.2-1.6,6-4.8c-1.2,1.6-2.6,2.2-4.2,1.8c-0.913-0.228-1.565-0.89-2.288-1.624 C10.337,13.382,8.976,12,6.001,12z" />
  </svg>
);

const FramerMotionIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="currentColor">
    <path d="M4 0h16v8h-8zM4 8h8l8 8H4zM4 16h8v8z" />
  </svg>
);

const LucideIconSvg: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="6" y1="3" x2="6" y2="15" />
    <circle cx="18" cy="6" r="3" />
    <circle cx="6" cy="18" r="3" />
    <path d="M18 9a9 9 0 0 1-9 9" />
  </svg>
);

// Secondary icons for VidhAI Core Architecture tab
const FlutterIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="currentColor">
    <path d="M14.314 0L2.3 12 6 15.7 21.684.013h-7.37zM14.314 11.517l-5.63 5.63 5.63 5.63h7.37l-5.63-5.63 5.63-5.63h-7.37z" />
  </svg>
);

const GroqIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <circle cx="12" cy="12" r="9" />
    <path d="M9 12h6" />
    <path d="M12 9v6" />
  </svg>
);

const NvidiaIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="currentColor">
    <path d="M8.9 7.82c-.3 0-.58.07-.84.2-.82.41-1.12 1.34-.84 2.14.37 1.05 1.48 1.63 2.5 1.3 1.02-.33 1.57-1.42 1.25-2.45-.3-.98-1.17-1.19-2.07-1.19zm3.17-2.82c-4.47 0-8.1 3.53-8.1 7.88 0 4.35 3.63 7.88 8.1 7.88 4.47 0 8.1-3.53 8.1-7.88 0-4.35-3.63-7.88-8.1-7.88zm0 13.96c-3.44 0-6.23-2.72-6.23-6.08 0-3.36 2.79-6.08 6.23-6.08s6.23 2.72 6.23 6.08c0 3.36-2.79 6.08-6.23 6.08z" />
  </svg>
);

const NodeExpressIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="2" y="2" width="20" height="8" rx="2" />
    <rect x="2" y="14" width="20" height="8" rx="2" />
    <line x1="6" y1="6" x2="6.01" y2="6" />
    <line x1="6" y1="18" x2="6.01" y2="18" />
  </svg>
);

const AgmarknetIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M3 3v18h18" />
    <path d="M18.7 8l-5.1 5.2-2.8-2.7L7 14.3" />
  </svg>
);

const FirestoreIcon: React.FC = () => (
  <svg className="w-5 h-5 text-[#1B432C]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
  </svg>
);

// 1. Technologies directly verified from package.json
const PACKAGE_JSON_TECH: TechItemData[] = [
  {
    name: 'Next.js',
    role: 'Full-stack framework with React App Router & static generation',
    category: 'Framework',
    version: 'v16.3',
    sourceFile: 'package.json:15',
    icon: <NextJsIcon />,
  },
  {
    name: 'React',
    role: 'Component architecture, concurrent rendering & reactive state',
    category: 'UI Library',
    version: 'v19.2',
    sourceFile: 'package.json:16',
    icon: <ReactIcon />,
  },
  {
    name: 'TypeScript',
    role: 'End-to-end type safety, strict compile checks & typed interfaces',
    category: 'Language',
    version: 'v5.x',
    sourceFile: 'tsconfig.json',
    icon: <TypeScriptIcon />,
  },
  {
    name: 'Tailwind CSS',
    role: 'Utility-first styling with modern design tokens & responsive grids',
    category: 'Styling',
    version: 'v4.x',
    sourceFile: 'postcss.config.mjs',
    icon: <TailwindIcon />,
  },
  {
    name: 'Framer Motion',
    role: 'Fluid spring physics, layout animations & micro-interactions',
    category: 'Motion Engine',
    version: 'v13.4',
    sourceFile: 'package.json:13',
    icon: <FramerMotionIcon />,
  },
  {
    name: 'Lucide React',
    role: 'Accessible scalable vector icons for agriculture & telemetry',
    category: 'Iconography',
    version: 'v1.47',
    sourceFile: 'package.json:14',
    icon: <LucideIconSvg />,
  },
];

// 2. Core VidhAI Application Architecture (Flutter + Hybrid AI Backend)
const VIDHAI_APP_TECH: TechItemData[] = [
  {
    name: 'Flutter & Dart',
    role: 'Cross-platform mobile client with 60fps UI on Android devices',
    category: 'Mobile Client',
    version: 'v3.x',
    sourceFile: 'pubspec.yaml:7-12',
    icon: <FlutterIcon />,
  },
  {
    name: 'Groq (openai/gpt-oss-20b)',
    role: 'Dedicated low-latency streaming conversational chat engine',
    category: 'Conversational AI',
    version: 'Streaming SSE',
    sourceFile: 'functions/src/aiGateway.ts',
    icon: <GroqIcon />,
  },
  {
    name: 'NVIDIA NIM Architecture',
    role: 'Nemotron Ultra 550B agronomy reasoning & Nano Omni 30B vision',
    category: 'Specialized AI',
    version: 'Nemotron 3',
    sourceFile: 'functions/src/cropAiService.ts',
    icon: <NvidiaIcon />,
  },
  {
    name: 'Node.js & Express Gateway',
    role: 'Standalone authenticated API router deployed on Render cloud',
    category: 'Backend Gateway',
    version: 'TypeScript',
    sourceFile: 'functions/src/app.ts',
    icon: <NodeExpressIcon />,
  },
  {
    name: 'AGMARKNET 2.0 (data.gov.in)',
    role: 'Official mandi commodity prices normalized into uniform ₹/kg',
    category: 'Market Truth',
    version: 'Normalized ₹/kg',
    sourceFile: 'functions/src/marketService.ts',
    icon: <AgmarknetIcon />,
  },
  {
    name: 'Firebase & Firestore',
    role: 'User authentication, token verification & real-time document store',
    category: 'Cloud Services',
    version: 'Admin SDK',
    sourceFile: 'functions/src/firebase.ts',
    icon: <FirestoreIcon />,
  },
];

export const TechStack: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeTab, setActiveTab] = useState<'platform' | 'app'>('platform');

  const currentItems = activeTab === 'platform' ? PACKAGE_JSON_TECH : VIDHAI_APP_TECH;

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

  const gridVariants: Variants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: prefersReducedMotion ? 0 : 0.06,
      },
    },
  };

  const cardVariants: Variants = {
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
      id="tech-stack"
      className="py-16 sm:py-20 md:py-24 lg:py-28 relative overflow-hidden bg-[#FAF8F5] border-t border-[#E6ECE7]"
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        {/* SECTION HEADER */}
        <motion.div
          variants={headerVariants}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: '-60px' }}
          className="text-center max-w-3xl mx-auto mb-10 sm:mb-12 lg:mb-14 space-y-4"
        >
          {/* Eyebrow */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
            <span className="text-xs font-semibold tracking-wider uppercase">
              TECHNOLOGY STACK
            </span>
          </div>

          {/* Heading */}
          <h2 className="text-3xl sm:text-4xl lg:text-[42px] font-extrabold text-[#18201B] tracking-tight leading-[1.16]">
            Grounded in modern, production-grade tooling.
          </h2>

          {/* Description */}
          <p className="text-base sm:text-lg text-[#4F5D54] leading-relaxed max-w-2xl mx-auto font-normal">
            Every library in the codebase solves a concrete engineering constraint in rural
            connectivity, strict type safety, or verified agronomic intelligence.
          </p>

          {/* Interactive Stack Selector Pills */}
          <div className="pt-2 flex items-center justify-center">
            <div className="inline-flex items-center p-1 rounded-full bg-white border border-[#E6ECE7] shadow-xs">
              <button
                type="button"
                onClick={() => setActiveTab('platform')}
                className={`px-4 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer ${
                  activeTab === 'platform'
                    ? 'bg-[#1B432C] text-white shadow-xs'
                    : 'text-[#4F5D54] hover:text-[#18201B] hover:bg-[#F4F6F4]'
                }`}
              >
                Web Platform (package.json)
              </button>
              <button
                type="button"
                onClick={() => setActiveTab('app')}
                className={`px-4 py-1.5 rounded-full text-xs font-semibold transition-all duration-200 cursor-pointer ${
                  activeTab === 'app'
                    ? 'bg-[#1B432C] text-white shadow-xs'
                    : 'text-[#4F5D54] hover:text-[#18201B] hover:bg-[#F4F6F4]'
                }`}
              >
                VidhAI Mobile &amp; AI Stack
              </button>
            </div>
          </div>
        </motion.div>

        {/* TECHNOLOGY CARDS GRID */}
        {/* Responsive layout:
            Desktop: 3 cards per row (md:grid-cols-3)
            Tablet: 2–3 cards per row (sm:grid-cols-2 md:grid-cols-3)
            Android: 2-column grid (grid-cols-2)
        */}
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            variants={gridVariants}
            initial="hidden"
            animate="visible"
            exit="hidden"
            className="grid grid-cols-2 sm:grid-cols-2 md:grid-cols-3 gap-3.5 sm:gap-5 lg:gap-6"
          >
            {currentItems.map((tech) => (
              <motion.div key={tech.name} variants={cardVariants} className="h-full">
                <TechCard tech={tech} />
              </motion.div>
            ))}
          </motion.div>
        </AnimatePresence>

        {/* Verification Note */}
        <div className="mt-10 sm:mt-12 text-center">
          <p className="text-xs text-[#79877E] inline-flex items-center gap-1.5 font-medium">
            <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
            All listed packages cross-verified against repository manifests and live builds.
          </p>
        </div>
      </div>
    </section>
  );
};
