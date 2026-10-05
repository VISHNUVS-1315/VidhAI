'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PROJECT_CONFIG } from '@/data/project';
import { ShieldCheck, ChevronRight } from 'lucide-react';

export const ChallengesSection: React.FC = () => {
  const [activeChallenge, setActiveChallenge] = useState<number>(0);

  const challenges = PROJECT_CONFIG.challenges;
  const current = challenges[activeChallenge];

  return (
    <section id="engineering" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Engineering Decisions
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Engineering the <span className="text-emerald-400">real-world constraints.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Software built for rural agriculture must confront real friction: spotty connectivity,
            complex multi-lingual scripts, high AI inference latency, and chaotic market data.
            Here is how each challenge was engineered in VidhAI.
          </p>
        </div>

        {/* Interactive Master-Detail Layout */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start max-w-6xl mx-auto">
          {/* Left: Challenge Selector List */}
          <div className="lg:col-span-5 space-y-2">
            {challenges.map((item, idx) => {
              const isSelected = activeChallenge === idx;
              return (
                <button
                  key={idx}
                  onClick={() => setActiveChallenge(idx)}
                  className={`w-full p-4 rounded-2xl text-left border transition-all cursor-pointer flex items-center justify-between ${
                    isSelected
                      ? 'bg-[#1A3222] border-emerald-500/70 shadow-lg shadow-emerald-950/40 ring-1 ring-emerald-500/30'
                      : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/30'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <span
                      className={`text-xs font-mono font-bold w-6 h-6 rounded-lg flex items-center justify-center ${
                        isSelected
                          ? 'bg-emerald-950 text-emerald-400 border border-emerald-500/50'
                          : 'bg-[#0B170E] text-[#718776] border border-[#1E3626]'
                      }`}
                    >
                      0{idx + 1}
                    </span>
                    <span className="text-xs font-bold text-[#F1F7F2] truncate max-w-[240px]">
                      {item.title}
                    </span>
                  </div>
                  <ChevronRight
                    className={`w-4 h-4 transition-transform ${
                      isSelected ? 'text-emerald-400 translate-x-1' : 'text-[#718776]'
                    }`}
                  />
                </button>
              );
            })}
          </div>

          {/* Right: Challenge Detailed Inspector */}
          <div className="lg:col-span-7 sticky top-24">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-6">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div>
                  <span className="text-[10px] font-mono uppercase text-emerald-400 font-semibold block mb-1">
                    Constraint Case 0{activeChallenge + 1}
                  </span>
                  <h3 className="text-xl font-bold text-[#F1F7F2]">{current.title}</h3>
                </div>
                <Badge variant="verified" size="sm">
                  Engineered Approach
                </Badge>
              </div>

              {/* The Real-World Constraint */}
              <div className="p-4 rounded-2xl bg-red-950/20 border border-red-900/40 space-y-1.5">
                <span className="text-xs font-mono uppercase text-red-300 font-semibold block">
                  The Real-World Constraint
                </span>
                <p className="text-xs sm:text-sm text-[#F1F7F2] leading-relaxed">
                  {current.constraint}
                </p>
              </div>

              {/* The Engineering Solution */}
              <div className="p-4 rounded-2xl bg-emerald-950/30 border border-emerald-500/40 space-y-1.5">
                <span className="text-xs font-mono uppercase text-emerald-400 font-semibold block">
                  The Engineering Response
                </span>
                <p className="text-xs sm:text-sm text-[#F1F7F2] leading-relaxed">
                  {current.solution}
                </p>
              </div>

              {/* Implementation Trace */}
              <div className="p-3.5 rounded-xl bg-[#0B170E] border border-[#233E2B] space-y-1">
                <span className="text-[10px] font-mono uppercase text-[#718776] block">
                  Codebase Implementation Trace
                </span>
                <p className="text-xs font-mono text-emerald-300">{current.implementation}</p>
              </div>

              <div className="pt-2 flex items-center justify-between text-xs text-[#718776]">
                <div className="flex items-center gap-1.5 text-emerald-400">
                  <ShieldCheck className="w-4 h-4" />
                  <span>Audited against active repository branch</span>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
