'use client';

import React from 'react';
import { Smartphone, ShieldCheck, Cpu, CheckCircle2, type LucideIcon } from 'lucide-react';

export interface ProcessStepData {
  number: string;
  icon: LucideIcon;
  title: string;
  description: string;
  technicalProof: string;
}

export const PROCESS_STEPS: ProcessStepData[] = [
  {
    number: '01',
    icon: Smartphone,
    title: 'Farmer Input & Field Telemetry',
    description:
      'The farmer submits a query via voice audio, crop leaf photo, or text. The client automatically injects GPS coordinates, soil profile, and live Open-Meteo weather telemetry into a typed context snapshot.',
    technicalProof: 'Voice STT · Foliage Vision · Open-Meteo API',
  },
  {
    number: '02',
    icon: ShieldCheck,
    title: 'Gateway Auth & Intent Dispatch',
    description:
      'Transmitted over HTTPS to VidhAI’s standalone Express gateway on Render. Firebase Admin validates user tokens, and an intent classifier analyzes agronomic complexity to select the optimal inference tier.',
    technicalProof: 'Express Gateway · Firebase Admin · Intent Router',
  },
  {
    number: '03',
    icon: Cpu,
    title: 'Hybrid AI & Mandi Ground Truth',
    description:
      'Conversational dialogue streams via Groq (openai/gpt-oss-20b), while deep crop planning and foliage diagnosis route to NVIDIA NIM Nemotron models alongside live AGMARKNET 2.0 mandi feeds normalized to ₹/kg.',
    technicalProof: 'Groq Streaming · NVIDIA NIM · AGMARKNET 2.0',
  },
  {
    number: '04',
    icon: CheckCircle2,
    title: 'Localized Delivery & Offline Sync',
    description:
      'Validated recommendations return in the farmer’s native tongue across 13 Indian languages with audio speech synthesis. Farm tasks and mandi price bulletins are cached in SharedPreferences for low-connectivity fields.',
    technicalProof: '13 Indian Languages · TTS Audio · Offline Cache',
  },
];

interface ProcessStepProps {
  step: ProcessStepData;
  index: number;
  total: number;
}

/**
 * Reusable ProcessStep component representing a single workflow milestone.
 */
export const ProcessStep: React.FC<ProcessStepProps> = ({ step, index, total }) => {
  const Icon = step.icon;
  const isLast = index === total - 1;

  return (
    <div className="flex flex-col h-full relative group">
      {/* 1. Step Number */}
      <div className="mb-2">
        <span className="font-mono text-xs font-bold text-[#1B432C] bg-[#E8F0EA] border border-[#C2D6C6] px-2.5 py-0.5 rounded-full inline-block">
          {step.number}
        </span>
      </div>

      {/* 2. Timeline Node & Connecting Line (Desktop) */}
      <div className="relative flex items-center my-3">
        {/* Connecting line to the right */}
        {!isLast && (
          <div
            className="hidden md:block absolute left-4 right-0 top-1/2 -translate-y-1/2 h-[1.5px] bg-[#CDD9CF] z-0"
            aria-hidden="true"
          />
        )}
        {/* Connecting line to the left if not first */}
        {index > 0 && (
          <div
            className="hidden md:block absolute left-0 right-1/2 top-1/2 -translate-y-1/2 h-[1.5px] bg-[#CDD9CF] z-0"
            aria-hidden="true"
          />
        )}

        {/* Node Circle */}
        <div
          className="relative z-10 w-8 h-8 rounded-full bg-white border-2 border-[#1B432C] flex items-center justify-center shadow-xs group-hover:scale-110 transition-transform duration-200"
          aria-hidden="true"
        >
          <div className="w-2.5 h-2.5 rounded-full bg-[#1B432C]" />
        </div>
      </div>

      {/* 3. Step Header: Icon + Title */}
      <div className="mt-3 flex items-start gap-2.5">
        <div className="mt-0.5 p-1.5 rounded-lg bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] shrink-0">
          <Icon className="w-4 h-4" />
        </div>
        <h3 className="text-base font-bold text-[#18201B] tracking-tight leading-snug">
          {step.title}
        </h3>
      </div>

      {/* 4. Description */}
      <p className="text-sm text-[#4F5D54] leading-relaxed mt-2.5 flex-1">
        {step.description}
      </p>

      {/* 5. Technical Footnote / Proof Badge */}
      <div className="mt-4 pt-3 border-t border-[#E6ECE7]">
        <span className="text-[11px] font-mono text-[#79877E] block leading-tight">
          {step.technicalProof}
        </span>
      </div>
    </div>
  );
};
