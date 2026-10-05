'use client';

import React from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';

interface DataWeaveTransitionProps {
  label?: string;
  sourceContext?: string;
  targetContext?: string;
}

export const DataWeaveTransition: React.FC<DataWeaveTransitionProps> = ({
  label = 'CONVERGING INTELLIGENCE FLOW',
  sourceContext,
  targetContext,
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();

  return (
    <div className="relative py-8 bg-[#0B170E] overflow-hidden border-y border-[#182C1E]/60 select-none">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative">
        {/* Subtle braided SVG conduits */}
        <div className="h-16 w-full flex items-center justify-center relative">
          <svg
            className="w-full h-full max-w-4xl opacity-80"
            viewBox="0 0 800 64"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <defs>
              <linearGradient id="weave-grad-1" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="#2E7D32" stopOpacity="0.2" />
                <stop offset="50%" stopColor="#4CAF50" stopOpacity="0.9" />
                <stop offset="100%" stopColor="#2E7D32" stopOpacity="0.2" />
              </linearGradient>
              <linearGradient id="weave-grad-2" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stopColor="#1E3E26" stopOpacity="0.1" />
                <stop offset="50%" stopColor="#81C784" stopOpacity="0.8" />
                <stop offset="100%" stopColor="#1E3E26" stopOpacity="0.1" />
              </linearGradient>
            </defs>

            {/* Braided Line 1: Top to Bottom to Center */}
            <path
              d="M 50 12 C 250 12, 350 52, 400 32 C 450 12, 550 52, 750 52"
              stroke="url(#weave-grad-1)"
              strokeWidth="1.5"
              strokeDasharray={prefersReducedMotion ? 'none' : '6 4'}
              className={prefersReducedMotion ? '' : 'animate-signal'}
            />

            {/* Braided Line 2: Bottom to Top to Center */}
            <path
              d="M 50 52 C 250 52, 350 12, 400 32 C 450 52, 550 12, 750 12"
              stroke="url(#weave-grad-2)"
              strokeWidth="1.5"
              strokeDasharray={prefersReducedMotion ? 'none' : '4 6'}
              className={prefersReducedMotion ? '' : 'animate-signal'}
            />

            {/* Central Convergence Node */}
            <circle cx="400" cy="32" r="4" fill="#4CAF50" />
            <circle
              cx="400"
              cy="32"
              r="9"
              stroke="#4CAF50"
              strokeWidth="1"
              strokeOpacity="0.5"
              className={prefersReducedMotion ? '' : 'animate-ping'}
            />

            {/* Micro Intersect Nodes */}
            <circle cx="200" cy="32" r="2" fill="#81C784" fillOpacity="0.7" />
            <circle cx="600" cy="32" r="2" fill="#81C784" fillOpacity="0.7" />
          </svg>

          {/* Central Technical Chip */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center gap-2 px-3 py-1 rounded-full bg-[#0A140D]/90 border border-[#233E2B] text-[10px] font-mono tracking-widest text-[#A9BBAE] uppercase backdrop-blur-sm">
            {sourceContext && <span className="text-[#718776]">{sourceContext}</span>}
            {sourceContext && <span className="text-emerald-400">→</span>}
            <span className="text-emerald-300 font-semibold">{label}</span>
            {targetContext && <span className="text-emerald-400">→</span>}
            {targetContext && <span className="text-[#718776]">{targetContext}</span>}
          </div>
        </div>
      </div>
    </div>
  );
};
