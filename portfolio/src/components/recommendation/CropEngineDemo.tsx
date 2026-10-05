'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { ContextBuildEngine } from '@/components/motion/ContextBuildEngine';
import { MOCK_CROP_RECOMMENDATIONS } from '@/data/mockData';
import { Sliders, ShieldCheck, Clock, Droplets, AlertCircle } from 'lucide-react';

export const CropEngineDemo: React.FC = () => {
  const [selectedSoil, setSelectedSoil] = useState('Red Loamy');
  const [selectedSeason, setSelectedSeason] = useState('Rabi');
  const [selectedWater, setSelectedWater] = useState('Medium');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [budgetPerAcre, setBudgetPerAcre] = useState(35000);

  const filteredCrops = MOCK_CROP_RECOMMENDATIONS.filter((crop) => {
    if (selectedCategory !== 'All' && crop.category !== selectedCategory) return false;
    if (crop.estimatedCostPerAcre > budgetPerAcre + 10000) return false;
    return true;
  });

  return (
    <section id="recommendation" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            5-Tier Recommendation Pipeline
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Precision crop selection, <span className="text-emerald-400">grounded in soil science.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            VidhAI does not make random guesses. Twelve field factors pass into a deterministic
            scoring catalog, validated against live NVIDIA NIM agronomic models with a verified local
            offline knowledge base fallback.
          </p>
        </div>

        {/* Signature Motion: Context Build Animation Engine */}
        <div className="mb-12">
          <ContextBuildEngine />
        </div>

        {/* Interactive Parameter Control Bar */}
        <Card className="bg-[#122217] border-[#233E2B] p-6 mb-10 glow-card">
          <div className="flex items-center gap-2 mb-4 text-xs font-mono uppercase text-emerald-400 font-semibold">
            <Sliders className="w-4 h-4" />
            <span>Farm Inputs & Decision Parameters (Live Simulation)</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
            {/* Soil Selector */}
            <div>
              <label className="text-[11px] font-medium text-[#A9BBAE] block mb-1.5">
                Soil Type
              </label>
              <select
                value={selectedSoil}
                onChange={(e) => setSelectedSoil(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2] focus:outline-none focus:border-emerald-500"
              >
                <option value="Red Loamy">Red Loamy</option>
                <option value="Black Cotton">Black Cotton Clay</option>
                <option value="Sandy Loam">Sandy Loam</option>
                <option value="Alluvial">Alluvial</option>
              </select>
            </div>

            {/* Season Selector */}
            <div>
              <label className="text-[11px] font-medium text-[#A9BBAE] block mb-1.5">
                Current Season
              </label>
              <select
                value={selectedSeason}
                onChange={(e) => setSelectedSeason(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2] focus:outline-none focus:border-emerald-500"
              >
                <option value="Rabi">Rabi (Winter/Post-Monsoon)</option>
                <option value="Kharif">Kharif (Monsoon)</option>
                <option value="Zaid">Zaid (Summer)</option>
              </select>
            </div>

            {/* Water Availability */}
            <div>
              <label className="text-[11px] font-medium text-[#A9BBAE] block mb-1.5">
                Water Availability
              </label>
              <select
                value={selectedWater}
                onChange={(e) => setSelectedWater(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2] focus:outline-none focus:border-emerald-500"
              >
                <option value="Medium">Medium (Borewell / Drip)</option>
                <option value="Low">Low (Rainfed / Deficit)</option>
                <option value="High">High (Perennial Canal)</option>
              </select>
            </div>

            {/* Category Filter */}
            <div>
              <label className="text-[11px] font-medium text-[#A9BBAE] block mb-1.5">
                Category Preference
              </label>
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2] focus:outline-none focus:border-emerald-500"
              >
                <option value="All">All Categories</option>
                <option value="Vegetables">Vegetables</option>
                <option value="Oilseeds">Oilseeds</option>
                <option value="Pulses">Pulses</option>
                <option value="Cereals">Cereals</option>
                <option value="Cash Crops">Cash Crops</option>
              </select>
            </div>

            {/* Budget Range */}
            <div>
              <div className="flex justify-between items-center mb-1.5">
                <label className="text-[11px] font-medium text-[#A9BBAE]">
                  Max Budget / Acre
                </label>
                <span className="text-xs font-mono text-emerald-400">
                  ₹{budgetPerAcre.toLocaleString('en-IN')}
                </span>
              </div>
              <input
                type="range"
                min="15000"
                max="50000"
                step="5000"
                value={budgetPerAcre}
                onChange={(e) => setBudgetPerAcre(Number(e.target.value))}
                className="w-full accent-emerald-500 h-1.5 bg-[#0B170E] rounded-lg cursor-pointer"
              />
            </div>
          </div>
        </Card>

        {/* Results Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredCrops.map((crop) => (
            <Card
              key={crop.id}
              interactive
              className="bg-[#14261A] border-[#233E2B] p-6 flex flex-col justify-between space-y-4"
            >
              <div>
                <div className="flex items-start justify-between gap-2 mb-2">
                  <div>
                    <h3 className="text-base font-bold text-[#F1F7F2]">{crop.name}</h3>
                    <span className="text-xs italic text-[#718776]">{crop.scientificName}</span>
                  </div>
                  <div className="flex flex-col items-end">
                    <span className="text-sm font-extrabold text-emerald-400 font-mono">
                      {crop.suitabilityScore}%
                    </span>
                    <span className="text-[10px] text-[#718776]">Suitability</span>
                  </div>
                </div>

                <p className="text-xs text-[#A9BBAE] leading-relaxed mb-4">
                  {crop.agronomicReasoning}
                </p>

                {/* Technical Specs Tags */}
                <div className="grid grid-cols-3 gap-2 py-3 border-y border-[#1E3626] text-[11px]">
                  <div className="space-y-0.5">
                    <span className="text-[10px] text-[#718776] flex items-center gap-1">
                      <Clock className="w-3 h-3" /> Duration
                    </span>
                    <span className="text-[#F1F7F2] font-medium">{crop.durationDays}</span>
                  </div>
                  <div className="space-y-0.5">
                    <span className="text-[10px] text-[#718776] flex items-center gap-1">
                      <Droplets className="w-3 h-3" /> Water
                    </span>
                    <span className="text-[#F1F7F2] font-medium">{crop.waterRequirement}</span>
                  </div>
                  <div className="space-y-0.5">
                    <span className="text-[10px] text-[#718776] flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" /> Risk
                    </span>
                    <span
                      className={`font-medium ${
                        crop.riskLevel === 'Low'
                          ? 'text-emerald-400'
                          : crop.riskLevel === 'Moderate'
                          ? 'text-amber-400'
                          : 'text-red-400'
                      }`}
                    >
                      {crop.riskLevel}
                    </span>
                  </div>
                </div>
              </div>

              {/* Financial & Yield Estimates */}
              <div className="p-3 rounded-xl bg-[#0B170E] border border-[#1E3626] text-xs space-y-1">
                <div className="flex justify-between items-center text-[11px]">
                  <span className="text-[#718776]">Estimated Expense / Acre:</span>
                  <span className="font-mono text-[#F1F7F2] font-semibold">
                    ₹{crop.estimatedCostPerAcre.toLocaleString('en-IN')}
                  </span>
                </div>
                <div className="flex justify-between items-center text-[11px]">
                  <span className="text-[#718776]">Expected Yield:</span>
                  <span className="font-mono text-emerald-300">{crop.expectedYieldQuintal}</span>
                </div>
                <span className="text-[10px] text-[#718776] italic block pt-1">
                  Illustrative recommendation derived from `functions/src/cropData.ts`
                </span>
              </div>
            </Card>
          ))}
        </div>

        {/* Bottom Fallback Hierarchy Note */}
        <div className="mt-12 p-4 rounded-2xl bg-[#122217] border border-[#233E2B] flex flex-col md:flex-row items-center justify-between gap-4 text-xs text-[#A9BBAE]">
          <div className="flex items-center gap-2 text-emerald-400 font-semibold">
            <ShieldCheck className="w-4 h-4 shrink-0" />
            <span>5-Tier Execution Order Verified:</span>
          </div>
          <div className="flex flex-wrap items-center gap-2 text-[11px] font-mono text-[#F1F7F2]">
            <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-[#233E2B]">
              1. Live NVIDIA AI (/crop/ai-recommend)
            </span>
            <span className="text-[#718776]">→</span>
            <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-[#233E2B]">
              2. Scored Engine (/crop/recommend)
            </span>
            <span className="text-[#718776]">→</span>
            <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-[#233E2B]">
              3. Context-Hash Cache
            </span>
            <span className="text-[#718776]">→</span>
            <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-[#233E2B]">
              4. Realtime AI Ranker
            </span>
            <span className="text-[#718776]">→</span>
            <span className="px-2 py-0.5 rounded bg-[#0B170E] border border-[#233E2B]">
              5. Local Knowledge Base
            </span>
          </div>
        </div>
      </div>
    </section>
  );
};
