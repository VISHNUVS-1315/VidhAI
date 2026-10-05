'use client';

import React from 'react';
import { Badge } from '@/components/ui/Badge';
import { GrowthLineTimeline } from '@/components/timeline/GrowthLineTimeline';
import { ShieldCheck } from 'lucide-react';

export const ProjectTimeline: React.FC = () => {
  return (
    <section id="timeline" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Engineering Evolution
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Development timeline &amp; <span className="text-emerald-400">commit milestones.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Trace how VidhAI evolved from foundational Flutter state management to a hybrid AI gateway,
            normalized AGMARKNET mandi telemetry, and a bilateral community ecosystem.
          </p>
        </div>

        {/* Signature Motion: Growth Line Timeline */}
        <GrowthLineTimeline />

        {/* Verification Footer */}
        <div className="mt-12 flex items-center justify-center gap-2 text-xs text-[#A9BBAE]">
          <ShieldCheck className="w-4 h-4 text-emerald-400" />
          <span>Grounded in repository git history and commit progression</span>
        </div>
      </div>
    </section>
  );
};
