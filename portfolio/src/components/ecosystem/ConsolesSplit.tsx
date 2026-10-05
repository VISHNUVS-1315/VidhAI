'use client';

import React from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Sprout, ShoppingBag, ArrowRightLeft, Check } from 'lucide-react';

export const ConsolesSplit: React.FC = () => {
  return (
    <section className="py-20 border-b border-[#233E2B] bg-[#0B170E] relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <Badge variant="verified" size="sm">
            Ecosystem Architecture
          </Badge>
          <h2 className="text-3xl sm:text-4xl font-bold text-[#F1F7F2] tracking-tight">
            Two specialized consoles. <span className="text-emerald-400">One connected market.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            VidhAI separates user experiences by intent while unifying them over the same Firestore
            and Node.js backend. Farmers manage fields and list produce; consumers post volume demands
            and discover local harvests.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-11 gap-6 items-center">
          {/* Left: Farmer Console */}
          <div className="lg:col-span-5">
            <Card className="bg-[#14261A] border-[#2E7D32]/50 p-6 sm:p-8 space-y-5">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
                    <Sprout className="w-6 h-6" />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-[#F1F7F2]">Farmer Console</h3>
                    <span className="text-xs text-emerald-400">Decision Support & Management</span>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Primary Flow
                </Badge>
              </div>

              <p className="text-xs text-[#A9BBAE] leading-relaxed">
                Empowers agricultural producers with predictive agronomic advice, input optimization,
                and direct pre-harvest market exposure.
              </p>

              <ul className="space-y-3 text-xs">
                {[
                  'Multi-farm management with GPS coordinate binding',
                  '12-input top-10 crop recommendation engine',
                  'Foliage disease diagnosis via NVIDIA Nano Omni 30B',
                  'Automated task scheduling and expense/pesticide logging',
                  'Pre-harvest produce announcements (available_soon)',
                  'Mandi price alerts converted to uniform ₹ / kg',
                ].map((item, idx) => (
                  <li key={idx} className="flex items-start gap-2.5 text-[#F1F7F2]">
                    <div className="w-4 h-4 rounded-full bg-emerald-950 border border-emerald-500/50 flex items-center justify-center shrink-0 mt-0.5">
                      <Check className="w-2.5 h-2.5 text-emerald-400" />
                    </div>
                    <span>{item}</span>
                  </li>
                ))}
              </ul>

              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-[11px] text-[#A9BBAE] font-mono">
                Entry: <span className="text-emerald-300">FarmerHomeScreen.dart</span> (lib/features/home/)
              </div>
            </Card>
          </div>

          {/* Center Connection Indicator */}
          <div className="lg:col-span-1 flex flex-col items-center justify-center py-4 lg:py-0">
            <div className="p-4 rounded-full bg-[#162B1D] border border-emerald-500/40 text-emerald-400 shadow-xl shadow-emerald-950/50">
              <ArrowRightLeft className="w-6 h-6" />
            </div>
            <span className="text-[11px] font-mono uppercase tracking-wider text-emerald-400 font-semibold mt-2 text-center">
              Direct Trade
            </span>
          </div>

          {/* Right: Consumer Console */}
          <div className="lg:col-span-5">
            <Card className="bg-[#14261A] border-[#3B82F6]/40 p-6 sm:p-8 space-y-5">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-blue-950 border border-blue-500/40 text-blue-400">
                    <ShoppingBag className="w-6 h-6" />
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-[#F1F7F2]">Consumer Console</h3>
                    <span className="text-xs text-blue-400">Direct Procurement & Demand</span>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Verified Screen
                </Badge>
              </div>

              <p className="text-xs text-[#A9BBAE] leading-relaxed">
                Enables retail consumers, cooperative bulk buyers, and restaurants to source fresh
                produce directly from local farmers without middleman markups.
              </p>

              <ul className="space-y-3 text-xs">
                {[
                  'Browse verified upcoming harvests by district & crop',
                  'Publish specific produce requirements (demand posts)',
                  'Express bilateral interest in farmer crop lots',
                  'Transparent price discovery without distributor commission',
                  'Access VidhAI Assistant for nutritional & storage guidance',
                  'Real-time supplier notification triggers',
                ].map((item, idx) => (
                  <li key={idx} className="flex items-start gap-2.5 text-[#F1F7F2]">
                    <div className="w-4 h-4 rounded-full bg-blue-950 border border-blue-500/50 flex items-center justify-center shrink-0 mt-0.5">
                      <Check className="w-2.5 h-2.5 text-blue-400" />
                    </div>
                    <span>{item}</span>
                  </li>
                ))}
              </ul>

              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-[11px] text-[#A9BBAE] font-mono">
                Entry: <span className="text-blue-300">ConsumerHomeScreen.dart</span> (lib/features/home/)
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
