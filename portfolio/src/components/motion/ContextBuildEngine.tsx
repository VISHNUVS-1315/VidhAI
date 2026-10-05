'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { Sprout, Droplets, MapPin, Calendar, DollarSign, History, Layers, Cpu, Sparkles } from 'lucide-react';

interface ContextCapsule {
  id: string;
  label: string;
  value: string;
  category: string;
  icon: React.ReactNode;
  active: boolean;
}

export const ContextBuildEngine: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [pulseActive, setPulseActive] = useState<string | null>(null);

  const [capsules] = useState<ContextCapsule[]>([
    {
      id: 'soil',
      label: 'Soil Type',
      value: 'Red Loamy Soil',
      category: 'Pedology',
      icon: <Layers className="w-3.5 h-3.5 text-amber-400" />,
      active: true,
    },
    {
      id: 'water',
      label: 'Water / Irrigation',
      value: 'Borewell + Drip',
      category: 'Hydrology',
      icon: <Droplets className="w-3.5 h-3.5 text-blue-400" />,
      active: true,
    },
    {
      id: 'location',
      label: 'Geo Coordinates',
      value: 'Tiruppur, TN (11.1085° N)',
      category: 'Geography',
      icon: <MapPin className="w-3.5 h-3.5 text-rose-400" />,
      active: true,
    },
    {
      id: 'season',
      label: 'Cropping Season',
      value: 'Rabi (Winter Cycle)',
      category: 'Climate',
      icon: <Calendar className="w-3.5 h-3.5 text-emerald-400" />,
      active: true,
    },
    {
      id: 'budget',
      label: 'Budget per Acre',
      value: '₹35,000 / acre',
      category: 'Economics',
      icon: <DollarSign className="w-3.5 h-3.5 text-yellow-400" />,
      active: true,
    },
    {
      id: 'previous',
      label: 'Previous Harvest',
      value: 'Groundnut (Leguminous)',
      category: 'Rotation',
      icon: <History className="w-3.5 h-3.5 text-purple-400" />,
      active: true,
    },
    {
      id: 'size',
      label: 'Parcel Boundary',
      value: '4.5 Acres (2 Plots)',
      category: 'Topography',
      icon: <Sprout className="w-3.5 h-3.5 text-emerald-300" />,
      active: true,
    },
  ]);

  const handleCapsuleClick = (id: string) => {
    setPulseActive(id);
    setTimeout(() => setPulseActive(null), 1200);
  };

  return (
    <div className="relative p-6 sm:p-8 rounded-3xl bg-[#0F2014]/90 border border-[#233E2B] shadow-2xl overflow-hidden glow-card">
      {/* Background radial glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-emerald-600/10 rounded-full blur-[100px] pointer-events-none" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#233E2B] pb-4 mb-8">
        <div>
          <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold tracking-wider block">
            Signature Motion Pattern: Flow Merge
          </span>
          <h3 className="text-xl font-bold text-[#F1F7F2]">Multi-Factor Context Convergence</h3>
        </div>
        <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-950/80 border border-emerald-500/30 text-xs text-emerald-300">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
          <span className="font-mono">7 Signals Ingested</span>
        </div>
      </div>

      {/* Interactive Visualization Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center relative">
        {/* Left / Surrounding Capsules */}
        <div className="lg:col-span-7 space-y-2.5">
          <p className="text-xs text-[#A9BBAE] mb-3">
            Click any capsule to pulse signal into the agronomic reasoning engine:
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {capsules.map((c) => {
              const isPulsing = pulseActive === c.id;
              return (
                <button
                  key={c.id}
                  onClick={() => handleCapsuleClick(c.id)}
                  className={`p-3 rounded-2xl border text-left transition-all duration-300 cursor-pointer flex items-center gap-3 relative overflow-hidden ${
                    isPulsing
                      ? 'bg-emerald-950/90 border-emerald-400 scale-[1.02] shadow-[0_0_15px_rgba(76,175,108,0.4)]'
                      : 'bg-[#14261A] border-[#233E2B] hover:border-emerald-600/50 hover:bg-[#182E20]'
                  }`}
                >
                  <div className="p-2 rounded-xl bg-[#0B170E] border border-[#233E2B] shrink-0">
                    {c.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-1">
                      <span className="text-[10px] font-mono text-[#718776] uppercase">
                        {c.category}
                      </span>
                      {isPulsing && (
                        <span className="text-[9px] font-mono text-emerald-400 animate-ping">
                          TRANSMITTING
                        </span>
                      )}
                    </div>
                    <div className="text-xs font-semibold text-[#F1F7F2] truncate">{c.label}</div>
                    <div className="text-[11px] text-emerald-300 font-mono truncate">{c.value}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Central VidhAI Decision Engine Core */}
        <div className="lg:col-span-5 flex flex-col items-center justify-center p-6 rounded-2xl bg-[#09130B] border border-emerald-600/40 relative shadow-inner text-center">
          {/* Animated pulsing concentric circles */}
          <div className="relative w-28 h-28 flex items-center justify-center mb-5">
            <div
              className={`absolute inset-0 rounded-full border border-emerald-500/30 ${
                prefersReducedMotion ? '' : 'animate-ping'
              }`}
            />
            <div className="absolute inset-2 rounded-full border border-emerald-400/20 animate-spin" />
            <div className="w-20 h-20 rounded-full bg-emerald-950/90 border-2 border-emerald-400 flex items-center justify-center shadow-[0_0_30px_rgba(76,175,108,0.5)]">
              <Cpu className="w-9 h-9 text-emerald-300 animate-pulse" />
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-center gap-1.5 text-xs font-mono text-emerald-400 uppercase font-semibold">
              <Sparkles className="w-3.5 h-3.5" />
              <span>5-Tier Agronomy Engine</span>
            </div>
            <h4 className="text-sm font-bold text-[#F1F7F2]">
              Deterministic Ranking + NVIDIA NIM
            </h4>
            <p className="text-[11px] text-[#A9BBAE] leading-relaxed">
              Weights water deficit risk against market profitability and nitrogen replenishment from
              groundnut.
            </p>
          </div>

          {/* Resolved Decision Output */}
          <div className="mt-5 w-full p-3 rounded-xl bg-[#14261A] border border-emerald-500/30 text-left flex items-center justify-between">
            <div>
              <span className="text-[10px] font-mono text-emerald-400 uppercase block">
                Top Recommendation Resolved
              </span>
              <span className="text-xs font-bold text-[#F1F7F2]">Cotton (MCU-5)</span>
            </div>
            <div className="text-right">
              <span className="text-[10px] font-mono text-[#718776] block">Suitability</span>
              <span className="text-xs font-mono text-emerald-400 font-bold">96.8%</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
