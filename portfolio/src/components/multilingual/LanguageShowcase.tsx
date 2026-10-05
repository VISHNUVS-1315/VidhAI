'use client';

import React from 'react';
import { Badge } from '@/components/ui/Badge';
import { LanguageBloom } from '@/components/multilingual/LanguageBloom';
import { ShieldCheck } from 'lucide-react';

export const LanguageShowcase: React.FC = () => {
  return (
    <section id="multilingual" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            13-Language Localization
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            13 languages. <span className="text-emerald-400">One unified experience.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Language barriers isolate millions of Indian farmers from modern agricultural technology.
            VidhAI features a complete custom localization engine with 13 official vernaculars and
            bi-directional RTL layout support for Urdu.
          </p>
        </div>

        {/* Signature Motion: Language Bloom */}
        <LanguageBloom />

        {/* Verification Note */}
        <div className="mt-8 flex items-center justify-center gap-2 text-xs text-[#A9BBAE]">
          <ShieldCheck className="w-4 h-4 text-emerald-400" />
          <span>Verified: 13 translation files in `lib/locale/translations/` with bi-directional text support</span>
        </div>
      </div>
    </section>
  );
};
