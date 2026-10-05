'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { Sprout, ShoppingBag, Handshake, CheckCircle2, Sparkles } from 'lucide-react';

export const MatchFlowDiagram: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [matchState, setMatchState] = useState<'idle' | 'routing' | 'connected'>('connected');

  return (
    <div
      data-context-label="SEE CONNECTION"
      className="p-6 sm:p-8 rounded-3xl bg-[#0E1C12]/95 border border-[#233E2B] glow-card mb-10 overflow-hidden relative"
    >
      {/* Background ambient glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-emerald-600/10 rounded-full blur-[100px] pointer-events-none" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#233E2B] pb-4 mb-6">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold tracking-wider">
              Signature Motion Pattern: Match Flow
            </span>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 border border-emerald-500/30 text-emerald-300">
              Illustrative Scenario
            </span>
          </div>
          <h3 className="text-xl font-bold text-[#F1F7F2] mt-1">
            Pre-Harvest Supply ↔ Consumer Demand Connection
          </h3>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              setMatchState('routing');
              setTimeout(() => setMatchState('connected'), 1200);
            }}
            className="px-3 py-1.5 rounded-xl bg-emerald-950 border border-emerald-500/40 text-xs font-mono text-emerald-300 hover:bg-emerald-900 transition-colors cursor-pointer flex items-center gap-1.5"
          >
            <Sparkles className="w-3.5 h-3.5 text-emerald-400" />
            <span>Re-simulate Match</span>
          </button>
        </div>
      </div>

      {/* 3-Column Match Layout: Left (Farmer Post) | Center (VidhAI Hub) | Right (Buyer Demand) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center relative">
        {/* Left Card: Farmer Pre-Harvest Listing */}
        <div className="lg:col-span-4 p-5 rounded-2xl bg-[#14261A] border border-[#233E2B] space-y-3 relative">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-mono uppercase text-emerald-400 font-semibold">
              Pre-Harvest Listing (Active)
            </span>
            <span className="text-[10px] font-mono text-[#718776]">Plot #2</span>
          </div>

          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
              <Sprout className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xs text-[#718776] font-mono">FARMER (DEMO)</div>
              <h4 className="text-sm font-bold text-[#F1F7F2]">Hybrid Tomato (S-14)</h4>
            </div>
          </div>

          <div className="space-y-1.5 text-xs text-[#A9BBAE] bg-[#0B170E] p-3 rounded-xl border border-[#1E3626]">
            <div className="flex justify-between">
              <span>Estimated Harvest:</span>
              <span className="font-mono text-[#F1F7F2]">1,200 kg</span>
            </div>
            <div className="flex justify-between">
              <span>Target Harvest Date:</span>
              <span className="font-mono text-emerald-400">In 12 Days</span>
            </div>
            <div className="flex justify-between">
              <span>Expected Price:</span>
              <span className="font-mono text-[#F1F7F2]">₹28 / kg</span>
            </div>
            <div className="flex justify-between">
              <span>District:</span>
              <span className="font-mono text-[#718776]">Tiruppur, TN</span>
            </div>
          </div>

          <div className="flex items-center gap-1.5 text-[11px] text-emerald-400 pt-1">
            <CheckCircle2 className="w-3.5 h-3.5" />
            <span>Farm Verified Coordinates Bound</span>
          </div>
        </div>

        {/* Center: VidhAI Match Layer & Traveling SVG Path */}
        <div className="lg:col-span-4 flex flex-col items-center justify-center p-4 relative text-center">
          {/* Animated SVG Conduit */}
          <div className="w-full h-16 relative flex items-center justify-center">
            <svg
              className="w-full h-full"
              viewBox="0 0 300 60"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              {/* Path from Left to Center */}
              <line
                x1="20"
                y1="30"
                x2="150"
                y2="30"
                stroke="#2E7D32"
                strokeWidth="2"
                strokeDasharray={prefersReducedMotion ? 'none' : '6 4'}
                className={prefersReducedMotion ? '' : 'animate-signal'}
              />
              {/* Path from Center to Right */}
              <line
                x1="150"
                y1="30"
                x2="280"
                y2="30"
                stroke="#4CAF50"
                strokeWidth="2"
                strokeDasharray={prefersReducedMotion ? 'none' : '6 4'}
                className={prefersReducedMotion ? '' : 'animate-signal'}
              />
              <circle cx="150" cy="30" r="5" fill="#4CAF50" />
              <circle
                cx="150"
                cy="30"
                r="12"
                stroke="#4CAF50"
                strokeWidth="1"
                className={prefersReducedMotion ? '' : 'animate-ping opacity-60'}
              />
            </svg>
          </div>

          {/* Central Matchmaking Engine Node */}
          <div className="p-3.5 rounded-2xl bg-[#09130B] border border-emerald-500/50 w-full max-w-[240px] shadow-lg">
            <div className="flex items-center justify-center gap-1.5 text-[11px] font-mono text-emerald-400 uppercase font-semibold mb-1">
              <Handshake className="w-4 h-4" />
              <span>VidhAI Match Layer</span>
            </div>
            <div className="text-[11px] text-[#F1F7F2] font-semibold">Bilateral Agronomic Match</div>
            <div className="text-[10px] text-[#A9BBAE] mt-1 font-mono">
              Distance: 38 km • Price Delta: 0% • Sync: 100%
            </div>
          </div>

          <div className="mt-3 text-[10px] font-mono text-emerald-400">
            {matchState === 'routing' ? 'COMPUTING ROUTE...' : 'MATCH COMMITTED'}
          </div>
        </div>

        {/* Right Card: Consumer / Buyer Demand Listing */}
        <div className="lg:col-span-4 p-5 rounded-2xl bg-[#14261A] border border-[#233E2B] space-y-3 relative">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-mono uppercase text-blue-400 font-semibold">
              Consumer Demand Post
            </span>
            <span className="text-[10px] font-mono text-[#718776]">Console: Consumer</span>
          </div>

          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-blue-950 border border-blue-500/40 text-blue-400">
              <ShoppingBag className="w-5 h-5" />
            </div>
            <div>
              <div className="text-xs text-[#718776] font-mono">BUYER (DEMO)</div>
              <h4 className="text-sm font-bold text-[#F1F7F2]">Fresh Produce Outlet</h4>
            </div>
          </div>

          <div className="space-y-1.5 text-xs text-[#A9BBAE] bg-[#0B170E] p-3 rounded-xl border border-[#1E3626]">
            <div className="flex justify-between">
              <span>Demand Volume:</span>
              <span className="font-mono text-[#F1F7F2]">800 kg</span>
            </div>
            <div className="flex justify-between">
              <span>Required By:</span>
              <span className="font-mono text-blue-400">In 14 Days</span>
            </div>
            <div className="flex justify-between">
              <span>Offer Ceiling:</span>
              <span className="font-mono text-[#F1F7F2]">₹28 / kg</span>
            </div>
            <div className="flex justify-between">
              <span>Destination:</span>
              <span className="font-mono text-[#718776]">Coimbatore, TN</span>
            </div>
          </div>

          <div className="flex items-center gap-1.5 text-[11px] text-blue-400 pt-1">
            <CheckCircle2 className="w-3.5 h-3.5" />
            <span>Direct Bilateral Purchase Agreement</span>
          </div>
        </div>
      </div>
    </div>
  );
};
