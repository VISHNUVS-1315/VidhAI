'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PacketFlowDiagram } from '@/components/architecture/PacketFlowDiagram';
import { LivingSignalGrid } from '@/components/motion/LivingSignalGrid';
import {
  Users,
  Smartphone,
  HardDrive,
  Flame,
  Server,
  Cpu,
  Database,
  ShieldCheck,
} from 'lucide-react';

interface LayerMeta {
  id: string;
  name: string;
  badge: string;
  icon: React.ReactNode;
  components: string[];
  description: string;
  repoPath: string;
}

export const ArchitectureDiagram: React.FC = () => {
  const [selectedLayer, setSelectedLayer] = useState<string>('l5');

  const layers: LayerMeta[] = [
    {
      id: 'l1',
      name: 'Layer 01 — Users & Consoles',
      badge: 'Client Interfaces',
      icon: <Users className="w-5 h-5 text-emerald-400" />,
      components: ['Farmer Console', 'Consumer Console', 'Guest Previews'],
      description:
        'Dual specialized console workflows for agricultural producers and direct consumers, authenticated via Google Sign-In with Firebase Authentication and Firestore profile synchronization.',
      repoPath: 'lib/screens/home/ & lib/screens/auth/',
    },
    {
      id: 'l2',
      name: 'Layer 02 — Flutter Mobile Client',
      badge: 'Frontend Shell',
      icon: <Smartphone className="w-5 h-5 text-emerald-300" />,
      components: ['Flutter', 'Dart', 'flutter_bloc', 'Provider'],
      description:
        'Cross-platform Flutter client with current verified application build for Android. BLoC handles deterministic auth and session state; Provider binds domain repositories.',
      repoPath: 'pubspec.yaml & lib/main.dart',
    },
    {
      id: 'l3',
      name: 'Layer 03 — Local Device Services',
      badge: 'Device Integration',
      icon: <HardDrive className="w-5 h-5 text-blue-400" />,
      components: [
        'SharedPreferences Cache',
        'Speech-to-Text (STT)',
        'Flutter TTS',
        'WorkManager Workers',
        'Local Notifications',
      ],
      description:
        'Offline storage engine for user profiles, farm records, and cached prices. WorkManager executes periodic background weather checks and rain alerts.',
      repoPath: 'lib/services/background_work.dart & lib/services/data_service.dart',
    },
    {
      id: 'l4',
      name: 'Layer 04 — Firebase Suite',
      badge: 'Cloud Identity & Data',
      icon: <Flame className="w-5 h-5 text-amber-400" />,
      components: [
        'Firebase Authentication',
        'Cloud Firestore Database',
        'Firebase Cloud Messaging (FCM)',
      ],
      description:
        'Authenticates users and provides verifiable JWT tokens. Firestore holds community posts, synchronized farm records, and market cache snapshots.',
      repoPath: 'firestore.rules & lib/firebase_options.dart',
    },
    {
      id: 'l5',
      name: 'Layer 05 — VidhAI Secure Backend Gateway',
      badge: 'Render Cloud Deployment',
      icon: <Server className="w-5 h-5 text-emerald-400" />,
      components: [
        'Node.js & Express',
        'TypeScript',
        'Firebase Admin Verification',
        'Intent Classifier',
        'Retry / Fallback Engine',
      ],
      description:
        'Standalone backend deployed on Render. Verifies incoming Bearer tokens via Firebase Admin SDK. Acts as the single protected gateway so no AI secrets ever touch client devices.',
      repoPath: 'functions/src/app.ts & functions/src/server.ts',
    },
    {
      id: 'l6',
      name: 'Layer 06 — AI Model Router',
      badge: 'Hybrid AI Routing',
      icon: <Cpu className="w-5 h-5 text-purple-400" />,
      components: [
        'Groq (openai/gpt-oss-20b)',
        'NVIDIA Nemotron Ultra 550B',
        'NVIDIA Lightning 30B',
        'NVIDIA Nano Omni 30B (Vision)',
        'Content Safety 3.5',
      ],
      description:
        'Dispatches conversational text to Groq for low-latency streaming, and routes complex crop planning, foliage image diagnosis, and moderation to NVIDIA NIM.',
      repoPath: 'functions/src/aiGateway.ts & lib/core/ai/ai_model_router.dart',
    },
    {
      id: 'l7',
      name: 'Layer 07 — Agricultural Data Providers',
      badge: 'External Telemetry',
      icon: <Database className="w-5 h-5 text-cyan-400" />,
      components: [
        'AGMARKNET 2.0 (data.gov.in)',
        'Open-Meteo Weather API',
        'Government Administrative Datasets',
      ],
      description:
        'Authoritative live telemetry sources. Prices are normalized into uniform ₹/kg; weather data is evaluated against localized agricultural risk thresholds.',
      repoPath: 'functions/src/marketService.ts & functions/src/agmarknet2Provider.ts',
    },
  ];

  const current = layers.find((l) => l.id === selectedLayer) || layers[4];

  return (
    <section id="architecture" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative overflow-hidden">
      {/* Living Signal Grid Background */}
      <LivingSignalGrid density="low" className="opacity-60" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            System Engineering
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Seven layers of <span className="text-emerald-400">precision engineering.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            From the Flutter client to the Render-deployed TypeScript gateway, Groq inference, and
            AGMARKNET 2.0 APIs, examine how requests flow securely through the VidhAI architecture.
          </p>
        </div>

        {/* Signature Motion: Packet Flow Diagram */}
        <PacketFlowDiagram />

        {/* Interactive Stacked Architecture View */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* 7 Layers Stack List */}
          <div className="lg:col-span-6 space-y-3">
            {layers.map((layer) => {
              const isSelected = selectedLayer === layer.id;
              return (
                <div
                  key={layer.id}
                  onClick={() => setSelectedLayer(layer.id)}
                  className={`p-4 rounded-2xl border transition-all cursor-pointer flex items-center justify-between ${
                    isSelected
                      ? 'bg-[#1A3222] border-emerald-500/70 shadow-lg shadow-emerald-950/50 ring-1 ring-emerald-500/30'
                      : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/30 hover:bg-[#16291D]'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`p-2.5 rounded-xl border shrink-0 ${
                        isSelected
                          ? 'bg-emerald-950 border-emerald-500/50'
                          : 'bg-[#0B170E] border-[#1E3626]'
                      }`}
                    >
                      {layer.icon}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold text-[#F1F7F2]">{layer.name}</span>
                        <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-[#0B170E] text-[#A9BBAE] border border-[#1E3626]">
                          {layer.badge}
                        </span>
                      </div>
                      <div className="flex flex-wrap gap-1.5 pt-1">
                        {layer.components.slice(0, 3).map((c, cIdx) => (
                          <span key={cIdx} className="text-[10px] text-[#718776] font-mono">
                            {c}
                            {cIdx < 2 && cIdx < layer.components.length - 1 ? ' • ' : ''}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Detailed Inspector for Selected Layer */}
          <div className="lg:col-span-6 sticky top-24">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-6">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-emerald-950 border border-emerald-500/50">
                    {current.icon}
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-[#F1F7F2]">{current.name}</h3>
                    <span className="text-xs text-emerald-400 font-mono">{current.badge}</span>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Layer Active
                </Badge>
              </div>

              <div>
                <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-2 font-semibold">
                  Architectural Role &amp; Execution
                </h4>
                <p className="text-sm text-[#F1F7F2] leading-relaxed">{current.description}</p>
              </div>

              <div>
                <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-2 font-semibold">
                  Implemented Components
                </h4>
                <div className="flex flex-wrap gap-2">
                  {current.components.map((comp, idx) => (
                    <span
                      key={idx}
                      className="px-3 py-1 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs font-mono text-emerald-300"
                    >
                      {comp}
                    </span>
                  ))}
                </div>
              </div>

              <div className="p-3.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs space-y-1">
                <span className="text-[10px] font-mono uppercase text-[#718776] block">
                  Audited Source Path
                </span>
                <code className="text-emerald-300 font-mono text-xs block break-all">
                  {current.repoPath}
                </code>
              </div>

              <div className="pt-2 flex items-center justify-between text-xs text-[#718776]">
                <div className="flex items-center gap-1.5 text-emerald-400">
                  <ShieldCheck className="w-4 h-4" />
                  <span>Authenticated HTTPS Pipeline</span>
                </div>
                <span className="font-mono text-[11px]">Zero Client Secrets</span>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
