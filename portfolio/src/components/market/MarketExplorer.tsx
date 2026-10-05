'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { MOCK_MANDI_DATA } from '@/data/mockData';
import { PricePulseRibbon } from '@/components/market/PricePulseRibbon';
import {
  TrendingUp,
  ArrowUpRight,
  RefreshCw,
  ShieldCheck,
  Building2,
} from 'lucide-react';

export const MarketExplorer: React.FC = () => {
  const [selectedCommodity, setSelectedCommodity] = useState<string>('Tomato');
  const [isRefreshing, setIsRefreshing] = useState(false);

  const currentRecord =
    MOCK_MANDI_DATA.find((r) => r.commodity === selectedCommodity) || MOCK_MANDI_DATA[0];

  const handleRefresh = () => {
    setIsRefreshing(true);
    setTimeout(() => setIsRefreshing(false), 500);
  };

  return (
    <section id="market" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <div className="flex items-center justify-center gap-2">
            <Badge variant="verified" size="sm">
              Official AGMARKNET 2.0 Integration
            </Badge>
            <Badge variant="demo" size="sm">
              Illustrative Scenario
            </Badge>
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Mandi prices, normalized to <span className="text-emerald-400">₹ / kg.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            The VidhAI backend queries the official AGMARKNET 2.0 API with a data.gov.in AGMARKNET server-side fallback.
            Raw prices quoted in quintals and bags are automatically normalized into transparent per-kilogram
            benchmarks with a 1-hour server-side market snapshot cache for resilience, fallback handling and rate-limit protection.
          </p>
          <div className="pt-1 flex items-center justify-center gap-2 text-[11px] font-mono text-[#718776]">
            <span className="text-emerald-400 font-semibold">IMPLEMENTATION:</span>
            <span>AGMARKNET 2.0 Provider (`functions/src/marketData.ts`) + 1-hr Server-Side Snapshot Cache</span>
          </div>
        </div>

        {/* Signature Motion: Price Pulse Ribbon */}
        <div className="max-w-4xl mx-auto mb-10">
          <PricePulseRibbon
            commodity={`${currentRecord.commodity} (${currentRecord.variety})`}
            market={currentRecord.market}
            minPrice={currentRecord.minPricePerKg}
            modalPrice={currentRecord.modalPricePerKg}
            maxPrice={currentRecord.maxPricePerKg}
            trend={currentRecord.trend}
          />
        </div>

        {/* Commodity Filter Bar */}
        <div className="max-w-4xl mx-auto mb-8 flex flex-wrap items-center justify-between gap-3 p-3 rounded-2xl bg-[#122217] border border-[#233E2B]">
          <div className="flex items-center gap-2 overflow-x-auto">
            {MOCK_MANDI_DATA.map((record) => (
              <button
                key={record.commodity}
                onClick={() => setSelectedCommodity(record.commodity)}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-medium transition-colors cursor-pointer border ${
                  selectedCommodity === record.commodity
                    ? 'bg-emerald-950 text-emerald-300 border-emerald-500/60 shadow-sm'
                    : 'bg-[#0B170E] text-[#A9BBAE] border-[#233E2B] hover:text-[#F1F7F2]'
                }`}
              >
                {record.commodity}
              </button>
            ))}
          </div>

          <button
            onClick={handleRefresh}
            aria-label="Refresh mandi rates"
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#A9BBAE] hover:text-[#F1F7F2] cursor-pointer"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
            <span>Simulate Cache Refresh</span>
          </button>
        </div>

        {/* Main Mandi Price Dashboard Card */}
        <div className="max-w-4xl mx-auto">
          <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-6">
            {/* Header: Market Name & Date */}
            <div className="flex flex-wrap items-center justify-between gap-4 border-b border-[#233E2B] pb-6">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="text-2xl font-bold text-[#F1F7F2]">{currentRecord.commodity}</h3>
                  <span className="text-xs px-2.5 py-0.5 rounded-full bg-[#0B170E] border border-[#233E2B] text-emerald-300 font-mono">
                    {currentRecord.variety}
                  </span>
                </div>
                <div className="flex items-center gap-3 text-xs text-[#A9BBAE]">
                  <span className="flex items-center gap-1">
                    <Building2 className="w-3.5 h-3.5 text-emerald-400" />
                    {currentRecord.market}, {currentRecord.district}
                  </span>
                  <span>•</span>
                  <span>{currentRecord.state}</span>
                </div>
              </div>

              <div className="flex flex-col items-end">
                <span className="text-3xl font-extrabold text-emerald-400 font-mono">
                  ₹{currentRecord.modalPricePerKg.toFixed(2)}
                  <span className="text-sm font-normal text-[#A9BBAE] ml-1">/ kg</span>
                </span>
                <div className="flex items-center gap-1 text-xs text-emerald-400 font-medium">
                  <ArrowUpRight className="w-4 h-4" />
                  <span>Modal Market Benchmark</span>
                </div>
              </div>
            </div>

            {/* Price Metric Spread Cards (Min, Modal, Max) */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-center">
              <div className="p-4 rounded-2xl bg-[#0B170E] border border-[#233E2B]">
                <span className="text-[11px] font-mono uppercase text-[#718776] block mb-1">
                  Min Reported
                </span>
                <span className="text-xl font-bold text-[#F1F7F2] font-mono">
                  ₹{currentRecord.minPricePerKg.toFixed(2)} / kg
                </span>
                <span className="text-[10px] text-[#718776] block mt-0.5">₹{(currentRecord.minPricePerKg * 100).toFixed(0)} / Quintal</span>
              </div>

              <div className="p-4 rounded-2xl bg-[#16291D] border border-emerald-500/40">
                <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold block mb-1">
                  Modal Average
                </span>
                <span className="text-xl font-bold text-emerald-300 font-mono">
                  ₹{currentRecord.modalPricePerKg.toFixed(2)} / kg
                </span>
                <span className="text-[10px] text-emerald-400/80 block mt-0.5">₹{(currentRecord.modalPricePerKg * 100).toFixed(0)} / Quintal</span>
              </div>

              <div className="p-4 rounded-2xl bg-[#0B170E] border border-[#233E2B]">
                <span className="text-[11px] font-mono uppercase text-[#718776] block mb-1">
                  Max Reported
                </span>
                <span className="text-xl font-bold text-[#F1F7F2] font-mono">
                  ₹{currentRecord.maxPricePerKg.toFixed(2)} / kg
                </span>
                <span className="text-[10px] text-[#718776] block mt-0.5">₹{(currentRecord.maxPricePerKg * 100).toFixed(0)} / Quintal</span>
              </div>
            </div>

            {/* 7-Day History Chart Visualization */}
            <div className="p-5 rounded-2xl bg-[#0B170E] border border-[#233E2B] space-y-4">
              <div className="flex items-center justify-between text-xs font-semibold text-[#A9BBAE]">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-emerald-400" />
                  <span>7-Day Daily Modal Price Trend (Normalized ₹ / kg)</span>
                </div>
                <span className="text-[10px] font-mono text-[#718776]">Daily Reported Averages</span>
              </div>

              {/* Bar Chart Representation */}
              <div className="flex items-end justify-between gap-2 h-36 pt-4 px-2">
                {currentRecord.history7Days.map((point, pIdx) => {
                  const maxVal = Math.max(...currentRecord.history7Days.map((p) => p.price));
                  const heightPercent = Math.max(25, (point.price / maxVal) * 100);
                  const isLatest = pIdx === currentRecord.history7Days.length - 1;

                  return (
                    <div key={pIdx} className="flex-1 flex flex-col items-center gap-1.5 h-full justify-end">
                      <span className="text-[10px] font-mono text-[#A9BBAE]">
                        ₹{point.price.toFixed(1)}
                      </span>
                      <div
                        style={{ height: `${heightPercent}%` }}
                        className={`w-full max-w-[42px] rounded-t-lg transition-all duration-500 ${
                          isLatest
                            ? 'bg-gradient-to-t from-[#2E7D32] to-[#4CAF6C] border-t border-emerald-300'
                            : 'bg-[#1E3626] hover:bg-[#2E7D32]/60'
                        }`}
                      />
                      <span
                        className={`text-[9px] font-mono ${
                          isLatest ? 'text-emerald-400 font-semibold' : 'text-[#718776]'
                        }`}
                      >
                        {point.day}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Official Source & Resiliency Architecture Footer */}
            <div className="pt-4 border-t border-[#233E2B] flex flex-wrap items-center justify-between gap-3 text-xs text-[#A9BBAE]">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400" />
                <span>
                  Official Source:{' '}
                  <strong className="text-[#F1F7F2]">AGMARKNET (data.gov.in)</strong> • Directorate
                  of Marketing &amp; Inspection
                </span>
              </div>
              <div className="text-[11px] font-mono text-[#718776]">
                1-Hour Server-Side Snapshot Cache (`functions/src/marketService.ts`)
              </div>
            </div>
          </Card>
        </div>
      </div>
    </section>
  );
};
