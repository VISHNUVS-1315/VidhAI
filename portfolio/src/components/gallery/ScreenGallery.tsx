'use client';

import React from 'react';
import { Badge } from '@/components/ui/Badge';
import { ScreenshotCascade } from '@/components/gallery/ScreenshotCascade';
import { ShieldCheck } from 'lucide-react';

export const ScreenGallery: React.FC = () => {
  return (
    <section id="screens" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Verified UI Proof
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Authentic application screens. <span className="text-emerald-400">Zero mockups.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Every screen below was captured directly from the compiled Android application build.
            We do not use redesigned Figma concept frames, AI-generated interfaces, or synthetic mockups to represent VidhAI.
          </p>
        </div>

        {/* Signature Motion: Screenshot Cascade */}
        <ScreenshotCascade />

        {/* Verification Note */}
        <div className="mt-8 flex items-center justify-center gap-2 text-xs text-[#A9BBAE]">
          <ShieldCheck className="w-4 h-4 text-emerald-400" />
          <span>Grounded in authentic Android captures documented in `src/data/screenshots.ts`</span>
        </div>
      </div>
    </section>
  );
};
