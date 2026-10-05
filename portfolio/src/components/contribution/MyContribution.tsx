'use client';

import React from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PROJECT_CONFIG } from '@/data/project';
import {
  Compass,
  Smartphone,
  Cpu,
  Server,
  Database,
  Eye,
  ShieldCheck,
} from 'lucide-react';

const CATEGORY_ICONS: Record<string, React.ReactNode> = {
  'Product & System Design': <Compass className="w-5 h-5 text-emerald-400" />,
  'Flutter Development': <Smartphone className="w-5 h-5 text-emerald-300" />,
  'AI Integration': <Cpu className="w-5 h-5 text-purple-400" />,
  'Backend/API Integration': <Server className="w-5 h-5 text-amber-400" />,
  'Agricultural Data Integration': <Database className="w-5 h-5 text-blue-400" />,
  'UI/UX & Accessibility Iteration': <Eye className="w-5 h-5 text-cyan-400" />,
};

export const MyContribution: React.FC = () => {
  const contributions = PROJECT_CONFIG.creator.confirmedContributions || [];

  return (
    <section id="contributions" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <div className="flex items-center justify-center gap-2">
            <Badge variant="verified" size="sm">
              Author Attribution
            </Badge>
            <Badge variant="neutral" size="sm">
              Confirmed Scope
            </Badge>
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            My <span className="text-emerald-400">Contribution.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            A clear and honest separation of the lead creator&apos;s confirmed architectural,
            engineering, and design contributions from overall project scope.
          </p>
        </div>

        {/* 6 Contribution Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-10">
          {contributions.map((item, idx) => (
            <Card
              key={idx}
              className="p-6 bg-[#122217] border-[#233E2B] hover:border-emerald-500/40 transition-all flex flex-col justify-between space-y-4"
            >
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <div className="p-2.5 rounded-xl bg-[#0B170E] border border-[#233E2B]">
                    {CATEGORY_ICONS[item.category] || <ShieldCheck className="w-5 h-5 text-emerald-400" />}
                  </div>
                  <span className="text-[10px] font-mono uppercase text-emerald-400 font-semibold px-2 py-0.5 rounded-full bg-emerald-950/80 border border-emerald-500/30">
                    Confirmed
                  </span>
                </div>

                <h3 className="text-base font-bold text-[#F1F7F2]">
                  {item.category}
                </h3>

                <p className="text-xs text-[#A9BBAE] leading-relaxed">
                  {item.summary}
                </p>
              </div>

              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-[11px] font-mono text-[#718776]">
                <span className="text-emerald-400 block mb-0.5 font-semibold">Evidence:</span>
                <span className="text-[#A9BBAE]">{item.evidence}</span>
              </div>
            </Card>
          ))}
        </div>

        {/* Veracity Assurance Note */}
        <div className="max-w-3xl mx-auto p-4 rounded-xl bg-[#0B170E] border border-[#233E2B] flex items-center justify-center gap-2 text-xs text-[#718776] text-center">
          <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
          <span>
            Only displaying contributions explicitly confirmed and authored by {PROJECT_CONFIG.creator.name} ({PROJECT_CONFIG.creator.handle}).
          </span>
        </div>
      </div>
    </section>
  );
};
