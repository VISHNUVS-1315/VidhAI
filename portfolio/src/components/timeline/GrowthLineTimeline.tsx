'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { PROJECT_CONFIG } from '@/data/project';
import { Sprout, CheckCircle2 } from 'lucide-react';

export const GrowthLineTimeline: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeMilestone, setActiveMilestone] = useState<number>(2);

  const milestones = PROJECT_CONFIG.timeline;

  return (
    <div className="relative max-w-4xl mx-auto py-6">
      {/* Central Growth Stem SVG */}
      <div className="relative">
        <div className="space-y-8 relative">
          {/* Vertical Stem Line */}
          <div className="absolute top-4 bottom-4 left-6 md:left-1/2 -translate-x-1/2 w-0.5 bg-gradient-to-b from-emerald-600 via-emerald-400 to-[#14261A] pointer-events-none" />

          {milestones.map((m, idx) => {
            const isLeft = idx % 2 === 0;
            const isSelected = activeMilestone === idx;

            return (
              <div
                key={idx}
                className={`flex flex-col md:flex-row items-start md:items-center gap-6 relative ${
                  isLeft ? 'md:flex-row-reverse' : ''
                }`}
              >
                {/* Milestone Content Card */}
                <div className="ml-14 md:ml-0 md:w-1/2">
                  <div
                    onClick={() => setActiveMilestone(idx)}
                    className={`p-5 rounded-2xl border transition-all duration-300 cursor-pointer text-left ${
                      isSelected
                        ? 'bg-[#14261A] border-emerald-400 shadow-[0_0_20px_rgba(76,175,108,0.25)] scale-[1.02]'
                        : 'bg-[#0E1C12]/90 border-[#233E2B] hover:border-emerald-600/50'
                    }`}
                  >
                    <div className="flex items-center justify-between gap-2 mb-2">
                      <span className="text-[10px] font-mono text-emerald-400 uppercase font-semibold">
                        {m.period}
                      </span>
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[#09130B] border border-[#233E2B] text-[#A9BBAE]">
                        {m.tag}
                      </span>
                    </div>

                    <h4 className="text-sm font-bold text-[#F1F7F2] mb-1.5">{m.title}</h4>
                    <p className="text-xs text-[#A9BBAE] leading-relaxed mb-3">{m.summary}</p>

                    <div className="space-y-1.5 pt-2 border-t border-[#1C3524]">
                      {m.details.map((detail, dIdx) => (
                        <div key={dIdx} className="flex items-start gap-2 text-[11px] text-[#C8E6C9]">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                          <span>{detail}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Central Branching Node */}
                <div
                  onClick={() => setActiveMilestone(idx)}
                  className="absolute left-6 md:left-1/2 -translate-x-1/2 w-8 h-8 rounded-full bg-[#0B170E] border-2 border-emerald-400 flex items-center justify-center cursor-pointer transition-transform duration-300 hover:scale-110 z-10 shadow-[0_0_15px_rgba(76,175,108,0.4)]"
                >
                  <Sprout
                    className={`w-4 h-4 text-emerald-300 ${
                      isSelected && !prefersReducedMotion ? 'animate-bounce' : ''
                    }`}
                  />
                </div>

                {/* Empty spacer for the other side */}
                <div className="hidden md:block md:w-1/2" />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
