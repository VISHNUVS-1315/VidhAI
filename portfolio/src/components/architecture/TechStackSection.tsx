'use client';

import React from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PROJECT_CONFIG } from '@/data/project';
import { Smartphone, Layers, Cpu, Server, Cloud, Database, HardDrive } from 'lucide-react';

export const TechStackSection: React.FC = () => {
  const categories = [
    {
      title: 'Mobile Client',
      role: 'Cross-platform native performance with 60fps UI',
      icon: <Smartphone className="w-5 h-5 text-emerald-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'Mobile'),
    },
    {
      title: 'State Management',
      role: 'Predictable unidirectional data flow & session stores',
      icon: <Layers className="w-5 h-5 text-emerald-300" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'State'),
    },
    {
      title: 'AI & Inference',
      role: 'Streaming conversational AI & deep agronomic reasoning',
      icon: <Cpu className="w-5 h-5 text-purple-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'AI'),
    },
    {
      title: 'Backend Gateway',
      role: 'Authenticated Express gateway deployed on Render',
      icon: <Server className="w-5 h-5 text-emerald-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'Backend'),
    },
    {
      title: 'Cloud Infrastructure',
      role: 'Identity token verification & real-time document store',
      icon: <Cloud className="w-5 h-5 text-amber-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'Cloud'),
    },
    {
      title: 'Agricultural Telemetry',
      role: 'Official mandi bulletins & hyperlocal weather data',
      icon: <Database className="w-5 h-5 text-cyan-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'Data'),
    },
    {
      title: 'On-Device Services',
      role: 'Offline persistent caching & background workers',
      icon: <HardDrive className="w-5 h-5 text-blue-400" />,
      items: PROJECT_CONFIG.techStack.filter((t) => t.category === 'Device' || t.category === 'Local'),
    },
  ];

  return (
    <section id="tech-stack" className="py-20 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <Badge variant="verified" size="sm">
            Technologies &amp; Libraries
          </Badge>
          <h2 className="text-3xl sm:text-4xl font-bold text-[#F1F7F2] tracking-tight">
            Grouped by responsibility. <span className="text-emerald-400">Zero fluff.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Every library in the VidhAI codebase solves a concrete engineering constraint in rural
            connectivity, multilingual access, or agronomic accuracy.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {categories.map((cat, idx) => (
            <Card key={idx} className="bg-[#14261A] border-[#233E2B] p-6 space-y-4">
              <div className="flex items-center gap-3 border-b border-[#233E2B] pb-3">
                <div className="p-2 rounded-xl bg-emerald-950 border border-emerald-500/40">
                  {cat.icon}
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#F1F7F2]">{cat.title}</h3>
                  <span className="text-[11px] text-[#A9BBAE] block">{cat.role}</span>
                </div>
              </div>

              <div className="space-y-3">
                {cat.items.map((item, iIdx) => (
                  <div key={iIdx} className="space-y-0.5">
                    <div className="text-xs font-semibold text-emerald-300 font-mono">
                      {item.name}
                    </div>
                    <p className="text-[11px] text-[#718776] leading-relaxed">{item.purpose}</p>
                  </div>
                ))}
              </div>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};
