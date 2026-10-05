import React from 'react';
import Image from '@/components/ui/PortfolioImage';
import { ExternalLink, Terminal, ShieldCheck } from 'lucide-react';
import { PROJECT_CONFIG } from '@/data/project';

export const Footer: React.FC = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="border-t border-[#233E2B] bg-[#0A140D] pt-14 pb-10 text-[#A9BBAE]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-12">
          {/* Col 1: Brand & Tagline */}
          <div className="md:col-span-2 space-y-3">
            <div className="flex items-center gap-3">
              <div className="relative w-8 h-8 rounded-lg overflow-hidden bg-emerald-950/80 border border-emerald-500/40 p-1">
                <Image
                  src="/brand/vidhai-logo.png"
                  alt="VidhAI Emblem"
                  width={28}
                  height={28}
                  className="object-contain"
                />
              </div>
              <span className="font-bold text-xl text-[#F1F7F2]">{PROJECT_CONFIG.name}</span>
            </div>
            <p className="text-sm text-[#A9BBAE] max-w-md leading-relaxed">
              {PROJECT_CONFIG.subtagline}
            </p>
            <div className="flex items-center gap-2 pt-2 text-xs text-emerald-400 font-medium">
              <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
              <span>Verified implementation grounded in Flutter, Node.js & Groq/NVIDIA NIM.</span>
            </div>
          </div>

          {/* Col 2: Architecture Layers */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#F1F7F2] mb-3">
              Architecture
            </h4>
            <ul className="space-y-2 text-xs">
              <li>Flutter 3.19+ & BLoC</li>
              <li>Groq gpt-oss-20b Chat</li>
              <li>NVIDIA Nemotron Ultra 550B</li>
              <li>AGMARKNET 2.0 (₹/kg)</li>
              <li>Open-Meteo Weather API</li>
              <li>Render Standalone Express</li>
            </ul>
          </div>

          {/* Col 3: Links & Creator */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#F1F7F2] mb-3">
              Engineering Credit
            </h4>
            <div className="text-xs space-y-2">
              <p className="text-[#F1F7F2] font-medium">
                Lead Architect: {PROJECT_CONFIG.creator.name} ({PROJECT_CONFIG.creator.handle})
              </p>
              <p className="text-[#A9BBAE]">
                {PROJECT_CONFIG.builtFor}
              </p>
              <a
                href={PROJECT_CONFIG.repositoryUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-emerald-400 hover:text-emerald-300 transition-colors pt-2"
              >
                <Terminal className="w-3.5 h-3.5" />
                <span>Private Source Repository</span>
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="pt-8 border-t border-[#1E3626] flex flex-col sm:flex-row items-center justify-between gap-4 text-xs">
          <p>© {currentYear} VidhAI Project Team. All rights reserved.</p>
          <p className="text-center sm:text-right text-[#718776]">
            Genuine Project Case Study • Source-Code Audited Architecture
          </p>
        </div>
      </div>
    </footer>
  );
};
