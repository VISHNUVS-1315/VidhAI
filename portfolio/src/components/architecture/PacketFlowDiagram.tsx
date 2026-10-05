'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { Smartphone, ShieldCheck, Server, Cpu, Database, Sparkles, ArrowRight } from 'lucide-react';

interface Station {
  id: string;
  name: string;
  category: string;
  protocol: string;
  codeRef: string;
  latency: string;
  icon: React.ReactNode;
  summary: string;
}

export const PacketFlowDiagram: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeStation, setActiveStation] = useState<string>('ai');

  const stations: Station[] = [
    {
      id: 'client',
      name: 'Flutter Mobile App',
      category: 'Presentation & Local State',
      protocol: 'HTTPS / WSS',
      codeRef: 'lib/core/services/api_service.dart',
      latency: '0ms (edge)',
      icon: <Smartphone className="w-4 h-4 text-emerald-400" />,
      summary: 'Captures speech, geotags, and farm attributes. Manages SharedPreferences local cache and offline queues.',
    },
    {
      id: 'auth',
      name: 'Firebase Auth & Gateway',
      category: 'Identity & Ingestion',
      protocol: 'JWT Bearer',
      codeRef: 'lib/features/auth/presentation/providers/auth_provider.dart',
      latency: '~25ms',
      icon: <ShieldCheck className="w-4 h-4 text-blue-400" />,
      summary: 'Authenticates farmer sessions, validates claims, and securely provisions scoped API tokens.',
    },
    {
      id: 'cloud',
      name: 'Cloud Functions Proxy',
      category: 'Serverless Orchestration',
      protocol: 'Node.js Express',
      codeRef: 'functions/src/index.ts',
      latency: '~40ms',
      icon: <Server className="w-4 h-4 text-amber-400" />,
      summary: 'Normalizes input telemetry, injects user context, and orchestrates model fallback cascades.',
    },
    {
      id: 'ai',
      name: 'AI Dual Router',
      category: 'Inference Layer',
      protocol: 'REST / Streaming SSE',
      codeRef: 'lib/core/services/ai_routing_service.dart',
      latency: '~380ms',
      icon: <Cpu className="w-4 h-4 text-purple-400" />,
      summary: 'Dispatches conversational chat to Groq (openai/gpt-oss-20b) and structured agronomy to NVIDIA NIM.',
    },
    {
      id: 'data',
      name: 'Gov Data & AGMARKNET',
      category: 'Ground Truth Ingestion',
      protocol: 'REST JSON',
      codeRef: 'functions/src/marketData.ts',
      latency: '~120ms',
      icon: <Database className="w-4 h-4 text-emerald-300" />,
      summary: 'Streams verified mandi commodity prices normalized to ₹/kg and soil survey datasets.',
    },
    {
      id: 'response',
      name: 'Actionable Guidance',
      category: 'Farmer Delivery',
      protocol: 'UI Render + Audio TTS',
      codeRef: 'lib/features/recommendation/presentation/screens/',
      latency: 'UI Dispatch',
      icon: <Sparkles className="w-4 h-4 text-emerald-400" />,
      summary: 'Sanitizes recommendation outputs and streams structured guidance into the farmer dashboard.',
    },
  ];

  const current = stations.find((s) => s.id === activeStation) || stations[3];

  return (
    <div
      data-context-label="TRACE FLOW"
      className="p-6 sm:p-8 rounded-3xl bg-[#0E1C12]/95 border border-[#233E2B] glow-card mb-12 overflow-hidden relative"
    >
      {/* Background ambient radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-emerald-600/10 rounded-full blur-[120px] pointer-events-none" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#233E2B] pb-4 mb-6">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold tracking-wider">
              Signature Motion Pattern: Packet Flow Diagram
            </span>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 border border-emerald-500/30 text-emerald-300">
              Interactive 6-Stage Pipeline
            </span>
          </div>
          <h3 className="text-xl font-bold text-[#F1F7F2] mt-1">
            End-to-End Architectural Data Transit
          </h3>
        </div>

        <div className="flex items-center gap-2 text-xs font-mono text-[#A9BBAE]">
          <span className={`w-2 h-2 rounded-full bg-emerald-400 ${prefersReducedMotion ? '' : 'animate-pulse'}`} />
          <span>Active Packet Stream</span>
        </div>
      </div>

      {/* Interactive Flow Conduit & Stations */}
      <div className="grid grid-cols-1 md:grid-cols-6 gap-2 relative mb-6">
        {stations.map((station, idx) => {
          const isSelected = activeStation === station.id;
          return (
            <div
              key={station.id}
              onClick={() => setActiveStation(station.id)}
              className={`p-3.5 rounded-2xl border transition-all duration-300 cursor-pointer relative text-left ${
                isSelected
                  ? 'bg-emerald-950/90 border-emerald-400 shadow-[0_0_15px_rgba(76,175,108,0.4)] scale-[1.02] z-10'
                  : 'bg-[#14261A] border-[#233E2B] hover:border-emerald-600/50 hover:bg-[#182E20]'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-[9px] font-mono text-emerald-400 uppercase font-semibold">
                  0{idx + 1}
                </span>
                <div className="p-1.5 rounded-lg bg-[#0B170E] border border-[#233E2B]">
                  {station.icon}
                </div>
              </div>

              <h4 className="text-xs font-bold text-[#F1F7F2] truncate">{station.name}</h4>
              <div className="text-[10px] text-[#718776] font-mono truncate mt-0.5">
                {station.latency}
              </div>

              {/* Direction Arrow between steps */}
              {idx < 5 && (
                <div className="hidden md:block absolute -right-2 top-1/2 -translate-y-1/2 z-20 text-emerald-500/50 pointer-events-none">
                  <ArrowRight className="w-3.5 h-3.5" />
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Selected Station Deep Dive Inspector */}
      <div className="p-5 sm:p-6 rounded-2xl bg-[#09130B] border border-emerald-500/30 flex flex-col md:flex-row items-start md:items-center justify-between gap-6 relative shadow-inner">
        <div className="space-y-2 max-w-2xl">
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-emerald-400 uppercase font-semibold">
              {current.category}
            </span>
            <span className="text-[#718776]">•</span>
            <span className="text-xs font-mono text-[#A9BBAE]">{current.protocol}</span>
          </div>

          <h4 className="text-base font-bold text-[#F1F7F2]">{current.name}</h4>
          <p className="text-xs sm:text-sm text-[#A9BBAE] leading-relaxed">{current.summary}</p>
        </div>

        <div className="shrink-0 space-y-2 w-full md:w-auto text-left md:text-right">
          <div className="text-xs text-[#718776] font-mono">VERIFIED REPO SOURCE:</div>
          <code className="text-xs font-mono text-emerald-300 px-3 py-1.5 rounded-xl bg-[#14261A] border border-[#233E2B] inline-block">
            {current.codeRef}
          </code>
        </div>
      </div>
    </div>
  );
};
