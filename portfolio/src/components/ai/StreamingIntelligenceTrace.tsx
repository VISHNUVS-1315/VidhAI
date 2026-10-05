'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { Sprout, Cpu, Sparkles, ArrowRight, Zap } from 'lucide-react';

export const StreamingIntelligenceTrace: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeStep, setActiveStep] = useState<number>(1);

  const steps = [
    {
      id: 0,
      title: 'Farm Context Ingestion',
      subtitle: 'Farm name, soil type, water, crop records',
      tag: 'Step 1: Context Builder',
      latency: '12ms',
      icon: <Sprout className="w-4 h-4 text-emerald-400" />,
      detail: 'Bundles 4.5ac red loamy coordinates, borewell telemetry, and last groundnut cycle.',
    },
    {
      id: 1,
      title: 'Intent & Model Routing',
      subtitle: 'Groq (Conversational) vs NIM (Agronomy)',
      tag: 'Step 2: Express AI Gateway',
      latency: '45ms',
      icon: <Cpu className="w-4 h-4 text-emerald-300" />,
      detail: 'Classifies query: conversational advice routed to Groq; complex pest diagnosis to NIM Nemotron.',
    },
    {
      id: 2,
      title: 'Actionable Field Strategy',
      subtitle: 'Multilingual stream + on-device TTS',
      tag: 'Step 3: Verified Output',
      latency: '180ms TTFT',
      icon: <Sparkles className="w-4 h-4 text-amber-300" />,
      detail: 'Streams structured dosage instructions into Flutter client with speech synthesis ready.',
    },
  ];

  return (
    <div className="p-6 rounded-3xl bg-[#122217] border border-[#233E2B] glow-card mb-10 overflow-hidden relative">
      {/* Background signal wire */}
      <div className="flex items-center justify-between border-b border-[#233E2B] pb-4 mb-6">
        <div className="flex items-center gap-2">
          <Zap className="w-4 h-4 text-emerald-400" />
          <span className="text-xs font-mono uppercase text-emerald-400 font-semibold tracking-wider">
            Signature Motion Pattern: Streaming Intelligence Trace
          </span>
        </div>
        <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-950 border border-emerald-500/30 text-[10px] font-mono text-emerald-300">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span>Real-time Thinking Path</span>
        </div>
      </div>

      {/* 3-Step Pipeline Flow */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 relative">
        {steps.map((step, idx) => {
          const isActive = activeStep === step.id;
          return (
            <div
              key={step.id}
              onClick={() => setActiveStep(step.id)}
              className={`p-4 rounded-2xl border transition-all duration-300 cursor-pointer relative ${
                isActive
                  ? 'bg-emerald-950/70 border-emerald-500/60 shadow-[0_0_20px_rgba(76,175,108,0.2)]'
                  : 'bg-[#0B170E] border-[#233E2B] hover:border-emerald-600/40'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] font-mono text-emerald-400 uppercase font-semibold">
                  {step.tag}
                </span>
                <span className="text-[10px] font-mono text-[#718776]">{step.latency}</span>
              </div>

              <div className="flex items-center gap-2 mb-1.5">
                <div className="p-1.5 rounded-lg bg-[#14261A] border border-[#233E2B]">
                  {step.icon}
                </div>
                <h4 className="text-xs font-bold text-[#F1F7F2]">{step.title}</h4>
              </div>

              <p className="text-[11px] text-[#A9BBAE] leading-relaxed mb-3">{step.detail}</p>

              {/* Progress Pulse Bar */}
              <div className="h-1 w-full bg-[#182F20] rounded-full overflow-hidden">
                <div
                  className={`h-full bg-emerald-400 rounded-full ${
                    prefersReducedMotion ? 'w-full' : 'animate-pulse w-full'
                  }`}
                />
              </div>

              {idx < 2 && (
                <div className="hidden md:block absolute -right-3.5 top-1/2 -translate-y-1/2 z-10 text-emerald-500/60 pointer-events-none">
                  <ArrowRight className="w-4 h-4" />
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
