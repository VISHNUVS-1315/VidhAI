'use client';

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  PhoneCall,
  UserCheck,
  AudioWaveform,
  FileText,
  Brain,
  Layers,
  Volume2,
  PhoneForwarded,
  ChevronDown,
  ArrowDown,
  CheckCircle2,
  LucideIcon,
} from 'lucide-react';
import { TELECOM_STEPS } from './telecomData';
import { TelecomStepData } from './types';
import { usePrefersReducedMotion } from '@/lib/motion';

const STEP_ICONS: Record<string, LucideIcon> = {
  '01': PhoneCall,
  '02': UserCheck,
  '03': AudioWaveform,
  '04': FileText,
  '05': Brain,
  '06': Layers,
  '07': Volume2,
  '08': PhoneForwarded,
};

interface TelecomMobileTimelineProps {
  activeStepId: string;
  onSelectStep: (stepId: string) => void;
}

export const TelecomMobileTimeline: React.FC<TelecomMobileTimelineProps> = ({
  activeStepId,
  onSelectStep,
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [expandedId, setExpandedId] = useState<string>('01');

  const toggleExpand = (id: string) => {
    const nextId = expandedId === id ? '' : id;
    setExpandedId(nextId);
    if (nextId) {
      onSelectStep(nextId);
    }
  };

  return (
    <div className="w-full max-w-full overflow-hidden space-y-4">
      <div className="text-center pb-2">
        <span className="text-xs font-mono text-[#1B432C] bg-[#E8F0EA] px-3 py-1 rounded-full font-semibold">
          Tap any stage to expand detailed telemetry
        </span>
      </div>

      <div className="relative pl-6 sm:pl-8 space-y-5 before:absolute before:left-3 sm:before:left-4 before:top-4 before:bottom-4 before:w-0.5 before:bg-[#E6ECE7]">
        {TELECOM_STEPS.map((step, idx) => {
          const Icon = STEP_ICONS[step.id] || PhoneCall;
          const isExpanded = expandedId === step.id;
          const isLast = idx === TELECOM_STEPS.length - 1;

          return (
            <div key={step.id} className="relative">
              {/* Timeline Indicator Node */}
              <div
                onClick={() => toggleExpand(step.id)}
                className={`absolute -left-6 sm:-left-8 top-3 w-6 h-6 sm:w-7 sm:h-7 rounded-full flex items-center justify-center cursor-pointer transition-all duration-300 z-10 ${
                  isExpanded
                    ? 'bg-[#1B432C] text-white ring-4 ring-[#E8F0EA] shadow-xs'
                    : 'bg-white border-2 border-[#E6ECE7] text-[#79877E] hover:border-[#1B432C]'
                }`}
              >
                <span className="text-[10px] font-mono font-bold">
                  {step.number}
                </span>
              </div>

              {/* Stage Card */}
              <div
                className={`rounded-2xl border transition-all duration-300 overflow-hidden bg-white ${
                  isExpanded
                    ? 'border-[#1B432C] shadow-md ring-1 ring-[#1B432C]/10'
                    : 'border-[#E6ECE7] hover:border-[#C2D6C6]'
                }`}
              >
                {/* Collapsible Header */}
                <button
                  type="button"
                  onClick={() => toggleExpand(step.id)}
                  className="w-full p-4 flex items-center justify-between text-left gap-3"
                  aria-expanded={isExpanded}
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div
                      className={`p-2 rounded-xl transition-colors shrink-0 ${
                        isExpanded
                          ? 'bg-[#E8F0EA] text-[#1B432C]'
                          : 'bg-[#FAF8F5] text-[#79877E]'
                      }`}
                    >
                      <Icon className="w-4 h-4" />
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-[10px] font-mono text-[#79877E] uppercase">
                          {step.actor}
                        </span>
                      </div>
                      <h4 className="font-bold text-sm text-[#18201B] truncate">
                        {step.stageName}
                      </h4>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <span className="text-[10px] font-mono text-[#1B432C] bg-[#E8F0EA] px-2 py-0.5 rounded hidden sm:inline-block">
                      {step.technicalBadge}
                    </span>
                    <ChevronDown
                      className={`w-4 h-4 text-[#79877E] transition-transform duration-300 ${
                        isExpanded ? 'rotate-180 text-[#1B432C]' : ''
                      }`}
                    />
                  </div>
                </button>

                {/* Expandable Body */}
                <AnimatePresence initial={false}>
                  {isExpanded && (
                    <motion.div
                      key={`content-${step.id}`}
                      initial={{ height: 0, opacity: prefersReducedMotion ? 1 : 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: prefersReducedMotion ? 1 : 0 }}
                      transition={{ duration: prefersReducedMotion ? 0.01 : 0.25, ease: 'easeInOut' }}
                      className="overflow-hidden"
                    >
                      <div className="px-4 pb-4 pt-1 space-y-3.5 border-t border-[#F0F4F1] text-xs">
                        <p className="text-[#4F5D54] leading-relaxed">
                          {step.summary}
                        </p>

                        {/* Branching actions if present */}
                        {step.branching && step.branching.length > 0 && (
                          <div className="space-y-2 p-3 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                            <span className="text-[10px] font-mono font-semibold uppercase text-[#1B432C]">
                              Decision Branching
                            </span>
                            {step.branching.map((branch, bIdx) => (
                              <div key={bIdx} className="space-y-0.5">
                                <div className="font-bold text-[#18201B] flex items-center gap-1.5">
                                  <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
                                  <span>{branch.label}</span>
                                </div>
                                <div className="text-[11px] text-[#4F5D54] pl-3">
                                  {branch.action}
                                </div>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Connected Providers */}
                        <div className="space-y-1.5 pt-1">
                          <span className="text-[10px] font-mono uppercase tracking-wider text-[#79877E]">
                            Integrated Providers
                          </span>
                          <div className="flex flex-wrap gap-1.5">
                            {step.providers.map((p, pIdx) => (
                              <div
                                key={pIdx}
                                className="px-2.5 py-1 rounded-lg bg-[#FAF8F5] border border-[#E6ECE7] text-[11px]"
                              >
                                <span className="font-semibold text-[#18201B]">{p.name}</span>
                                <span className="text-[#79877E] text-[10px] block">{p.role}</span>
                              </div>
                            ))}
                          </div>
                        </div>

                        {/* Step Details list */}
                        <div className="space-y-1 pt-1">
                          <span className="text-[10px] font-mono uppercase tracking-wider text-[#79877E]">
                            Pipeline Actions
                          </span>
                          <ul className="space-y-1.5 text-[11px] text-[#4F5D54]">
                            {step.details.map((detail, dIdx) => (
                              <li key={dIdx} className="flex items-start gap-1.5">
                                <span className="text-[#1B432C] font-bold">›</span>
                                <span>{detail}</span>
                              </li>
                            ))}
                          </ul>
                        </div>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              {/* Connecting Down Arrow between cards (mobile visual trail) */}
              {!isLast && (
                <div className="flex justify-center py-1">
                  <ArrowDown className="w-3.5 h-3.5 text-[#C2D6C6]" />
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
