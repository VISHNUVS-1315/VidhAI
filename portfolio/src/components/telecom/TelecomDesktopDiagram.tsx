'use client';

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  PhoneCall,
  UserCheck,
  AudioWaveform,
  FileText,
  Brain,
  Layers,
  Volume2,
  PhoneForwarded,
  ArrowRight,
  ArrowDown,
  Play,
  Pause,
  RotateCcw,
  Sparkles,
  CloudSun,
  TrendingUp,
  Database,
  CheckCircle2,
  RefreshCw,
  LucideIcon,
} from 'lucide-react';
import { TELECOM_STEPS } from './telecomData';
import { TelecomStepData } from './types';
import { usePrefersReducedMotion } from '@/lib/motion';

interface TelecomDesktopDiagramProps {
  activeStepId: string;
  onSelectStep: (stepId: string) => void;
  hoveredStepId: string | null;
  onHoverStep: (stepId: string | null) => void;
}

const STEP_ICONS: Record<string, LucideIcon> = {
  '01': PhoneCall,
  '02': UserCheck,
  '03': AudioWaveform,
  '04': FileText,
  '05': Brain,
  '06': Layers,
  '07': Volume2,
  '08': PhoneForwarded,
};

export const TelecomDesktopDiagram: React.FC<TelecomDesktopDiagramProps> = ({
  activeStepId,
  onSelectStep,
  hoveredStepId,
  onHoverStep,
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const [isPlaying, setIsPlaying] = useState(false);

  // Auto-play simulation across the 8 steps
  useEffect(() => {
    if (!isPlaying) return;

    const timer = setInterval(() => {
      const currentIndex = TELECOM_STEPS.findIndex((s) => s.id === activeStepId);
      const nextIndex = (currentIndex + 1) % TELECOM_STEPS.length;
      onSelectStep(TELECOM_STEPS[nextIndex].id);
    }, 2800);

    return () => clearInterval(timer);
  }, [isPlaying, activeStepId, onSelectStep]);

  const currentStep =
    TELECOM_STEPS.find((s) => s.id === (hoveredStepId || activeStepId)) ||
    TELECOM_STEPS[0];

  const isCurrentActive = (id: string) =>
    hoveredStepId ? hoveredStepId === id : activeStepId === id;

  return (
    <div className="w-full space-y-8">
      {/* SIMULATION BAR & CONTROLS */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 rounded-2xl bg-white border border-[#E6ECE7] shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-[#1B432C] animate-pulse" />
          <div>
            <span className="text-xs font-mono font-semibold uppercase tracking-wider text-[#1B432C]">
              Interactive Architecture Board
            </span>
            <p className="text-xs text-[#79877E] hidden sm:block">
              Hover over any stage or run the simulation to trace real-time telephony data flow.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className={`inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full text-xs font-medium transition-all ${
              isPlaying
                ? 'bg-[#1B432C] text-white shadow-sm'
                : 'bg-[#FAF8F5] text-[#18201B] border border-[#E6ECE7] hover:border-[#1B432C] hover:bg-[#E8F0EA]'
            }`}
            aria-label={isPlaying ? 'Pause call flow simulation' : 'Play call flow simulation'}
          >
            {isPlaying ? (
              <>
                <Pause className="w-3.5 h-3.5 fill-current" />
                <span>Pause Trace</span>
              </>
            ) : (
              <>
                <Play className="w-3.5 h-3.5 fill-current" />
                <span>Simulate Call Flow</span>
              </>
            )}
          </button>

          <button
            onClick={() => {
              setIsPlaying(false);
              onSelectStep('01');
            }}
            className="p-1.5 rounded-full text-[#79877E] hover:text-[#18201B] hover:bg-[#FAF8F5] transition-colors"
            title="Reset to Step 01"
            aria-label="Reset simulation"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* WIDE ARCHITECTURE CANVAS */}
      <div className="relative rounded-3xl bg-[#FAF8F5] border border-[#E6ECE7] p-6 lg:p-8 overflow-hidden shadow-sm">
        {/* Subtle grid pattern background */}
        <div
          className="absolute inset-0 opacity-[0.03] pointer-events-none"
          style={{
            backgroundImage:
              'radial-gradient(#1B432C 1px, transparent 1px), radial-gradient(#1B432C 1px, #FAF8F5 1px)',
            backgroundSize: '24px 24px',
          }}
        />

        <div className="relative z-10 space-y-8">
          {/* ============================================================== */}
          {/* TIER 1: INBOUND STREAM & ACOUSTIC INGESTION (01 -> 02 -> 03 -> 04) */}
          {/* ============================================================== */}
          <div className="space-y-3">
            <div className="flex items-center justify-between text-xs font-mono text-[#79877E] px-1">
              <span className="flex items-center gap-1.5 font-semibold text-[#1B432C] uppercase tracking-wide">
                <PhoneCall className="w-3.5 h-3.5" />
                Phase I: Telephony Ingestion & Multilingual Speech Recognition
              </span>
              <span className="text-[11px]">Steps 01 — 04</span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-stretch">
              {/* STEP 01 */}
              <StageNode
                step={TELECOM_STEPS[0]}
                isActive={isCurrentActive('01')}
                onSelect={() => onSelectStep('01')}
                onHover={onHoverStep}
                icon={STEP_ICONS['01']}
                badge="Exotel WebSocket"
              />

              {/* STEP 02 */}
              <StageNode
                step={TELECOM_STEPS[1]}
                isActive={isCurrentActive('02')}
                onSelect={() => onSelectStep('02')}
                onHover={onHoverStep}
                icon={STEP_ICONS['02']}
                badge="Caller ID & Onboarding"
              />

              {/* STEP 03 */}
              <StageNode
                step={TELECOM_STEPS[2]}
                isActive={isCurrentActive('03')}
                onSelect={() => onSelectStep('03')}
                onHover={onHoverStep}
                icon={STEP_ICONS['03']}
                badge="VAD & Clean Buffer"
              />

              {/* STEP 04: SPEECH TO TEXT ROUTER (with provider callout branches) */}
              <div
                onMouseEnter={() => onHoverStep('04')}
                onMouseLeave={() => onHoverStep(null)}
                onClick={() => onSelectStep('04')}
                className={`relative flex flex-col justify-between p-4 rounded-2xl transition-all duration-300 cursor-pointer ${
                  isCurrentActive('04')
                    ? 'bg-white border-[#1B432C] shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] ring-2 ring-[#1B432C]/10'
                    : 'bg-white/90 border-[#E6ECE7] hover:border-[#C2D6C6] hover:shadow-xs'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span
                      className={`text-xs font-mono font-bold px-2 py-0.5 rounded-md ${
                        isCurrentActive('04')
                          ? 'bg-[#1B432C] text-white'
                          : 'bg-[#E8F0EA] text-[#1B432C]'
                      }`}
                    >
                      04
                    </span>
                    <span className="text-[10px] font-mono text-[#79877E] uppercase">
                      STT Router
                    </span>
                  </div>
                  <h4 className="font-bold text-[#18201B] text-sm mb-1">
                    Speech-to-Text
                  </h4>
                  <p className="text-[11px] text-[#4F5D54] leading-relaxed mb-3">
                    Language-aware dynamic speech recognition routing:
                  </p>
                </div>

                {/* Sub-provider branches */}
                <div className="space-y-1.5 pt-2 border-t border-[#F0F4F1] text-[10px] font-mono">
                  <div className="flex items-center justify-between bg-[#FAF8F5] px-2 py-1 rounded border border-[#E6ECE7]">
                    <span className="font-semibold text-[#18201B]">Sarvam Saaras v4</span>
                    <span className="text-[#1B432C]">Tamil / Mixed</span>
                  </div>
                  <div className="flex items-center justify-between bg-[#FAF8F5] px-2 py-1 rounded border border-[#E6ECE7]">
                    <span className="font-semibold text-[#18201B]">Groq Whisper Turbo</span>
                    <span className="text-[#1B432C]">EN / Recovery</span>
                  </div>
                  <div className="flex items-center justify-between bg-[#FAF8F5] px-2 py-1 rounded border border-[#E6ECE7]">
                    <span className="font-semibold text-[#18201B]">NVIDIA Parakeet</span>
                    <span className="text-[#1B432C]">Hindi Acoustic</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* DIRECTIONAL CONNECTOR DOWN */}
          <div className="flex items-center justify-center">
            <div className="flex items-center gap-3 px-4 py-1 rounded-full bg-white border border-[#E6ECE7] text-xs font-mono text-[#1B432C] shadow-xs">
              <span>Verified Transcript & Language Detected</span>
              <ArrowDown className="w-3.5 h-3.5 text-[#1B432C]" />
            </div>
          </div>

          {/* ============================================================== */}
          {/* TIER 2: CENTRAL AI LAYER & CONNECTED SERVICES (VISUALLY PROMINENT) */}
          {/* ============================================================== */}
          <div className="space-y-4">
            <div className="flex items-center justify-between text-xs font-mono text-[#79877E] px-1">
              <span className="flex items-center gap-1.5 font-semibold text-[#1B432C] uppercase tracking-wide">
                <Brain className="w-3.5 h-3.5 text-[#1B432C]" />
                Phase II: Core Conversational Intelligence & Agronomic Grounding
              </span>
              <span className="text-[11px]">Steps 05 — 06</span>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
              {/* STEP 05: CENTRAL AI LAYER (PROMINENT HERO BOX) */}
              <div
                onMouseEnter={() => onHoverStep('05')}
                onMouseLeave={() => onHoverStep(null)}
                onClick={() => onSelectStep('05')}
                className={`lg:col-span-6 relative p-6 sm:p-7 rounded-3xl transition-all duration-300 cursor-pointer overflow-hidden ${
                  isCurrentActive('05')
                    ? 'bg-gradient-to-br from-[#1B432C] to-[#143522] text-white shadow-[0_16px_40px_-8px_rgba(27,67,44,0.35)] ring-4 ring-[#1B432C]/20'
                    : 'bg-[#18201B] text-white hover:shadow-[0_12px_32px_-8px_rgba(24,32,27,0.25)] border border-[#2D3830]'
                }`}
              >
                {/* Decorative glowing ambient orb */}
                <div className="absolute top-0 right-0 -mr-12 -mt-12 w-48 h-48 bg-[#4ADE80]/15 rounded-full blur-2xl pointer-events-none" />

                <div className="relative z-10 space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 border border-white/15 text-xs font-mono">
                      <span className="w-2 h-2 rounded-full bg-[#4ADE80] animate-ping" />
                      <span className="font-bold text-white">STAGE 05</span>
                      <span className="text-white/60">·</span>
                      <span className="text-emerald-300 font-semibold">Central AI Core</span>
                    </div>
                    <span className="text-xs font-mono text-white/70 bg-white/5 px-2.5 py-1 rounded-md border border-white/10">
                      Groq openai/gpt-oss-20b
                    </span>
                  </div>

                  <div>
                    <h3 className="text-xl sm:text-2xl font-extrabold text-white tracking-tight flex items-center gap-2.5">
                      <Brain className="w-6 h-6 text-emerald-400" />
                      VidhAI AI + Context Engine
                    </h3>
                    <p className="text-xs sm:text-sm text-white/80 leading-relaxed mt-2 font-normal">
                      Synthesizes real-time caller transcript, language dialects, multi-turn history, and farm land records. Orchestrates structured tool calling and intent resolution.
                    </p>
                  </div>

                  {/* Context Ingestion Chips */}
                  <div className="grid grid-cols-2 gap-2 pt-2 border-t border-white/10 text-[11px] font-mono">
                    <div className="bg-white/10 px-2.5 py-1.5 rounded-lg border border-white/10 flex items-center gap-1.5 text-white/90">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>Live Transcript</span>
                    </div>
                    <div className="bg-white/10 px-2.5 py-1.5 rounded-lg border border-white/10 flex items-center gap-1.5 text-white/90">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>Farmer Memory</span>
                    </div>
                    <div className="bg-white/10 px-2.5 py-1.5 rounded-lg border border-white/10 flex items-center gap-1.5 text-white/90">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>Tool Calling Router</span>
                    </div>
                    <div className="bg-white/10 px-2.5 py-1.5 rounded-lg border border-white/10 flex items-center gap-1.5 text-white/90">
                      <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>Safety Guardrails</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* STEP 06: CONNECTED SERVICES (TRI-SERVICE HUB) */}
              <div
                onMouseEnter={() => onHoverStep('06')}
                onMouseLeave={() => onHoverStep(null)}
                onClick={() => onSelectStep('06')}
                className={`lg:col-span-6 relative p-6 rounded-3xl transition-all duration-300 cursor-pointer ${
                  isCurrentActive('06')
                    ? 'bg-white border-[#1B432C] shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] ring-2 ring-[#1B432C]/10'
                    : 'bg-white border-[#E6ECE7] hover:border-[#C2D6C6]'
                }`}
              >
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs font-mono font-bold px-2 py-0.5 rounded-md ${
                        isCurrentActive('06')
                          ? 'bg-[#1B432C] text-white'
                          : 'bg-[#E8F0EA] text-[#1B432C]'
                      }`}
                    >
                      06
                    </span>
                    <span className="text-xs font-bold text-[#18201B]">
                      Information Retrieval / Action
                    </span>
                  </div>
                  <span className="text-[11px] font-mono text-[#79877E]">
                    Connected Services
                  </span>
                </div>

                <p className="text-xs text-[#4F5D54] mb-4">
                  Tool handlers query authoritative agricultural APIs and persistent cloud memory:
                </p>

                {/* 3 Connected Services Cards */}
                <div className="space-y-2.5">
                  <div className="flex items-center justify-between p-3 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                    <div className="flex items-center gap-2.5">
                      <div className="p-1.5 rounded-lg bg-blue-50 text-blue-700">
                        <CloudSun className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-[#18201B]">Open-Meteo</div>
                        <div className="text-[10px] text-[#79877E]">Hyperlocal Weather Telemetry & Rain Alerts</div>
                      </div>
                    </div>
                    <span className="text-[10px] font-mono text-[#1B432C] font-semibold bg-[#E8F0EA] px-2 py-0.5 rounded">
                      Live
                    </span>
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                    <div className="flex items-center gap-2.5">
                      <div className="p-1.5 rounded-lg bg-emerald-50 text-emerald-700">
                        <TrendingUp className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-[#18201B]">
                          TN Agrimark / Agmarknet v2
                        </div>
                        <div className="text-[10px] text-[#79877E]">Normalized ₹/kg Prices + data.gov.in Fallback</div>
                      </div>
                    </div>
                    <span className="text-[10px] font-mono text-[#1B432C] font-semibold bg-[#E8F0EA] px-2 py-0.5 rounded">
                      ₹/kg
                    </span>
                  </div>

                  <div className="flex items-center justify-between p-3 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7]">
                    <div className="flex items-center gap-2.5">
                      <div className="p-1.5 rounded-lg bg-amber-50 text-amber-700">
                        <Database className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="text-xs font-bold text-[#18201B]">Firebase Firestore</div>
                        <div className="text-[10px] text-[#79877E]">Profiles, Farm Records, Memory & Reminders</div>
                      </div>
                    </div>
                    <span className="text-[10px] font-mono text-[#1B432C] font-semibold bg-[#E8F0EA] px-2 py-0.5 rounded">
                      Persistent
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* DIRECTIONAL CONNECTOR DOWN */}
          <div className="flex items-center justify-center">
            <div className="flex items-center gap-3 px-4 py-1 rounded-full bg-white border border-[#E6ECE7] text-xs font-mono text-[#1B432C] shadow-xs">
              <span>Short Conversational Answer + Safety Filter Applied</span>
              <ArrowDown className="w-3.5 h-3.5 text-[#1B432C]" />
            </div>
          </div>

          {/* ============================================================== */}
          {/* TIER 3: RESPONSE GENERATION & CONTINUOUS TELEPHONY LOOP (07 -> 08) */}
          {/* ============================================================== */}
          <div className="space-y-3">
            <div className="flex items-center justify-between text-xs font-mono text-[#79877E] px-1">
              <span className="flex items-center gap-1.5 font-semibold text-[#1B432C] uppercase tracking-wide">
                <Volume2 className="w-3.5 h-3.5 text-[#1B432C]" />
                Phase III: Voice Synthesis & Multi-Turn Audio Delivery
              </span>
              <span className="text-[11px]">Steps 07 — 08</span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-stretch">
              {/* STEP 07: VOICE GENERATION */}
              <div
                onMouseEnter={() => onHoverStep('07')}
                onMouseLeave={() => onHoverStep(null)}
                onClick={() => onSelectStep('07')}
                className={`p-5 rounded-2xl transition-all duration-300 cursor-pointer ${
                  isCurrentActive('07')
                    ? 'bg-white border-[#1B432C] shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] ring-2 ring-[#1B432C]/10'
                    : 'bg-white border-[#E6ECE7] hover:border-[#C2D6C6]'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs font-mono font-bold px-2 py-0.5 rounded-md ${
                        isCurrentActive('07')
                          ? 'bg-[#1B432C] text-white'
                          : 'bg-[#E8F0EA] text-[#1B432C]'
                      }`}
                    >
                      07
                    </span>
                    <span className="text-sm font-bold text-[#18201B]">
                      Response Generation & TTS
                    </span>
                  </div>
                  <span className="text-[10px] font-mono text-[#79877E]">
                    Safety Checks Applied
                  </span>
                </div>

                <p className="text-xs text-[#4F5D54] mb-3">
                  Agricultural safety checks are applied before routing text to voice engines:
                </p>

                <div className="grid grid-cols-3 gap-2 text-[10px] font-mono">
                  <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7] text-center">
                    <div className="font-bold text-[#18201B]">ElevenLabs</div>
                    <div className="text-[#1B432C] mt-0.5">eleven_flash_v2_5</div>
                    <div className="text-[9px] text-[#79877E] mt-1">Preferred General</div>
                  </div>
                  <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7] text-center">
                    <div className="font-bold text-[#18201B]">Sarvam AI</div>
                    <div className="text-[#1B432C] mt-0.5">Bulbul v3</div>
                    <div className="text-[9px] text-[#79877E] mt-1">Tamil Voice / Fallback</div>
                  </div>
                  <div className="p-2 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7] text-center">
                    <div className="font-bold text-[#18201B]">Shunya Labs</div>
                    <div className="text-[#1B432C] mt-0.5">TTS Engine</div>
                    <div className="text-[9px] text-[#79877E] mt-1">Resilient Fallback</div>
                  </div>
                </div>
              </div>

              {/* STEP 08: CONTINUOUS TELEPHONY LOOP */}
              <div
                onMouseEnter={() => onHoverStep('08')}
                onMouseLeave={() => onHoverStep(null)}
                onClick={() => onSelectStep('08')}
                className={`p-5 rounded-2xl transition-all duration-300 cursor-pointer ${
                  isCurrentActive('08')
                    ? 'bg-white border-[#1B432C] shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] ring-2 ring-[#1B432C]/10'
                    : 'bg-white border-[#E6ECE7] hover:border-[#C2D6C6]'
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs font-mono font-bold px-2 py-0.5 rounded-md ${
                        isCurrentActive('08')
                          ? 'bg-[#1B432C] text-white'
                          : 'bg-[#E8F0EA] text-[#1B432C]'
                      }`}
                    >
                      08
                    </span>
                    <span className="text-sm font-bold text-[#18201B]">
                      Voice Response & Multi-Turn Loop
                    </span>
                  </div>
                  <span className="text-[10px] font-mono text-[#1B432C] font-semibold bg-[#E8F0EA] px-2 py-0.5 rounded">
                    WebSocket Chunks
                  </span>
                </div>

                <p className="text-xs text-[#4F5D54] mb-3">
                  Audio is converted into telephone chunks and streamed via WebSocket to Exotel. Exotel plays the voice to the farmer.
                </p>

                <div className="p-3 rounded-xl bg-[#E8F0EA]/60 border border-[#C2D6C6] flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <RefreshCw className="w-4 h-4 text-[#1B432C] animate-spin" style={{ animationDuration: '6s' }} />
                    <span className="font-semibold text-[#1B432C]">
                      Continuous Conversation Loop
                    </span>
                  </div>
                  <span className="text-[11px] text-[#4F5D54]">
                    Repeats until resolved or ended
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ============================================================== */}
      {/* DETAILED ACTIVE STAGE INSPECTOR */}
      {/* ============================================================== */}
      <AnimatePresence mode="wait">
        <motion.div
          key={currentStep.id}
          initial={{ opacity: prefersReducedMotion ? 1 : 0, y: prefersReducedMotion ? 0 : 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: prefersReducedMotion ? 1 : 0, y: prefersReducedMotion ? 0 : -8 }}
          transition={{ duration: prefersReducedMotion ? 0.01 : 0.25 }}
          className="p-6 sm:p-7 rounded-3xl bg-white border border-[#E6ECE7] shadow-sm space-y-4"
        >
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#F0F4F1] pb-4">
            <div className="flex items-center gap-3">
              <span className="w-9 h-9 rounded-xl bg-[#E8F0EA] text-[#1B432C] font-mono font-bold text-sm flex items-center justify-center border border-[#C2D6C6]">
                {currentStep.number}
              </span>
              <div>
                <span className="text-xs font-mono text-[#79877E] uppercase tracking-wider">
                  {currentStep.actor}
                </span>
                <h3 className="text-lg sm:text-xl font-bold text-[#18201B]">
                  {currentStep.stageName}
                </h3>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <span className="px-3 py-1 rounded-full bg-[#FAF8F5] border border-[#E6ECE7] text-xs font-mono text-[#4F5D54]">
                {currentStep.technicalBadge}
              </span>
            </div>
          </div>

          <p className="text-sm sm:text-base text-[#4F5D54] leading-relaxed">
            {currentStep.summary}
          </p>

          {/* Conditional Branching indicator (e.g. for Step 02 or Step 04) */}
          {currentStep.branching && currentStep.branching.length > 0 && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
              {currentStep.branching.map((branch, idx) => (
                <div
                  key={idx}
                  className="p-3 rounded-xl bg-[#FAF8F5] border border-[#E6ECE7] text-xs"
                >
                  <div className="font-bold text-[#1B432C] mb-1 flex items-center gap-1.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
                    {branch.label}
                  </div>
                  <div className="text-[#4F5D54] leading-relaxed">
                    {branch.action}
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Detailed step bullet points */}
          <div className="space-y-2 pt-2">
            <span className="text-xs font-mono uppercase tracking-wider text-[#79877E]">
              Operational Breakdown
            </span>
            <ul className="space-y-1.5 text-xs sm:text-sm text-[#4F5D54]">
              {currentStep.details.map((detail, idx) => (
                <li key={idx} className="flex items-start gap-2">
                  <span className="text-[#1B432C] mt-1 font-bold">›</span>
                  <span>{detail}</span>
                </li>
              ))}
            </ul>
          </div>
        </motion.div>
      </AnimatePresence>
    </div>
  );
};

interface StageNodeProps {
  step: TelecomStepData;
  isActive: boolean;
  onSelect: () => void;
  onHover: (id: string | null) => void;
  icon: LucideIcon;
  badge: string;
}

const StageNode: React.FC<StageNodeProps> = ({
  step,
  isActive,
  onSelect,
  onHover,
  icon: Icon,
  badge,
}) => {
  return (
    <div
      onMouseEnter={() => onHover(step.id)}
      onMouseLeave={() => onHover(null)}
      onClick={onSelect}
      className={`relative flex flex-col justify-between p-4 rounded-2xl transition-all duration-300 cursor-pointer ${
        isActive
          ? 'bg-white border-[#1B432C] shadow-[0_8px_24px_-4px_rgba(27,67,44,0.12)] ring-2 ring-[#1B432C]/10'
          : 'bg-white/90 border-[#E6ECE7] hover:border-[#C2D6C6] hover:shadow-xs'
      }`}
    >
      <div>
        <div className="flex items-center justify-between mb-2">
          <span
            className={`text-xs font-mono font-bold px-2 py-0.5 rounded-md ${
              isActive
                ? 'bg-[#1B432C] text-white'
                : 'bg-[#E8F0EA] text-[#1B432C]'
            }`}
          >
            {step.number}
          </span>
          <Icon
            className={`w-4 h-4 ${
              isActive ? 'text-[#1B432C]' : 'text-[#79877E]'
            }`}
          />
        </div>
        <h4 className="font-bold text-[#18201B] text-sm mb-1">
          {step.stageName}
        </h4>
        <p className="text-[11px] text-[#4F5D54] leading-relaxed line-clamp-2">
          {step.summary}
        </p>
      </div>

      <div className="pt-3 mt-3 border-t border-[#F0F4F1]">
        <span className="text-[10px] font-mono text-[#79877E] truncate block">
          {badge}
        </span>
      </div>
    </div>
  );
};
