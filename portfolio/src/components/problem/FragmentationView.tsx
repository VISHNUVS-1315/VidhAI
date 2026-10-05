'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import {
  CloudRain,
  TrendingUp,
  Bug,
  BookOpen,
  FileText,
  ShoppingBag,
  CheckCircle2,
  Unlink,
  Link as LinkIcon,
} from 'lucide-react';

export const FragmentationView: React.FC = () => {
  const [isUnified, setIsUnified] = useState(false);

  const fragments = [
    {
      title: 'Siloed Weather Broadcasts',
      desc: 'Generic TV/SMS forecasts lacking hyperlocal soil moisture or rain thresholds.',
      icon: <CloudRain className="w-5 h-5 text-blue-400" />,
      isolatedState: 'Checked on separate web portal; not linked to field tasks.',
      unifiedState: 'Open-Meteo telemetry directly triggers automated field task alerts.',
    },
    {
      title: 'Non-Standard Mandi Data',
      desc: 'Market reports quoted in quintals or maunds across disparate state portals.',
      icon: <TrendingUp className="w-5 h-5 text-amber-400" />,
      isolatedState: 'Unclear unit conversions; delayed price discovery.',
      unifiedState: 'AGMARKNET 2.0 automatically normalized to ₹/kg with 7-day history.',
    },
    {
      title: 'Pest Diagnosis Inaccessibility',
      desc: 'Farmers travel to distant Krishi Vigyan Kendras or rely on hearsay.',
      icon: <Bug className="w-5 h-5 text-red-400" />,
      isolatedState: 'Days lost waiting for agronomy visits while blight spreads.',
      unifiedState: 'On-device camera photo analyzed via NVIDIA Nano Omni 30B reasoning.',
    },
    {
      title: 'Paper Notebook Records',
      desc: 'Fertilizer expenses, spray logs, and harvest volumes scribbled on loose paper.',
      icon: <FileText className="w-5 h-5 text-emerald-400" />,
      isolatedState: 'Lost receipts, no cost-per-acre analysis or history comparison.',
      unifiedState: 'Digital farm records (expenses, spray logs, diseases) saved locally & synced.',
    },
    {
      title: 'Middleman Dependent Selling',
      desc: 'Produce sold at distress prices because buyers are discovered after harvest.',
      icon: <ShoppingBag className="w-5 h-5 text-purple-400" />,
      isolatedState: 'High commission cuts and zero advance price discovery.',
      unifiedState: 'Pre-harvest listings connect directly to regional buyers 8–10 days early.',
    },
    {
      title: 'Opaque Government Schemes',
      desc: 'Central & state subsidies buried in complex bureaucratic portals.',
      icon: <BookOpen className="w-5 h-5 text-cyan-400" />,
      isolatedState: 'Subsidies missed due to lack of timely eligibility awareness.',
      unifiedState: 'In-app Government Schemes directory with criteria guidance.',
    },
  ];

  return (
    <section id="problem" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <Badge variant="neutral" size="sm">
            The Agricultural Reality
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Farming decisions should not require{' '}
            <span className="text-emerald-400">five different platforms.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Critical agricultural data in India is traditionally scattered across disconnected
            portals, state directories, and middleman networks. VidhAI converges these silos into
            one unified, offline-friendly intelligence operating system.
          </p>

          {/* Interactive Toggle Button */}
          <div className="pt-4 flex items-center justify-center gap-3">
            <Button
              variant={!isUnified ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setIsUnified(false)}
              icon={<Unlink className="w-4 h-4" />}
            >
              Fragmented Reality
            </Button>
            <Button
              variant={isUnified ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setIsUnified(true)}
              icon={<LinkIcon className="w-4 h-4" />}
            >
              Unified VidhAI Architecture
            </Button>
          </div>
        </div>

        {/* Fragmented vs Unified Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {fragments.map((frag, idx) => (
            <Card
              key={idx}
              className={`transition-all duration-500 relative overflow-hidden ${
                isUnified
                  ? 'border-emerald-500/50 bg-[#162B1D] shadow-lg shadow-emerald-950/40'
                  : 'border-[#294332] bg-[#122217] opacity-90'
              }`}
            >
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="p-2.5 rounded-xl bg-[#0B170E] border border-[#233E2B]">
                  {frag.icon}
                </div>
                <Badge variant={isUnified ? 'verified' : 'neutral'} size="sm">
                  {isUnified ? 'Connected in VidhAI' : 'Fragmented'}
                </Badge>
              </div>

              <h3 className="text-base font-semibold text-[#F1F7F2] mb-1.5">{frag.title}</h3>
              <p className="text-xs text-[#A9BBAE] mb-4 leading-relaxed">{frag.desc}</p>

              {/* State comparison */}
              <div className="p-3 rounded-xl bg-[#0B170E]/80 border border-[#1E3626] text-xs">
                {isUnified ? (
                  <div className="flex items-start gap-2 text-emerald-300">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                    <span>{frag.unifiedState}</span>
                  </div>
                ) : (
                  <div className="text-[#718776] leading-relaxed">
                    <span className="text-amber-400/90 font-medium block mb-0.5">Isolated State:</span>
                    {frag.isolatedState}
                  </div>
                )}
              </div>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};
