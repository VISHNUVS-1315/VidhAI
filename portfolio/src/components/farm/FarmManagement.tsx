'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import {
  Droplets,
  DollarSign,
  Shield,
  Bug,
  History,
  ArrowRight,
  CheckCircle,
} from 'lucide-react';

export const FarmManagement: React.FC = () => {
  const [selectedRecord, setSelectedRecord] = useState(0);

  const recordTypes = [
    {
      title: 'Expense Records',
      file: 'expenses_screen.dart',
      icon: <DollarSign className="w-5 h-5 text-emerald-400" />,
      desc: 'Tracks seeds, labor, machinery rental, and irrigation expenditure per acre to calculate exact production costs.',
      fields: ['Date & Category', 'Amount in INR', 'Associated Crop', 'Payment Mode (Cash/UPI)'],
    },
    {
      title: 'Fertilizer Application Logs',
      file: 'fertilizer_screen.dart',
      icon: <Droplets className="w-5 h-5 text-blue-400" />,
      desc: 'Logs basal vs top-dressing fertilizer applications, NPK ratios, and fertigation schedules to prevent nitrogen leaching.',
      fields: ['NPK Blend (e.g. 19:19:19)', 'Quantity in kg', 'Application Method (Drip/Foliar)', 'Growth Stage'],
    },
    {
      title: 'Pesticide & Spray Logs',
      file: 'pesticide_screen.dart',
      icon: <Shield className="w-5 h-5 text-purple-400" />,
      desc: 'Monitors chemical and bio-agent spray interventions, safety intervals before harvest, and dilution concentrations.',
      fields: ['Chemical / Bio Name', 'Dosage per Liter', 'Target Pest / Fungus', 'Waiting Period (Days)'],
    },
    {
      title: 'Disease Outbreak Tracking',
      file: 'disease_screen.dart',
      icon: <Bug className="w-5 h-5 text-red-400" />,
      desc: 'Documents infected field zones, visual symptoms, weather triggers, and recovery progression across flushes.',
      fields: ['Pathogen Suspected', 'Foliage Severity %', 'Weather Preceding Outbreak', 'Remediation Applied'],
    },
    {
      title: 'Season Farm History',
      file: 'farm_history_screen.dart',
      icon: <History className="w-5 h-5 text-amber-400" />,
      desc: 'Maintains multi-season crop history, past yields, and rotational sequence for AI recommendation context.',
      fields: ['Past Harvested Crop', 'Yield (Quintals/Acre)', 'Fallow Period (Months)', 'Gross Revenue'],
    },
  ];

  const current = recordTypes[selectedRecord];

  return (
    <section id="farm-management" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Operational Workspace
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Comprehensive farm records. <span className="text-emerald-400">Zero loose papers.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Farming is an engineered operational cycle. VidhAI replaces messy paper ledgers with
            five verified digital record modules stored offline in SharedPreferences and backed by
            Firestore.
          </p>
        </div>

        {/* The Operational Flow Pipeline Visual */}
        <div className="mb-14 p-6 rounded-2xl bg-[#122217] border border-[#233E2B] overflow-x-auto">
          <div className="flex items-center justify-between min-w-[700px] gap-3 text-xs font-mono">
            {[
              { step: '01', title: 'FARM PROFILE', desc: 'GPS & Soil Type' },
              { step: '02', title: 'CROP SETUP', desc: 'Variety & Season' },
              { step: '03', title: 'SEASON PLAN', desc: 'NPK & Water Budget' },
              { step: '04', title: 'DAILY TASKS', desc: 'Fingerprint Deduped' },
              { step: '05', title: '5 RECORD LOGS', desc: 'Expenses & Sprays' },
              { step: '06', title: 'HARVEST & TRADE', desc: 'Pre-Harvest Listing' },
            ].map((item, idx) => (
              <React.Fragment key={idx}>
                <div className="flex flex-col items-center text-center space-y-1">
                  <span className="w-7 h-7 rounded-full bg-emerald-950 border border-emerald-500/40 text-emerald-400 flex items-center justify-center font-bold text-xs">
                    {item.step}
                  </span>
                  <span className="text-[#F1F7F2] font-semibold text-[11px]">{item.title}</span>
                  <span className="text-[#718776] text-[10px]">{item.desc}</span>
                </div>
                {idx < 5 && (
                  <ArrowRight className="w-4 h-4 text-[#233E2B] shrink-0" />
                )}
              </React.Fragment>
            ))}
          </div>
        </div>

        {/* 5 Record Modules Interactive Selector */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
          {/* Record Selector Tabs */}
          <div className="lg:col-span-5 space-y-2.5">
            {recordTypes.map((rec, idx) => {
              const isSelected = selectedRecord === idx;
              return (
                <button
                  key={idx}
                  onClick={() => setSelectedRecord(idx)}
                  className={`w-full p-4 rounded-2xl text-left border transition-all cursor-pointer flex items-center justify-between ${
                    isSelected
                      ? 'bg-[#1A3222] border-emerald-500/70 shadow-lg shadow-emerald-950/40'
                      : 'bg-[#122217] border-[#233E2B] hover:border-emerald-500/30'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`p-2.5 rounded-xl border ${
                        isSelected
                          ? 'bg-emerald-950/80 border-emerald-500/50'
                          : 'bg-[#0B170E] border-[#1E3626]'
                      }`}
                    >
                      {rec.icon}
                    </div>
                    <div>
                      <h4 className="text-xs font-bold text-[#F1F7F2]">{rec.title}</h4>
                      <code className="text-[10px] font-mono text-[#718776]">{rec.file}</code>
                    </div>
                  </div>
                  <ArrowRight
                    className={`w-4 h-4 transition-transform ${
                      isSelected ? 'text-emerald-400 translate-x-1' : 'text-[#718776]'
                    }`}
                  />
                </button>
              );
            })}
          </div>

          {/* Detailed Inspector for Selected Record Type */}
          <div className="lg:col-span-7">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-6">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-emerald-950 border border-emerald-500/40">
                    {current.icon}
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-[#F1F7F2]">{current.title}</h3>
                    <code className="text-xs font-mono text-emerald-400">
                      lib/features/farm_records/screens/{current.file}
                    </code>
                  </div>
                </div>
                <Badge variant="verified" size="sm">
                  Screen Verified
                </Badge>
              </div>

              <div>
                <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-2 font-semibold">
                  Field Responsibility & Utility
                </h4>
                <p className="text-sm text-[#F1F7F2] leading-relaxed">{current.desc}</p>
              </div>

              {/* Data Schema Fields */}
              <div>
                <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-3 font-semibold">
                  Captured Schema Attributes
                </h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  {current.fields.map((field, fIdx) => (
                    <div
                      key={fIdx}
                      className="p-3 rounded-xl bg-[#0B170E] border border-[#233E2B] text-xs text-[#F1F7F2] flex items-center gap-2"
                    >
                      <CheckCircle className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                      <span>{field}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="pt-2 flex items-center justify-between text-xs text-[#718776]">
                <span>State Storage: SharedPreferences (Offline-First)</span>
                <span>Cloud Sync: Cloud Firestore</span>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
