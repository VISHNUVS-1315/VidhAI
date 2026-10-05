'use client';

import React, { useState, useEffect } from 'react';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { StreamingIntelligenceTrace } from '@/components/ai/StreamingIntelligenceTrace';
import { LivingSignalGrid } from '@/components/motion/LivingSignalGrid';
import { AI_CHAT_SCENARIOS, AiChatPrompt } from '@/data/mockData';
import {
  Cpu,
  Mic,
  Volume2,
  VolumeX,
  Paperclip,
  Send,
  Sparkles,
  MapPin,
  Sprout,
  Smartphone,
} from 'lucide-react';

interface InteractiveChatProps {
  onOpenScreenshotLightbox?: (id: string) => void;
}

export const InteractiveChat: React.FC<InteractiveChatProps> = ({ onOpenScreenshotLightbox }) => {
  const [selectedScenario, setSelectedScenario] = useState<AiChatPrompt>(AI_CHAT_SCENARIOS[0]);
  const [streamedText, setStreamedText] = useState<string>(AI_CHAT_SCENARIOS[0].response);
  const [isStreaming, setIsStreaming] = useState<boolean>(false);
  const [ttsActive, setTtsActive] = useState<boolean>(false);
  const intervalRef = React.useRef<NodeJS.Timeout | null>(null);

  const handleSelectScenario = (scenario: AiChatPrompt) => {
    if (intervalRef.current) clearInterval(intervalRef.current);
    setSelectedScenario(scenario);
    setStreamedText('');
    setIsStreaming(true);
    let index = 0;
    const fullText = scenario.response;
    intervalRef.current = setInterval(() => {
      index += 5;
      if (index >= fullText.length) {
        setStreamedText(fullText);
        setIsStreaming(false);
        if (intervalRef.current) clearInterval(intervalRef.current);
      } else {
        setStreamedText(fullText.slice(0, index));
      }
    }, 12);
  };

  useEffect(() => {
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, []);

  return (
    <section id="ai-chat" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative overflow-hidden">
      {/* Living Signal Grid Background */}
      <LivingSignalGrid density="low" className="opacity-75" />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <div className="flex items-center justify-center gap-2">
            <Badge variant="verified" size="sm">
              Farm-Aware Conversational Intelligence
            </Badge>
            <Badge variant="demo" size="sm">
              Interactive Preview
            </Badge>
          </div>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Chat designed for the <span className="text-emerald-400">field.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            The VidhAI Assistant anchors every conversation to the farmer&apos;s active land coordinates,
            active crop lifecycle, and local language.
          </p>
          <div className="pt-1 flex items-center justify-center gap-2 text-[11px] font-mono text-[#718776]">
            <span className="text-emerald-400 font-semibold">IMPLEMENTATION:</span>
            <span>Dedicated Groq streaming path (`openai/gpt-oss-20b`) with farm-context pre-injection</span>
          </div>

          <div className="pt-2 flex justify-center">
            <Button
              variant="secondary"
              size="sm"
              icon={<Smartphone className="w-4 h-4 text-emerald-400" />}
              onClick={() => onOpenScreenshotLightbox?.('ai-assistant')}
            >
              View Genuine Android Chat Screenshot
            </Button>
          </div>
        </div>

        {/* Signature Motion: Streaming Intelligence Thinking Path */}
        <div className="max-w-4xl mx-auto">
          <StreamingIntelligenceTrace />
        </div>

        {/* Interactive Chat Console */}
        <div className="max-w-4xl mx-auto rounded-3xl bg-[#122217] border border-[#233E2B] overflow-hidden shadow-2xl glow-card">
          {/* Top Assistant Header & Farm Context Selector */}
          <div className="p-4 sm:p-5 border-b border-[#233E2B] bg-[#16291D]/90 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className="p-2 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
                <Sparkles className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-bold text-[#F1F7F2]">VidhAI Assistant</h3>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-950 text-emerald-400 border border-emerald-500/30">
                    Active Session
                  </span>
                </div>
                <div className="text-[11px] text-[#A9BBAE] flex items-center gap-2">
                  <span>Routing: {selectedScenario.routedModel}</span>
                </div>
              </div>
            </div>

            {/* Farm Context Selector Visual */}
            <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2]">
              <Sprout className="w-3.5 h-3.5 text-emerald-400" />
              <span className="font-medium">{selectedScenario.farmContext.farmName}</span>
              <span className="text-[10px] text-[#718776]">({selectedScenario.farmContext.size})</span>
              <MapPin className="w-3 h-3 text-[#718776] ml-1" />
              <span className="text-[10px] text-[#A9BBAE]">Tiruppur</span>
            </div>
          </div>

          {/* Quick Scenario Picker Buttons */}
          <div className="p-3 bg-[#0E1B13] border-b border-[#1E3626] flex items-center gap-2 overflow-x-auto">
            <span className="text-[11px] font-mono uppercase text-[#718776] shrink-0 pl-1">
              Select Sample Query:
            </span>
            {AI_CHAT_SCENARIOS.map((scenario) => (
              <button
                key={scenario.id}
                onClick={() => handleSelectScenario(scenario)}
                className={`px-3 py-1.5 rounded-xl text-xs whitespace-nowrap transition-colors cursor-pointer border ${
                  selectedScenario.id === scenario.id
                    ? 'bg-emerald-950/90 text-emerald-300 border-emerald-500/60 shadow-sm'
                    : 'bg-[#14261A] text-[#A9BBAE] border-[#233E2B] hover:text-[#F1F7F2]'
                }`}
              >
                {scenario.prompt.slice(0, 36)}...
              </button>
            ))}
          </div>

          {/* Chat Messages Body */}
          <div className="p-5 sm:p-6 space-y-5 min-h-[340px] max-h-[460px] overflow-y-auto bg-[#0F1E15]/50">
            {/* User Message */}
            <div className="flex justify-end">
              <div className="max-w-xl rounded-2xl rounded-tr-sm bg-[#2E7D32] p-4 text-[#F1F7F2] text-sm shadow-md">
                <p>{selectedScenario.prompt}</p>
                <div className="text-[10px] text-emerald-200/70 pt-1 text-right">
                  Attached: {selectedScenario.farmContext.farmName} ({selectedScenario.farmContext.soil})
                </div>
              </div>
            </div>

            {/* VidhAI Assistant Streamed Response */}
            <div className="flex items-start gap-3">
              <div className="p-2 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400 shrink-0 mt-1">
                <Cpu className="w-4 h-4" />
              </div>
              <div className="max-w-2xl rounded-2xl rounded-tl-sm bg-[#162B1D] border border-[#233E2B] p-5 text-[#F1F7F2] text-xs sm:text-sm space-y-3 leading-relaxed shadow-md">
                <div className="whitespace-pre-wrap font-sans text-[#F1F7F2]">
                  {streamedText}
                  {isStreaming && (
                    <span className="inline-block w-2 h-4 ml-1 bg-emerald-400 animate-pulse align-middle" />
                  )}
                </div>

                {/* Response Metadata Bar */}
                <div className="pt-3 border-t border-[#233E2B] flex flex-wrap items-center justify-between gap-2 text-[10px] text-[#A9BBAE]">
                  <div className="flex items-center gap-2">
                    <span className="text-emerald-400 font-mono">Provider: {selectedScenario.provider}</span>
                    <span>•</span>
                    <span>Tier: {selectedScenario.tier}</span>
                  </div>
                  <button
                    onClick={() => setTtsActive(!ttsActive)}
                    className="flex items-center gap-1 text-[#A9BBAE] hover:text-emerald-300 transition-colors cursor-pointer"
                  >
                    {ttsActive ? <Volume2 className="w-3.5 h-3.5 text-emerald-400" /> : <VolumeX className="w-3.5 h-3.5" />}
                    <span>{ttsActive ? 'TTS Playing' : 'Simulate Audio TTS'}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Chat Mock Input Bar */}
          <div className="p-3 sm:p-4 border-t border-[#233E2B] bg-[#16291D]/80 flex items-center gap-3">
            <button
              aria-label="Attach crop file or photo"
              className="p-2 rounded-xl bg-[#0B170E] border border-[#233E2B] text-[#A9BBAE] hover:text-[#F1F7F2] transition-colors cursor-pointer"
            >
              <Paperclip className="w-4 h-4" />
            </button>
            <div className="flex-1 px-4 py-2.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#718776] flex items-center justify-between">
              <span>Ask VidhAI regarding your soil, pests, irrigation, or market prices...</span>
              <div className="flex items-center gap-1.5 text-[10px] font-mono text-emerald-400">
                <Mic className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Voice Input Supported</span>
              </div>
            </div>
            <button
              disabled
              aria-label="Send message"
              className="p-2.5 rounded-xl bg-[#2E7D32] text-[#F1F7F2] opacity-80 cursor-default"
            >
              <Send className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Disclaimer Note */}
        <p className="text-center text-[11px] text-[#718776] mt-4">
          Interactive Product Preview • All answers are generated from authentic VidhAI prompt &
          telemetry schemas. VidhAI AI guidance is advisory decision support.
        </p>
      </div>
    </section>
  );
};
