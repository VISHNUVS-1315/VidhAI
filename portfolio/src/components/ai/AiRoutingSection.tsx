'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PROJECT_CONFIG } from '@/data/project';
import { LivingSignalGrid } from '@/components/motion/LivingSignalGrid';
import { Zap, Layers, Lock } from 'lucide-react';

export const AiRoutingSection: React.FC = () => {
  const [activeTier, setActiveTier] = useState<string>('chat');

  return (
    <section id="intelligence" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative overflow-hidden">
      {/* Living Signal Grid Background */}
      <LivingSignalGrid density="low" className="opacity-40" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            AI Gateway & Model Routing
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            One platform. <span className="text-emerald-400">Multiple intelligence paths.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            VidhAI does not rely on a single monolithic model. A specialized Node.js Express router
            evaluates prompt intent and latency requirements, dispatching conversational queries to
            Groq and complex multi-factor agronomy to NVIDIA NIM.
          </p>
        </div>

        {/* Central Architecture Flow Diagram */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start mb-12">
          {/* Left: Client & Gateway Security */}
          <div className="lg:col-span-4 space-y-4">
            <Card className="bg-[#14261A] border-[#2E7D32]/40 p-6 space-y-4">
              <div className="flex items-center gap-3">
                <div className="p-2.5 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
                  <Lock className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#F1F7F2]">Zero Client-Side Secrets</h3>
                  <span className="text-xs text-emerald-400 font-medium">
                    Firebase Bearer Token Auth
                  </span>
                </div>
              </div>
              <p className="text-xs text-[#A9BBAE] leading-relaxed">
                The Flutter client stores zero external AI API keys. Every request is signed with the
                user&apos;s Firebase ID token and verified by the backend gateway (`functions/src/app.ts`)
                before routing.
              </p>
              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] font-mono text-[11px] text-[#A9BBAE]">
                Header: <span className="text-emerald-300">Authorization: Bearer &lt;idToken&gt;</span>
              </div>
            </Card>

            <Card className="bg-[#14261A] border-[#233E2B] p-6 space-y-3">
              <div className="flex items-center gap-2 text-xs font-semibold uppercase font-mono text-[#A9BBAE]">
                <Layers className="w-4 h-4 text-emerald-400" />
                <span>Backend Gateway: Render</span>
              </div>
              <p className="text-xs text-[#A9BBAE] leading-relaxed">
                Node.js + Express standalone backend handles request classification, fallback
                retry logic, and rate-limit mitigation across providers.
              </p>
            </Card>
          </div>

          {/* Right: The Specialized Routing Paths */}
          <div className="lg:col-span-8 space-y-4">
            {/* Groq Card */}
            <div
              onClick={() => setActiveTier('chat')}
              className={`p-6 rounded-2xl border transition-all cursor-pointer ${
                activeTier === 'chat'
                  ? 'bg-[#1A3222] border-emerald-500/80 shadow-lg shadow-emerald-950/50'
                  : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/40'
              }`}
            >
              <div className="flex flex-wrap items-center justify-between gap-3 mb-2">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 rounded-xl bg-emerald-950 border border-emerald-500/50 text-emerald-400">
                    <Zap className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-base font-bold text-[#F1F7F2]">Conversational Text Chat</h4>
                    <span className="text-xs font-mono text-emerald-400">
                      Provider: Groq • Model: openai/gpt-oss-20b
                    </span>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Low-Latency Streaming
                </Badge>
              </div>
              <p className="text-xs text-[#A9BBAE] leading-relaxed mb-3">
                {PROJECT_CONFIG.aiArchitecture.appChat.purpose}
              </p>
              <div className="flex flex-wrap items-center gap-2 text-[11px] font-mono text-emerald-300">
                <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-emerald-500/30">
                  Streaming SSE
                </span>
                <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-emerald-500/30">
                  Live Transcription Sync
                </span>
                <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-emerald-500/30">
                  Farm-Context Injection
                </span>
              </div>
            </div>

            {/* NVIDIA NIM Specialized Tiers */}
            <div className="space-y-3 pt-2">
              <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] font-semibold">
                NVIDIA NIM Workload Specialization (`functions/src/aiGateway.ts`)
              </h4>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {PROJECT_CONFIG.aiArchitecture.specializedTiers.map((tier, idx) => (
                  <div
                    key={idx}
                    onClick={() => setActiveTier(tier.tier)}
                    className={`p-4 rounded-xl border transition-all cursor-pointer ${
                      activeTier === tier.tier
                        ? 'bg-[#1A3222] border-emerald-500/70 shadow-md shadow-emerald-950/40'
                        : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/30'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="text-xs font-bold text-[#F1F7F2]">{tier.tier}</span>
                      <span className="text-[10px] font-mono text-emerald-400">NVIDIA NIM</span>
                    </div>
                    <code className="text-[11px] font-mono text-emerald-300 block mb-2 truncate">
                      {tier.model}
                    </code>
                    <p className="text-[11px] text-[#A9BBAE] leading-relaxed">{tier.role}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};
