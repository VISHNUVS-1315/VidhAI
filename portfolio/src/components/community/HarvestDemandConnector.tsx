'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { MOCK_COMMUNITY_MATCH } from '@/data/mockData';
import { MatchFlowDiagram } from '@/components/community/MatchFlowDiagram';
import { LivingSignalGrid } from '@/components/motion/LivingSignalGrid';
import {
  Sprout,
  ShoppingBag,
  Handshake,
  Sparkles,
} from 'lucide-react';

export const HarvestDemandConnector: React.FC = () => {
  const [isConnected, setIsConnected] = useState(true);

  const { harvest, demand, matchingMetrics } = MOCK_COMMUNITY_MATCH;

  return (
    <section id="community" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative overflow-hidden">
      {/* Living Signal Grid Background */}
      <LivingSignalGrid density="low" className="opacity-50" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <div className="flex items-center justify-center gap-2">
            <Badge variant="verified" size="sm">
              Community &amp; Supply-Demand Matching
            </Badge>
            <Badge variant="demo" size="sm">
              Illustrative Scenario
            </Badge>
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            From harvest planning to <span className="text-emerald-400">direct market connection.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Instead of dumping produce into overcrowded morning mandis at distress rates, farmers
            publish upcoming yields 8–10 days early. Local buyers and retailers discover compatible
            batches and connect directly.
          </p>
          <div className="pt-1 flex items-center justify-center gap-2 text-[11px] font-mono text-[#718776]">
            <span className="text-emerald-400 font-semibold">IMPLEMENTATION:</span>
            <span>Firestore-backed district bilateral matching with disintermediation economics</span>
          </div>
        </div>

        {/* Signature Motion: Match Flow Diagram */}
        <div className="max-w-5xl mx-auto mb-12">
          <MatchFlowDiagram />
        </div>

        {/* Dual Listing Grid with Direct Matching Logic */}
        <div className="grid grid-cols-1 lg:grid-cols-11 gap-6 items-center max-w-6xl mx-auto mb-8">
          {/* Left: Farmer Pre-Harvest Announcement */}
          <div className="lg:col-span-5">
            <Card
              className={`p-6 sm:p-7 space-y-5 transition-all ${
                isConnected
                  ? 'bg-[#14261A] border-emerald-500/60 shadow-xl shadow-emerald-950/40 ring-1 ring-emerald-500/30'
                  : 'bg-[#122217] border-[#233E2B]'
              }`}
            >
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
                    <Sprout className="w-5 h-5" />
                  </div>
                  <div>
                    <span className="text-[10px] font-mono uppercase text-emerald-400 font-semibold">
                      Category: available_soon
                    </span>
                    <h3 className="text-base font-bold text-[#F1F7F2]">Pre-Harvest Listing</h3>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Farmer Post
                </Badge>
              </div>

              <div className="space-y-2 text-xs">
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Producer:</span>
                  <span className="text-[#F1F7F2] font-semibold">{harvest.author}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Commodity:</span>
                  <span className="text-emerald-300 font-medium">{harvest.crop}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Expected Volume:</span>
                  <span className="font-mono text-[#F1F7F2] font-bold">{harvest.quantityKg} kg</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Ready for Harvest:</span>
                  <span className="text-amber-300 font-medium">In {harvest.harvestInDays} Days</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Asking Benchmark:</span>
                  <span className="font-mono text-emerald-400 font-bold">
                    ₹{harvest.askingPricePerKg.toFixed(2)} / kg
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">District:</span>
                  <span className="text-[#A9BBAE]">{harvest.district}</span>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-xs text-[#A9BBAE] italic">
                &quot;{harvest.notes}&quot;
              </div>

              <div className="flex items-center justify-between text-[11px] text-[#718776] pt-1">
                <span>Interested Buyers: {harvest.interestedBuyers}</span>
                <span className="text-emerald-400 font-mono">Status: active</span>
              </div>
            </Card>
          </div>

          {/* Center Connection Match Indicator */}
          <div className="lg:col-span-1 flex flex-col items-center justify-center py-4 lg:py-0">
            <button
              onClick={() => setIsConnected(!isConnected)}
              aria-label="Toggle matching simulation"
              className={`p-3.5 rounded-2xl border transition-all duration-300 cursor-pointer ${
                isConnected
                  ? 'bg-emerald-950 border-emerald-500/60 text-emerald-400 shadow-xl shadow-emerald-950 animate-pulse'
                  : 'bg-[#14261A] border-[#233E2B] text-[#718776]'
              }`}
            >
              <Handshake className="w-6 h-6" />
            </button>
            <span className="text-[10px] font-mono text-emerald-400 mt-2 font-semibold uppercase text-center">
              {isConnected ? 'Direct Match' : 'Unlinked'}
            </span>
          </div>

          {/* Right: Consumer Demand Requirement */}
          <div className="lg:col-span-5">
            <Card
              className={`p-6 sm:p-7 space-y-5 transition-all ${
                isConnected
                  ? 'bg-[#14261A] border-blue-500/60 shadow-xl shadow-blue-950/40 ring-1 ring-blue-500/30'
                  : 'bg-[#122217] border-[#233E2B]'
              }`}
            >
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 rounded-xl bg-blue-950 border border-blue-500/40 text-blue-400">
                    <ShoppingBag className="w-5 h-5" />
                  </div>
                  <div>
                    <span className="text-[10px] font-mono uppercase text-blue-400 font-semibold">
                      Category: demand
                    </span>
                    <h3 className="text-base font-bold text-[#F1F7F2]">Buyer Requirement</h3>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Buyer Post
                </Badge>
              </div>

              <div className="space-y-2 text-xs">
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Requester:</span>
                  <span className="text-[#F1F7F2] font-semibold">{demand.author}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Commodity:</span>
                  <span className="text-blue-300 font-medium">{demand.crop}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Required Volume:</span>
                  <span className="font-mono text-[#F1F7F2] font-bold">{demand.requiredKg} kg</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Needed By:</span>
                  <span className="text-amber-300 font-medium">{demand.targetDate}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">Target Budget:</span>
                  <span className="font-mono text-blue-400 font-bold">
                    ₹{demand.targetPricePerKg.toFixed(2)} / kg
                  </span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[#718776]">District:</span>
                  <span className="text-[#A9BBAE]">{demand.district}</span>
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-xs text-[#A9BBAE] italic">
                &quot;{demand.notes}&quot;
              </div>

              <div className="flex items-center justify-between text-[11px] text-[#718776] pt-1">
                <span>Available Suppliers: {demand.availableSuppliers}</span>
                <span className="text-blue-400 font-mono">Status: active</span>
              </div>
            </Card>
          </div>
        </div>

        {/* Disintermediation Economics Card */}
        {isConnected && (
          <div className="max-w-4xl mx-auto p-5 rounded-2xl bg-[#122217] border border-emerald-500/40 text-xs space-y-2">
            <div className="flex items-center gap-2 text-emerald-400 font-semibold text-sm">
              <Sparkles className="w-4 h-4" />
              <span>Economic Impact of Direct Bilateral Matching:</span>
            </div>
            <p className="text-[#F1F7F2] leading-relaxed">
              {matchingMetrics.disintermediationBenefit} Both parties reside in {harvest.district},
              minimizing long-haul transit shrinkage and eliminating multi-tiered wholesale commission.
            </p>
            <div className="flex flex-wrap gap-4 text-[11px] text-[#A9BBAE] pt-1 font-mono">
              <span>Spread: {matchingMetrics.priceGap}</span>
              <span>•</span>
              <span>Capacity: {matchingMetrics.quantityFeasibility}</span>
              <span>•</span>
              <span>Lifecycle: open → reserved → fulfilled</span>
            </div>
          </div>
        )}
      </div>
    </section>
  );
};
