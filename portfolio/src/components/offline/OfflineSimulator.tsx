'use client';

import React, { useState } from 'react';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import {
  Wifi,
  WifiOff,
  Database,
  Cloud,
  CheckCircle2,
  AlertCircle,
  HardDrive,
  ShieldCheck,
} from 'lucide-react';

export const OfflineSimulator: React.FC = () => {
  const [isOnline, setIsOnline] = useState(true);

  const capabilities = [
    {
      feature: 'Farmer Profile & Credentials',
      onlineState: 'Synchronized with Firebase Auth & Cloud Firestore',
      offlineState: 'Cached in SharedPreferences; full profile access',
      availableOffline: true,
    },
    {
      feature: 'Farm Profiles & Acreage Coordinates',
      onlineState: 'GPS lookup, live boundary edits, and cloud backup',
      offlineState: 'Last saved farms & soil profiles accessible locally',
      availableOffline: true,
    },
    {
      feature: 'Crop Recommendation Catalog',
      onlineState: 'NVIDIA AI structured scoring with live weather',
      offlineState: 'Deterministic local knowledge-base fallback',
      availableOffline: true,
    },
    {
      feature: 'Mandi Market Prices',
      onlineState: 'Live AGMARKNET 2.0 streaming with 7-day history',
      offlineState: 'Shows last available snapshot marked (stale: true)',
      availableOffline: true,
    },
    {
      feature: 'Daily Tasks & Expense Logs',
      onlineState: 'Real-time Firestore sync and conflict resolution',
      offlineState: 'Written locally to device; synced on reconnect',
      availableOffline: true,
    },
    {
      feature: 'AI Conversational Assistant',
      onlineState: 'Active Groq streaming with dynamic function calling',
      offlineState: 'Persistent past chat history cached locally',
      availableOffline: 'Partial (History readable; new queries require signal)',
    },
    {
      feature: 'Camera Leaf Disease Vision',
      onlineState: 'NVIDIA Nemotron Nano Omni 30B multimodal reasoning',
      offlineState: 'Image queued on device for upload upon reconnection',
      availableOffline: false,
    },
  ];

  return (
    <section id="offline" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Architectural Resiliency
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Designed for connectivity that{' '}
            <span className="text-emerald-400">isn&apos;t always perfect.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Rural agricultural fields experience frequent dead zones. VidhAI employs a
            SharedPreferences-backed local cache architecture paired with Cloud Firestore, ensuring
            essential farm data and task ledgers remain accessible without internet.
          </p>

          {/* Interactive Simulation Toggle */}
          <div className="pt-4 flex items-center justify-center gap-3">
            <Button
              variant={isOnline ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setIsOnline(true)}
              icon={<Wifi className="w-4 h-4 text-emerald-400" />}
            >
              Simulate: Online (Cloud Mode)
            </Button>
            <Button
              variant={!isOnline ? 'primary' : 'secondary'}
              size="sm"
              onClick={() => setIsOnline(false)}
              icon={<WifiOff className="w-4 h-4 text-amber-400" />}
            >
              Simulate: Offline (Local Cache Mode)
            </Button>
          </div>
        </div>

        {/* Connectivity Status Banner */}
        <div
          className={`max-w-4xl mx-auto mb-10 p-5 rounded-2xl border transition-all duration-300 flex flex-wrap items-center justify-between gap-4 ${
            isOnline
              ? 'bg-[#14261A] border-emerald-500/50 shadow-lg shadow-emerald-950/40'
              : 'bg-[#1A2318] border-amber-500/50 shadow-lg shadow-amber-950/40'
          }`}
        >
          <div className="flex items-center gap-3">
            <div
              className={`p-3 rounded-xl ${
                isOnline ? 'bg-emerald-950 text-emerald-400' : 'bg-amber-950 text-amber-400'
              }`}
            >
              {isOnline ? <Cloud className="w-6 h-6" /> : <HardDrive className="w-6 h-6" />}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold text-[#F1F7F2]">
                  {isOnline ? 'Full Cloud Mode' : 'Local Storage Mode (SharedPreferences)'}
                </h3>
                <span
                  className={`text-[10px] font-mono px-2 py-0.5 rounded-full ${
                    isOnline
                      ? 'bg-emerald-950 text-emerald-400 border border-emerald-500/40'
                      : 'bg-amber-950 text-amber-300 border border-amber-500/40'
                  }`}
                >
                  {isOnline ? 'Live Latency: ~180ms' : 'Offline Safe'}
                </span>
              </div>
              <p className="text-xs text-[#A9BBAE] mt-0.5">
                {isOnline
                  ? 'Cloud Firestore, Groq streaming, NVIDIA reasoning, and live AGMARKNET APIs active.'
                  : 'Connectivity lost. App falls back to local SharedPreferences and deterministic knowledge base.'}
              </p>
            </div>
          </div>

          <div className="text-right text-xs font-mono text-[#718776]">
            {isOnline ? 'Firestore: CONNECTED' : 'Firestore: OFFLINE CACHED'}
          </div>
        </div>

        {/* Feature Behavior Comparison Table */}
        <div className="max-w-4xl mx-auto rounded-2xl bg-[#122217] border border-[#233E2B] overflow-hidden shadow-xl">
          <div className="p-4 bg-[#0B170E] border-b border-[#233E2B] flex items-center justify-between text-xs font-mono uppercase text-[#A9BBAE]">
            <span>System Capability</span>
            <span>Behavior in Current State</span>
          </div>

          <div className="divide-y divide-[#1E3626]">
            {capabilities.map((cap, idx) => (
              <div
                key={idx}
                className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs"
              >
                <div className="space-y-0.5 max-w-sm">
                  <span className="font-semibold text-[#F1F7F2]">{cap.feature}</span>
                  <div className="text-[11px] text-[#718776]">
                    {isOnline ? cap.onlineState : cap.offlineState}
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {cap.availableOffline === true && (
                    <span className="px-2.5 py-1 rounded-full bg-emerald-950/80 text-emerald-300 border border-emerald-500/40 text-[11px] flex items-center gap-1">
                      <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                      <span>Available Offline</span>
                    </span>
                  )}
                  {typeof cap.availableOffline === 'string' && (
                    <span className="px-2.5 py-1 rounded-full bg-blue-950/80 text-blue-300 border border-blue-500/40 text-[11px] flex items-center gap-1">
                      <Database className="w-3 h-3 text-blue-400" />
                      <span>{cap.availableOffline}</span>
                    </span>
                  )}
                  {cap.availableOffline === false && (
                    <span className="px-2.5 py-1 rounded-full bg-amber-950/80 text-amber-300 border border-amber-500/40 text-[11px] flex items-center gap-1">
                      <AlertCircle className="w-3 h-3 text-amber-400" />
                      <span>Requires Internet</span>
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Veracity Note */}
        <div className="mt-8 max-w-4xl mx-auto p-4 rounded-xl bg-[#0B170E] border border-[#233E2B] flex items-center justify-between gap-3 text-xs text-[#718776]">
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>
              <strong>Accurate Architecture:</strong> VidhAI utilizes SharedPreferences-based local
              caching for persistent offline-friendly state (cached market results, cached weather,
              cached farms/profile/tasks, and local preferences). Cloud data synchronizes with
              Firestore upon reconnection.
            </span>
          </div>
        </div>
      </div>
    </section>
  );
};
