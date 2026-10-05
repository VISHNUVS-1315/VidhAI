'use client';

import React, { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import {
  Camera,
  ShieldAlert,
  Smartphone,
} from 'lucide-react';

interface CropVisionDemoProps {
  onOpenScreenshotLightbox?: (id: string) => void;
}

export const CropVisionDemo: React.FC<CropVisionDemoProps> = ({ onOpenScreenshotLightbox }) => {
  const [selectedDiagnosis, setSelectedDiagnosis] = useState(0);

  const sampleDiagnoses = [
    {
      crop: 'Tomato Foliage',
      detectedIssue: 'Early Blight (Alternaria solani)',
      severity: 'Moderate (Stage 2 concentric lesions)',
      confidence: '86% Pattern Concordance',
      treatmentChemical: 'Apply Mancozeb 75% WP @ 2g/L water or Chlorothalonil on affected rows.',
      treatmentOrganic: 'Trichoderma harzianum soil drench and neem oil (10,000 ppm) foliar spray.',
      prevention: 'Avoid overhead sprinkler irrigation; maintain adequate row spacing to reduce humidity.',
    },
    {
      crop: 'Cotton Leaf',
      detectedIssue: 'Bollworm Infestation Symptoms (Helicoverpa armigera)',
      severity: 'Early Detection (Chewed bracts & young boll entry pinholes)',
      confidence: '82% Pattern Concordance',
      treatmentChemical: 'Emamectin Benzoate 5% SG @ 0.5g/L or Chlorantraniliprole 18.5% SC.',
      treatmentOrganic: 'Install 4 pheromone traps/acre; spray HaNPV @ 250 LE/acre in late evening.',
      prevention: 'Maintain border trap crops (Marigold / Okra) to attract moths away from cotton.',
    },
  ];

  const current = sampleDiagnoses[selectedDiagnosis];

  return (
    <section id="analysis" className="py-24 border-b border-[#233E2B] bg-[#0B170E] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-14 space-y-3">
          <Badge variant="verified" size="sm">
            AI-Assisted Crop Issue Analysis
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Vision intelligence for <span className="text-emerald-400">foliage & pest issues.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            Farmers capture suspicious leaf spots or pest damage directly from their field. The
            image is routed securely to NVIDIA Nemotron Nano Omni 30B to detect symptoms and outline
            immediate intervention steps.
          </p>

          <div className="pt-2 flex justify-center">
            <Button
              variant="secondary"
              size="sm"
              icon={<Smartphone className="w-4 h-4 text-emerald-400" />}
              onClick={() => onOpenScreenshotLightbox?.('tools-dashboard')}
            >
              View Verified Tools Screen
            </Button>
          </div>
        </div>

        {/* Vision Workflow Pipeline */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center max-w-5xl mx-auto">
          {/* Left: Input Selection & Image Simulation */}
          <div className="lg:col-span-5 space-y-4">
            <Card className="bg-[#14261A] border-[#233E2B] p-6 space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-xs font-mono uppercase text-[#A9BBAE]">Sample Diagnosis</span>
                <span className="text-xs text-emerald-400 font-semibold">
                  NVIDIA Nano Omni 30B
                </span>
              </div>

              {/* Toggle Between Scenarios */}
              <div className="flex gap-2">
                <button
                  onClick={() => setSelectedDiagnosis(0)}
                  className={`flex-1 py-2 px-3 rounded-xl text-xs font-medium border transition-colors cursor-pointer ${
                    selectedDiagnosis === 0
                      ? 'bg-emerald-950 text-emerald-300 border-emerald-500/50'
                      : 'bg-[#0B170E] text-[#A9BBAE] border-[#233E2B]'
                  }`}
                >
                  Tomato Foliage
                </button>
                <button
                  onClick={() => setSelectedDiagnosis(1)}
                  className={`flex-1 py-2 px-3 rounded-xl text-xs font-medium border transition-colors cursor-pointer ${
                    selectedDiagnosis === 1
                      ? 'bg-emerald-950 text-emerald-300 border-emerald-500/50'
                      : 'bg-[#0B170E] text-[#A9BBAE] border-[#233E2B]'
                  }`}
                >
                  Cotton Leaf
                </button>
              </div>

              {/* Diagnosis Simulation Box */}
              <div className="relative rounded-2xl bg-[#0B170E] border border-[#233E2B] p-6 text-center space-y-3">
                <div className="w-16 h-16 mx-auto rounded-2xl bg-emerald-950/60 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
                  <Camera className="w-8 h-8" />
                </div>
                <div>
                  <h4 className="text-sm font-bold text-[#F1F7F2]">{current.crop}</h4>
                  <span className="text-xs text-[#718776]">Captured via camera (image_picker)</span>
                </div>
                <div className="text-[11px] font-mono text-emerald-400">
                  Transferred via Base64 to /ai/image route
                </div>
              </div>
            </Card>
          </div>

          {/* Right: Diagnosis Details */}
          <div className="lg:col-span-7 space-y-4">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-5">
              <div className="flex items-center justify-between border-b border-[#233E2B] pb-4">
                <div>
                  <span className="text-[10px] font-mono uppercase tracking-wider text-emerald-400">
                    AI Visual Identification
                  </span>
                  <h3 className="text-lg font-bold text-[#F1F7F2]">{current.detectedIssue}</h3>
                </div>
                <Badge variant="demo" size="sm">
                  {current.confidence}
                </Badge>
              </div>

              <div className="space-y-3 text-xs">
                <div>
                  <span className="text-[11px] font-semibold text-[#A9BBAE] block mb-1">
                    Observed Severity:
                  </span>
                  <p className="text-amber-300 bg-amber-950/30 p-2.5 rounded-xl border border-amber-800/40">
                    {current.severity}
                  </p>
                </div>

                <div>
                  <span className="text-[11px] font-semibold text-[#A9BBAE] block mb-1">
                    Recommended Agronomic Treatment:
                  </span>
                  <p className="text-[#F1F7F2] leading-relaxed mb-1.5">{current.treatmentChemical}</p>
                  <p className="text-emerald-300 leading-relaxed font-medium">
                    Bio-control alternative: {current.treatmentOrganic}
                  </p>
                </div>

                <div>
                  <span className="text-[11px] font-semibold text-[#A9BBAE] block mb-1">
                    Field Prevention Measure:
                  </span>
                  <p className="text-[#A9BBAE] leading-relaxed">{current.prevention}</p>
                </div>
              </div>

              {/* Official Agronomic Disclaimer Mandated by Guidelines */}
              <div className="pt-4 border-t border-[#233E2B] flex items-start gap-2.5 text-[11px] text-[#718776] leading-relaxed">
                <ShieldAlert className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                <span>
                  <strong>Advisory Notice:</strong> AI agricultural analysis is provided as decision
                  support for early symptom recognition. It is not an absolute replacement for
                  on-site professional agronomic diagnosis or certified laboratory soil testing.
                </span>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
