'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import {
  Cpu,
  Sprout,
  Calendar,
  Bug,
  TrendingUp,
  BookOpen,
  Users,
  CloudRain,
  Languages,
  Layers,
  ArrowRight,
} from 'lucide-react';

interface OrbitNode {
  id: string;
  name: string;
  subtitle: string;
  icon: React.ReactNode;
  category: string;
  technicalDetails: string;
  repoEvidence: string;
}

export const OrbitEcosystem: React.FC = () => {
  const nodes: OrbitNode[] = [
    {
      id: 'ai-chat',
      name: 'AI Assistant',
      subtitle: 'Farm-aware conversational assistant',
      icon: <Cpu className="w-5 h-5 text-emerald-400" />,
      category: 'Intelligence',
      technicalDetails:
        'Groq text chat with openai/gpt-oss-20b for low-latency streaming conversational AI. Uses AIContextBuilder to inject active farm soil, crops, weather, and mandi data.',
      repoEvidence: 'lib/features/assistant/ & lib/services/ai/',
    },
    {
      id: 'crop-engine',
      name: 'Crop Intelligence',
      subtitle: '12-factor top-10 crop planner',
      icon: <Sprout className="w-5 h-5 text-emerald-300" />,
      category: 'Agronomy',
      technicalDetails:
        '5-tier recommendation pipeline: Live NVIDIA structured output -> deterministic scored engine -> context-hash cache -> realtime AI ranker -> local knowledge base.',
      repoEvidence: 'lib/services/crop_recommendation_service.dart & functions/src/cropService.ts',
    },
    {
      id: 'farm-mgmt',
      name: 'Farm Management',
      subtitle: 'Multi-farm workspace & records',
      icon: <Calendar className="w-5 h-5 text-blue-400" />,
      category: 'Operations',
      technicalDetails:
        'Multi-farm management with GPS coordinates, crop growth stages, and 5 dedicated record types: Expenses, Fertilizers, Pesticides, Disease outbreaks, and Farm History.',
      repoEvidence: 'lib/features/farm/ & lib/features/farm_records/screens/',
    },
    {
      id: 'disease-vision',
      name: 'Pest & Disease Support',
      subtitle: 'Multimodal foliage analysis',
      icon: <Bug className="w-5 h-5 text-red-400" />,
      category: 'Diagnostic',
      technicalDetails:
        'Camera capture and secure upload to NVIDIA Nemotron Nano Omni 30B reasoning model. Returns probable pathogen, severity assessment, and chemical/biological treatments.',
      repoEvidence: 'functions/src/aiGateway.ts (/ai/image)',
    },
    {
      id: 'market-intel',
      name: 'Market Intelligence',
      subtitle: 'Official AGMARKNET 2.0 Mandis',
      icon: <TrendingUp className="w-5 h-5 text-amber-400" />,
      category: 'Market Data',
      technicalDetails:
        'Connects to data.gov.in AGMARKNET 2.0 API resource. Automatically normalizes quintals, bags, and crates into uniform ₹/kg with 7-day to 30-day historical trend curves.',
      repoEvidence: 'functions/src/marketService.ts & lib/services/market_price_service.dart',
    },
    {
      id: 'community-ecosystem',
      name: 'Community & Marketplace',
      subtitle: 'Bilateral harvest & demand matching',
      icon: <Users className="w-5 h-5 text-purple-400" />,
      category: 'Marketplace',
      technicalDetails:
        'Supports pre-harvest announcements (available_soon) and buyer requirements (demand). Facilitates direct connections before harvest to eliminate distress sales.',
      repoEvidence: 'lib/features/community/models/community_models.dart',
    },
    {
      id: 'weather-alerts',
      name: 'Weather Intelligence',
      subtitle: 'Open-Meteo & background alerts',
      icon: <CloudRain className="w-5 h-5 text-cyan-400" />,
      category: 'Telemetry',
      technicalDetails:
        'Integrates Open-Meteo API for hyperlocal precipitation, wind gusts, and humidity. Background WorkManager tasks trigger local notifications for heavy rain and heat waves.',
      repoEvidence: 'lib/services/weather_service.dart & lib/services/background_work.dart',
    },
    {
      id: 'schemes',
      name: 'Government Schemes',
      subtitle: 'Subsidies & welfare directory',
      icon: <BookOpen className="w-5 h-5 text-yellow-400" />,
      category: 'Welfare',
      technicalDetails:
        'Curated database of central and state agricultural support schemes, solar pump subsidies, and credit facilities with eligibility verification guidelines.',
      repoEvidence: 'lib/features/schemes/screens/government_schemes_screen.dart',
    },
    {
      id: 'multilingual',
      name: '13-Language Localization',
      subtitle: 'Regional vernaculars + Urdu RTL',
      icon: <Languages className="w-5 h-5 text-rose-400" />,
      category: 'Accessibility',
      technicalDetails:
        'Custom lightweight locale engine covering 13 Indian languages with dedicated string maps and complete right-to-left layout adaptation for Urdu.',
      repoEvidence: 'lib/locale/translations/ & lib/locale/locale.dart',
    },
    {
      id: 'consoles',
      name: 'Dual Consoles',
      subtitle: 'Farmer & Consumer modes',
      icon: <Layers className="w-5 h-5 text-indigo-400" />,
      category: 'Architecture',
      technicalDetails:
        'Dedicated console modes tailored to agricultural producers vs direct institutional/retail consumers sharing the same backend ecosystem.',
      repoEvidence: 'lib/features/home/screens/farmer_home_screen.dart & consumer_home_screen.dart',
    },
  ];

  const [activeNode, setActiveNode] = useState<OrbitNode>(nodes[0]);

  return (
    <section id="ecosystem" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Interactive Ecosystem
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Ten interconnected nodes. <span className="text-emerald-400">One intelligent core.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            VidhAI is not a single-purpose utility. It connects agronomy, live telemetry, market
            pricing, and direct trade into a unified operational loop.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
          {/* Node Grid Selector (Left/Top) */}
          <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-2 gap-3">
            {nodes.map((node) => {
              const isActive = activeNode.id === node.id;
              return (
                <button
                  key={node.id}
                  onClick={() => setActiveNode(node)}
                  className={`p-4 rounded-2xl text-left border transition-all duration-200 cursor-pointer flex items-start gap-3.5 ${
                    isActive
                      ? 'bg-[#1A3222] border-emerald-500/60 shadow-lg shadow-emerald-950/40 ring-1 ring-emerald-500/30'
                      : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/30 hover:bg-[#16291D]'
                  }`}
                >
                  <div
                    className={`p-2.5 rounded-xl border shrink-0 ${
                      isActive
                        ? 'bg-emerald-950/80 border-emerald-500/50'
                        : 'bg-[#0B170E] border-[#1E3626]'
                    }`}
                  >
                    {node.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-1 mb-0.5">
                      <span className="text-xs font-semibold text-[#F1F7F2] truncate">
                        {node.name}
                      </span>
                      <span className="text-[10px] uppercase font-mono text-[#718776]">
                        {node.category}
                      </span>
                    </div>
                    <p className="text-[11px] text-[#A9BBAE] truncate">{node.subtitle}</p>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Detailed Inspector Card (Right/Bottom) */}
          <div className="lg:col-span-5">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 md:p-8 space-y-6">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-emerald-950/80 border border-emerald-500/40">
                    {activeNode.icon}
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-[#F1F7F2]">{activeNode.name}</h3>
                    <span className="text-xs text-emerald-400 font-medium">
                      {activeNode.subtitle}
                    </span>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Active Subsystem
                </Badge>
              </div>

              <div>
                <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-2 font-semibold">
                  Technical Architecture & Execution
                </h4>
                <p className="text-sm text-[#F1F7F2] leading-relaxed">
                  {activeNode.technicalDetails}
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs space-y-1">
                <span className="text-[11px] font-mono text-[#718776] uppercase block">
                  Repository Source Trace
                </span>
                <code className="text-emerald-300 font-mono text-xs block break-all">
                  {activeNode.repoEvidence}
                </code>
              </div>

              <div className="pt-2 flex items-center justify-between text-xs text-[#A9BBAE]">
                <span>Status: Fully Implemented</span>
                <span className="flex items-center gap-1 text-emerald-400">
                  <span>Audited in Codebase</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </span>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
