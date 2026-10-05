'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Server,
  Cpu,
  Layers,
  PhoneCall,
  Volume2,
  Database,
  Cloud,
  Code2,
  Radio,
  Sparkles,
} from 'lucide-react';
import { TELECOM_TECHNOLOGIES } from './telecomData';
import { TelecomTechnology } from './types';
import { usePrefersReducedMotion } from '@/lib/motion';

interface TechProviderGridProps {
  highlightedTechIds?: string[];
}

const CATEGORIES = [
  'All',
  'Telephony & Streaming',
  'Speech-to-Text',
  'Conversational AI',
  'Voice Synthesis',
  'Connected Services',
  'Core Runtime & Cloud',
] as const;

export const TechProviderGrid: React.FC<TechProviderGridProps> = ({
  highlightedTechIds = [],
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [selectedCategory, setSelectedCategory] = useState<string>('All');

  const filteredTechnologies =
    selectedCategory === 'All'
      ? TELECOM_TECHNOLOGIES
      : TELECOM_TECHNOLOGIES.filter((t) => t.category === selectedCategory);

  return (
    <div className="w-full space-y-6 pt-12 sm:pt-16 border-t border-[#E6ECE7]">
      {/* HEADER */}
      <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] mb-3">
            <Sparkles className="w-3.5 h-3.5" />
            <span className="text-xs font-semibold tracking-wider uppercase">
              Technology Stack
            </span>
          </div>
          <h3 className="text-2xl sm:text-3xl font-extrabold text-[#18201B] tracking-tight">
            Technology Behind VidhAI Telecom
          </h3>
          <p className="text-sm sm:text-base text-[#4F5D54] mt-1 max-w-2xl font-normal">
            Every layer in the telephony voice pipeline is powered by specialized infrastructure, regional acoustic engines, and connected agricultural APIs.
          </p>
        </div>

        <span className="text-xs font-mono text-[#79877E] self-start sm:self-auto bg-white px-3 py-1.5 rounded-full border border-[#E6ECE7]">
          {TELECOM_TECHNOLOGIES.length} Verified Providers
        </span>
      </div>

      {/* CATEGORY FILTER PILLS */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
        {CATEGORIES.map((cat) => {
          const isActive = selectedCategory === cat;
          return (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition-all duration-200 cursor-pointer ${
                isActive
                  ? 'bg-[#1B432C] text-white shadow-xs'
                  : 'bg-white text-[#4F5D54] border border-[#E6ECE7] hover:border-[#1B432C] hover:text-[#18201B]'
              }`}
            >
              {cat}
            </button>
          );
        })}
      </div>

      {/* TECH CARDS GRID */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
        {filteredTechnologies.map((tech) => {
          const isHighlighted = highlightedTechIds.includes(tech.id);

          return (
            <motion.div
              key={tech.id}
              layout
              initial={{ opacity: prefersReducedMotion ? 1 : 0, scale: prefersReducedMotion ? 1 : 0.98 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: prefersReducedMotion ? 0.01 : 0.2 }}
              className={`p-5 rounded-2xl bg-white border transition-all duration-300 flex flex-col justify-between ${
                isHighlighted
                  ? 'border-[#1B432C] ring-2 ring-[#1B432C]/10 shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] bg-[#F4F9F5]'
                  : 'border-[#E6ECE7] hover:border-[#C2D6C6] hover:shadow-xs'
              }`}
            >
              <div>
                <div className="flex items-start justify-between gap-2 mb-2.5">
                  <h4 className="font-bold text-sm sm:text-base text-[#18201B] tracking-tight">
                    {tech.name}
                  </h4>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-md bg-[#FAF8F5] border border-[#E6ECE7] text-[#4F5D54] shrink-0 font-medium">
                    {tech.badge}
                  </span>
                </div>

                <p className="text-xs sm:text-sm text-[#4F5D54] leading-relaxed">
                  {tech.purpose}
                </p>
              </div>

              <div className="pt-3 mt-3 border-t border-[#F0F4F1] flex items-center justify-between">
                <span className="text-[10px] font-mono text-[#79877E]">
                  {tech.category}
                </span>
                {isHighlighted && (
                  <span className="text-[10px] font-mono text-[#1B432C] font-semibold flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C] animate-ping" />
                    Active In Flow
                  </span>
                )}
              </div>
            </motion.div>
          );
        })}
      </div>
    </div>
  );
};
