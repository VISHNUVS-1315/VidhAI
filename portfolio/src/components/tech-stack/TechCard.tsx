'use client';

import React from 'react';

export interface TechItemData {
  name: string;
  role: string;
  category: string;
  version?: string;
  sourceFile?: string;
  icon: React.ReactNode;
}

interface TechCardProps {
  tech: TechItemData;
}

/**
 * Clean technology card for the Technology Stack section.
 * Adheres to VidhAI visual standards: white surface, subtle border,
 * deep green accents, and case-study typography.
 */
export const TechCard: React.FC<TechCardProps> = ({ tech }) => {
  return (
    <div className="group relative rounded-2xl bg-white border border-[#E6ECE7] p-4 sm:p-5 lg:p-6 text-[#18201B] shadow-[0_1px_3px_rgba(24,32,27,0.03)] transition-all duration-200 hover:border-[#C2D6C6] hover:shadow-[0_6px_20px_-4px_rgba(27,67,44,0.07)] hover:-translate-y-0.5 flex flex-col justify-between h-full">
      <div>
        {/* Top bar: Icon + Category/Version Badge */}
        <div className="flex items-center justify-between gap-2 mb-3.5 sm:mb-4">
          <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-[#E8F0EA] border border-[#C2D6C6] flex items-center justify-center text-[#1B432C] group-hover:scale-105 transition-transform duration-200 shrink-0">
            {tech.icon}
          </div>
          {tech.version && (
            <span className="text-[10px] sm:text-[11px] font-mono font-medium text-[#5A6B60] bg-[#FAF8F5] border border-[#E6ECE7] px-2 py-0.5 rounded-md">
              {tech.version}
            </span>
          )}
        </div>

        {/* Technology Name */}
        <h3 className="text-sm sm:text-base lg:text-lg font-bold text-[#18201B] tracking-tight group-hover:text-[#1B432C] transition-colors leading-snug">
          {tech.name}
        </h3>

        {/* Short Role / Description */}
        <p className="text-xs sm:text-sm text-[#4F5D54] leading-relaxed mt-1 sm:mt-1.5 font-normal">
          {tech.role}
        </p>
      </div>

      {/* Bottom Footer: Source Reference & Verified Indicator */}
      <div className="mt-4 pt-3 border-t border-[#F0F4F1] flex items-center justify-between text-[10px] sm:text-[11px] text-[#79877E]">
        <span className="font-mono text-[#6A7B70] truncate max-w-[120px] sm:max-w-none">
          {tech.sourceFile || tech.category}
        </span>
        <span className="text-[#1B432C] font-semibold flex items-center gap-1 shrink-0">
          <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
          Verified
        </span>
      </div>
    </div>
  );
};
