'use client';

import React, { useState, useEffect } from 'react';
import { Search, ArrowRight, X, Cpu, Sprout, TrendingUp, Users, Layers, Smartphone } from 'lucide-react';
import { GithubIcon } from '@/components/ui/GithubIcon';
import { PROJECT_CONFIG } from '@/data/project';

interface CommandPaletteProps {
  isOpen: boolean;
  onClose: () => void;
}

export const CommandPalette: React.FC<CommandPaletteProps> = ({ isOpen, onClose }) => {
  const [query, setQuery] = useState('');

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        if (isOpen) onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const quickActions = [
    {
      title: 'Project Overview & Hero',
      section: '#overview',
      icon: <Sprout className="w-4 h-4 text-emerald-400" />,
      category: 'Introduction',
    },
    {
      title: 'AI Routing Architecture (Groq + NVIDIA)',
      section: '#intelligence',
      icon: <Cpu className="w-4 h-4 text-emerald-400" />,
      category: 'AI Engine',
    },
    {
      title: 'Contextual AI Chat Preview',
      section: '#ai-chat',
      icon: <Cpu className="w-4 h-4 text-emerald-400" />,
      category: 'AI Assistant',
    },
    {
      title: '5-Tier Crop Recommendation Engine',
      section: '#recommendation',
      icon: <Sprout className="w-4 h-4 text-emerald-400" />,
      category: 'Agronomy',
    },
    {
      title: 'AGMARKNET 2.0 Mandi Prices (₹/kg)',
      section: '#market',
      icon: <TrendingUp className="w-4 h-4 text-emerald-400" />,
      category: 'Market Intelligence',
    },
    {
      title: 'Pre-Harvest & Consumer Demand Matching',
      section: '#community',
      icon: <Users className="w-4 h-4 text-emerald-400" />,
      category: 'Ecosystem',
    },
    {
      title: '13-Language Multilingual System',
      section: '#multilingual',
      icon: <Users className="w-4 h-4 text-emerald-400" />,
      category: 'Localization',
    },
    {
      title: '7-Layer System Architecture',
      section: '#architecture',
      icon: <Layers className="w-4 h-4 text-emerald-400" />,
      category: 'Engineering',
    },
    {
      title: 'Verified App Screen Gallery',
      section: '#screens',
      icon: <Smartphone className="w-4 h-4 text-emerald-400" />,
      category: 'UI Proof',
    },
    {
      title: 'GitHub Source Repository',
      external: PROJECT_CONFIG.repositoryUrl,
      icon: <GithubIcon className="w-4 h-4 text-emerald-400" />,
      category: 'Source Code',
    },
  ];

  const filtered = quickActions.filter(
    (action) =>
      action.title.toLowerCase().includes(query.toLowerCase()) ||
      action.category.toLowerCase().includes(query.toLowerCase())
  );

  const handleSelect = (action: typeof quickActions[0]) => {
    if (action.external) {
      window.open(action.external, '_blank');
    } else if (action.section) {
      const el = document.querySelector(action.section);
      el?.scrollIntoView({ behavior: 'smooth' });
    }
    onClose();
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-50 flex items-start justify-center pt-24 px-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-150"
      onClick={onClose}
    >
      <div
        className="w-full max-w-xl bg-[#122217] border border-[#294332] rounded-2xl shadow-2xl overflow-hidden flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Input bar */}
        <div className="flex items-center gap-3 px-4 py-3.5 border-b border-[#233E2B]">
          <Search className="w-4 h-4 text-[#A9BBAE]" />
          <input
            autoFocus
            type="text"
            placeholder="Search VidhAI case study sections, AI models, market data..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="flex-1 bg-transparent text-sm text-[#F1F7F2] placeholder-[#718776] focus:outline-none"
          />
          <button
            onClick={onClose}
            aria-label="Close command palette"
            className="p-1 rounded text-[#718776] hover:text-[#F1F7F2] cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Action list */}
        <div className="max-h-80 overflow-y-auto p-2 space-y-1">
          {filtered.length === 0 ? (
            <div className="py-8 text-center text-xs text-[#718776]">
              No sections matching &quot;{query}&quot;
            </div>
          ) : (
            filtered.map((action, idx) => (
              <button
                key={idx}
                onClick={() => handleSelect(action)}
                className="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-left text-xs hover:bg-[#1A3222] transition-colors group cursor-pointer"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-1.5 rounded-lg bg-[#0B170E] border border-[#233E2B]">
                    {action.icon}
                  </div>
                  <div>
                    <span className="font-medium text-[#F1F7F2] block">{action.title}</span>
                    <span className="text-[10px] text-[#718776]">{action.category}</span>
                  </div>
                </div>
                <ArrowRight className="w-3.5 h-3.5 text-[#718776] group-hover:text-emerald-400 transition-colors" />
              </button>
            ))
          )}
        </div>

        {/* Footer info */}
        <div className="px-4 py-2 bg-[#0B170E]/60 border-t border-[#1E3626] flex items-center justify-between text-[11px] text-[#718776]">
          <span>Use ESC to exit</span>
          <span>VidhAI Engineered Case Study</span>
        </div>
      </div>
    </div>
  );
};
