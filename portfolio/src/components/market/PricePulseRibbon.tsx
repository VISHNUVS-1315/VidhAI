'use client';

import React, { useState } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';
import { Building2 } from 'lucide-react';

interface PricePulseRibbonProps {
  commodity?: string;
  market?: string;
  minPrice?: number;
  modalPrice?: number;
  maxPrice?: number;
  trend?: string;
}

export const PricePulseRibbon: React.FC<PricePulseRibbonProps> = ({
  commodity = 'Tomato (Hybrid)',
  market = 'Tiruppur APMC Mandi',
  minPrice = 22,
  modalPrice = 28,
  maxPrice = 34,
  trend = '+14.2% weekly',
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [activeNode, setActiveNode] = useState<'min' | 'modal' | 'max'>('modal');

  return (
    <div
      data-context-label="READ SIGNAL"
      className="p-6 rounded-3xl bg-[#0E1C12]/95 border border-[#233E2B] glow-card mb-10 overflow-hidden relative"
    >
      {/* Background ambient gradient */}
      <div className="absolute top-0 right-0 w-80 h-80 bg-emerald-600/10 rounded-full blur-[90px] pointer-events-none" />

      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#233E2B] pb-4 mb-6">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono uppercase text-emerald-400 font-semibold tracking-wider">
              Signature Motion Pattern: Price Pulse Ribbon
            </span>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 border border-emerald-500/30 text-emerald-300">
              AGMARKNET 2.0 Normalized
            </span>
          </div>
          <h3 className="text-lg font-bold text-[#F1F7F2] mt-1">{commodity} — Live Waveform</h3>
        </div>

        <div className="flex items-center gap-2 text-xs font-mono text-[#A9BBAE]">
          <Building2 className="w-3.5 h-3.5 text-emerald-400" />
          <span>{market}</span>
          <span className="text-[#718776]">•</span>
          <span className="text-emerald-400 font-semibold">{trend}</span>
        </div>
      </div>

      {/* Animated SVG Price Ribbon */}
      <div className="relative w-full h-44 flex items-center justify-center my-2">
        <svg
          className="w-full h-full"
          viewBox="0 0 700 160"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            {/* Area fill gradient */}
            <linearGradient id="ribbon-area" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2E7D32" stopOpacity="0.4" />
              <stop offset="100%" stopColor="#0B170E" stopOpacity="0.0" />
            </linearGradient>

            {/* Stroke glow */}
            <linearGradient id="ribbon-stroke" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor="#1E3E26" />
              <stop offset="30%" stopColor="#4CAF50" />
              <stop offset="70%" stopColor="#81C784" />
              <stop offset="100%" stopColor="#F59E0B" />
            </linearGradient>
          </defs>

          {/* Background baseline grid */}
          <line
            x1="30"
            y1="130"
            x2="670"
            y2="130"
            stroke="#192F20"
            strokeWidth="1"
            strokeDasharray="4 4"
          />
          <line
            x1="30"
            y1="80"
            x2="670"
            y2="80"
            stroke="#192F20"
            strokeWidth="1"
            strokeDasharray="4 4"
          />
          <line
            x1="30"
            y1="30"
            x2="670"
            y2="30"
            stroke="#192F20"
            strokeWidth="1"
            strokeDasharray="4 4"
          />

          {/* Area Fill */}
          <path
            d="M 40 130 C 120 120, 200 110, 260 125 C 320 140, 390 60, 470 50 C 540 40, 600 70, 660 40 L 660 145 L 40 145 Z"
            fill="url(#ribbon-area)"
          />

          {/* Main Price Ribbon Waveform */}
          <path
            d="M 40 130 C 120 120, 200 110, 260 125 C 320 140, 390 60, 470 50 C 540 40, 600 70, 660 40"
            stroke="url(#ribbon-stroke)"
            strokeWidth="3"
            strokeLinecap="round"
            className={prefersReducedMotion ? '' : 'animate-signal'}
          />

          {/* Node 1: Min Price (x=260, y=125) */}
          <g
            className="cursor-pointer"
            onClick={() => setActiveNode('min')}
            tabIndex={0}
            role="button"
          >
            <circle
              cx="260"
              cy="125"
              r={activeNode === 'min' ? 7 : 5}
              fill="#2E7D32"
              stroke="#81C784"
              strokeWidth="2"
            />
            {activeNode === 'min' && (
              <circle
                cx="260"
                cy="125"
                r="12"
                stroke="#81C784"
                strokeWidth="1"
                className="animate-ping opacity-60"
              />
            )}
            <text x="260" y="152" fill="#A9BBAE" fontSize="10" textAnchor="middle" fontFamily="monospace">
              Min ₹{minPrice}/kg
            </text>
          </g>

          {/* Node 2: Modal Price (x=470, y=50) */}
          <g
            className="cursor-pointer"
            onClick={() => setActiveNode('modal')}
            tabIndex={0}
            role="button"
          >
            <circle
              cx="470"
              cy="50"
              r={activeNode === 'modal' ? 8 : 6}
              fill="#4CAF50"
              stroke="#F1F7F2"
              strokeWidth="2"
            />
            {activeNode === 'modal' && (
              <circle
                cx="470"
                cy="50"
                r="14"
                stroke="#4CAF50"
                strokeWidth="1.5"
                className="animate-ping opacity-75"
              />
            )}
            <text x="470" y="32" fill="#F1F7F2" fontSize="12" fontWeight="bold" textAnchor="middle" fontFamily="monospace">
              Modal ₹{modalPrice}/kg
            </text>
          </g>

          {/* Node 3: Max Price (x=660, y=40) */}
          <g
            className="cursor-pointer"
            onClick={() => setActiveNode('max')}
            tabIndex={0}
            role="button"
          >
            <circle
              cx="660"
              cy="40"
              r={activeNode === 'max' ? 7 : 5}
              fill="#F59E0B"
              stroke="#FEF3C7"
              strokeWidth="2"
            />
            {activeNode === 'max' && (
              <circle
                cx="660"
                cy="40"
                r="12"
                stroke="#F59E0B"
                strokeWidth="1"
                className="animate-ping opacity-60"
              />
            )}
            <text x="640" y="24" fill="#F59E0B" fontSize="10" textAnchor="middle" fontFamily="monospace">
              Peak ₹{maxPrice}/kg
            </text>
          </g>
        </svg>
      </div>

      {/* Ribbon Resolution Footer */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-3 border-t border-[#1F3927]">
        <div
          onClick={() => setActiveNode('min')}
          className={`p-2.5 rounded-xl border text-center transition-all cursor-pointer ${
            activeNode === 'min'
              ? 'bg-emerald-950/80 border-emerald-400 shadow-sm'
              : 'bg-[#0B170E] border-[#233E2B]'
          }`}
        >
          <span className="text-[10px] font-mono text-[#718776] uppercase block">Minimum Recorded</span>
          <span className="text-sm font-mono font-bold text-emerald-300">₹{minPrice} / kg</span>
        </div>

        <div
          onClick={() => setActiveNode('modal')}
          className={`p-2.5 rounded-xl border text-center transition-all cursor-pointer ${
            activeNode === 'modal'
              ? 'bg-emerald-950/90 border-emerald-400 shadow-[0_0_15px_rgba(76,175,108,0.3)]'
              : 'bg-[#0B170E] border-[#233E2B]'
          }`}
        >
          <span className="text-[10px] font-mono text-emerald-400 uppercase font-semibold block">
            Modal Fair Market Price
          </span>
          <span className="text-base font-mono font-bold text-[#F1F7F2]">₹{modalPrice} / kg</span>
        </div>

        <div
          onClick={() => setActiveNode('max')}
          className={`p-2.5 rounded-xl border text-center transition-all cursor-pointer ${
            activeNode === 'max'
              ? 'bg-amber-950/70 border-amber-400 shadow-sm'
              : 'bg-[#0B170E] border-[#233E2B]'
          }`}
        >
          <span className="text-[10px] font-mono text-[#718776] uppercase block">Maximum Arrival</span>
          <span className="text-sm font-mono font-bold text-amber-300">₹{maxPrice} / kg</span>
        </div>
      </div>
    </div>
  );
};
