'use client';

import React from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { User, HelpCircle, ArrowRight, CheckCircle2, AlertTriangle, Layers, Sprout, MapPin, Languages, CloudSun } from 'lucide-react';

export const ContextVsGeneric: React.FC = () => {
  return (
    <section className="py-20 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <Badge variant="accent" size="sm">
            5-Second Architectural Contrast
          </Badge>
          <h2 className="text-3xl sm:text-4xl font-bold text-[#F1F7F2] tracking-tight">
            Generic AI vs. <span className="text-emerald-400">VidhAI Contextual Intelligence</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Generic chatbots offer textbook advice that ignores local realities. VidhAI builds a
            comprehensive context snapshot before routing queries.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-stretch">
          {/* Left: Generic AI Pipeline */}
          <Card className="bg-[#142218] border-red-900/40 p-6 sm:p-8 flex flex-col justify-between space-y-6">
            <div>
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4 mb-5">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-lg bg-red-950/60 border border-red-800/40 text-red-400">
                    <AlertTriangle className="w-5 h-5" />
                  </div>
                  <h3 className="text-base font-bold text-[#F1F7F2]">Generic AI Chatbot</h3>
                </div>
                <span className="text-xs font-mono text-red-400">Unaware of Field</span>
              </div>

              {/* Steps */}
              <div className="space-y-4">
                <div className="p-3.5 rounded-xl bg-[#0B170E] border border-[#233E2B] flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <User className="w-4 h-4 text-[#A9BBAE]" />
                    <span className="text-xs text-[#F1F7F2]">Farmer enters prompt</span>
                  </div>
                  <span className="text-[11px] text-[#718776]">&quot;How to fertilize tomato?&quot;</span>
                </div>

                <div className="flex justify-center text-[#718776]">
                  <ArrowRight className="w-4 h-4 rotate-90" />
                </div>

                <div className="p-3.5 rounded-xl bg-[#0B170E] border border-[#233E2B] flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <HelpCircle className="w-4 h-4 text-red-400" />
                    <span className="text-xs text-red-300">Monolithic AI Model</span>
                  </div>
                  <span className="text-[11px] text-[#718776]">No field telemetry</span>
                </div>

                <div className="flex justify-center text-[#718776]">
                  <ArrowRight className="w-4 h-4 rotate-90" />
                </div>

                <div className="p-4 rounded-xl bg-red-950/20 border border-red-900/50 text-xs text-[#A9BBAE] space-y-1.5">
                  <span className="font-semibold text-red-300 block">Generic Textbook Output:</span>
                  <p className="leading-relaxed">
                    &quot;Apply standard NPK 100:50:50 kg/ha evenly during land preparation.&quot;
                  </p>
                  <p className="text-[11px] text-red-400/80 italic pt-1">
                    Ignores soil type, water availability, irrigation method, and active crop records.
                  </p>
                </div>
              </div>
            </div>

            <div className="pt-4 border-t border-[#233E2B] text-xs text-[#718776]">
              Result: Suboptimal nutrient utilization and wasted capital.
            </div>
          </Card>

          {/* Right: VidhAI Contextual Intelligence Pipeline */}
          <Card className="bg-[#14261A] border-emerald-500/50 p-6 sm:p-8 flex flex-col justify-between space-y-6 glow-card">
            <div>
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4 mb-5">
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-lg bg-emerald-950 border border-emerald-500/50 text-emerald-400">
                    <CheckCircle2 className="w-5 h-5" />
                  </div>
                  <h3 className="text-base font-bold text-[#F1F7F2]">VidhAI Contextual System</h3>
                </div>
                <Badge variant="verified" size="sm">
                  Full Field Awareness
                </Badge>
              </div>

              {/* Context Injection Steps */}
              <div className="space-y-3">
                <div className="p-3.5 rounded-xl bg-[#0B170E] border border-emerald-500/30 space-y-2">
                  <div className="flex items-center justify-between text-xs font-semibold text-emerald-400 font-mono">
                    <div className="flex items-center gap-1.5">
                      <Layers className="w-3.5 h-3.5" />
                      <span>AIContextBuilder Snapshot Assembly</span>
                    </div>
                    <span>`lib/services/ai/ai_context_builder.dart`</span>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-[10px] font-mono text-[#F1F7F2]">
                    <div className="p-1.5 rounded bg-[#16291D] border border-[#233E2B] flex items-center gap-1">
                      <Sprout className="w-3 h-3 text-emerald-400" />
                      <span>Red Loamy</span>
                    </div>
                    <div className="p-1.5 rounded bg-[#16291D] border border-[#233E2B] flex items-center gap-1">
                      <MapPin className="w-3 h-3 text-blue-400" />
                      <span>Tiruppur, TN</span>
                    </div>
                    <div className="p-1.5 rounded bg-[#16291D] border border-[#233E2B] flex items-center gap-1">
                      <CloudSun className="w-3 h-3 text-amber-400" />
                      <span>Rain in 24h</span>
                    </div>
                    <div className="p-1.5 rounded bg-[#16291D] border border-[#233E2B] flex items-center gap-1">
                      <Languages className="w-3 h-3 text-purple-400" />
                      <span>Tamil / English</span>
                    </div>
                  </div>
                </div>

                <div className="flex justify-center text-emerald-400">
                  <ArrowRight className="w-4 h-4 rotate-90" />
                </div>

                <div className="p-3.5 rounded-xl bg-[#0B170E] border border-emerald-500/40 flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                    <span className="text-xs font-semibold text-emerald-300">
                      VidhAI Router & Function Calling
                    </span>
                  </div>
                  <span className="text-[11px] font-mono text-emerald-400">Groq + NVIDIA NIM</span>
                </div>

                <div className="flex justify-center text-emerald-400">
                  <ArrowRight className="w-4 h-4 rotate-90" />
                </div>

                <div className="p-4 rounded-xl bg-emerald-950/40 border border-emerald-500/40 text-xs text-[#F1F7F2] space-y-1.5">
                  <span className="font-semibold text-emerald-300 block">
                    Precision Field Guidance:
                  </span>
                  <p className="leading-relaxed">
                    &quot;For your 2.5 acre red loam on Day 34 (Flowering): Drip-fertigate 2.5 kg
                    19:19:19 NPK this morning. With 38mm rain expected tomorrow, halt foliar nitrogen
                    to avoid leaching.&quot;
                  </p>
                </div>
              </div>
            </div>

            <div className="pt-4 border-t border-[#233E2B] text-xs text-emerald-400 flex items-center justify-between">
              <span>Result: Actionable, risk-mitigated agronomy tailored to today.</span>
              <span className="font-mono text-[11px]">Context Hash Cached</span>
            </div>
          </Card>
        </div>
      </div>
    </section>
  );
};
