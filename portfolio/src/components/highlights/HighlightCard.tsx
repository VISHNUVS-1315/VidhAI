'use client';

import React from 'react';
import type { LucideIcon } from 'lucide-react';

export interface HighlightItemData {
  icon: LucideIcon;
  category: string;
  title: string;
  explanation: string;
  sourceProof: string;
}

interface HighlightCardProps {
  highlight: HighlightItemData;
}

/**
 * Reusable HighlightCard component for the Project Highlights section.
 * Renders a clean white card with subtle borders, restrained shadows,
 * a small Lucide icon, bold title, and a verified 2-3 line explanation.
 */
export const HighlightCard: React.FC<HighlightCardProps> = ({ highlight }) => {
  const Icon = highlight.icon;

  return (
    <div className="group flex flex-col justify-between h-full rounded-2xl bg-white border border-[#E6ECE7] p-5 sm:p-6 text-[#18201B] shadow-[0_1px_3px_rgba(24,32,27,0.03)] transition-all duration-200 hover:border-[#C2D6C6] hover:shadow-[0_6px_20px_-4px_rgba(27,67,44,0.06)] hover:-translate-y-1">
      <div>
        {/* Top Header: Icon + Category Badge */}
        <div className="flex items-center justify-between gap-2 mb-4">
          <div className="w-10 h-10 rounded-xl bg-[#E8F0EA] border border-[#C2D6C6] flex items-center justify-center text-[#1B432C] group-hover:scale-105 transition-transform duration-200 shrink-0">
            <Icon className="w-5 h-5" />
          </div>
          <span className="text-[11px] font-mono text-[#5A6B60] bg-[#FAF8F5] border border-[#E6ECE7] px-2.5 py-0.5 rounded-full font-medium">
            {highlight.category}
          </span>
        </div>

        {/* Highlight Title */}
        <h3 className="text-base sm:text-lg font-bold text-[#18201B] tracking-tight group-hover:text-[#1B432C] transition-colors leading-snug">
          {highlight.title}
        </h3>

        {/* 2–3 Line Explanation */}
        <p className="text-xs sm:text-sm text-[#4F5D54] leading-relaxed mt-2 font-normal">
          {highlight.explanation}
        </p>
      </div>

      {/* Verified Source Reference Footnote */}
      <div className="mt-5 pt-3.5 border-t border-[#F0F4F1] flex items-center justify-between text-[11px] text-[#79877E]">
        <span className="font-mono text-[#6A7B70] truncate max-w-[140px] sm:max-w-none">
          {highlight.sourceProof}
        </span>
        <span className="text-[#1B432C] font-semibold flex items-center gap-1 shrink-0">
          <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
          Verified
        </span>
      </div>
    </div>
  );
};
