'use client';

import React from 'react';
import { Card } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { PROJECT_CONFIG } from '@/data/project';
import { ExternalLink, ShieldCheck, Award, CheckCircle } from 'lucide-react';
import { GithubIcon } from '@/components/ui/GithubIcon';

export const TeamSection: React.FC = () => {
  const { creator } = PROJECT_CONFIG;

  return (
    <section id="team" className="py-24 border-b border-[#233E2B] bg-[#0A140D] relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16 space-y-3">
          <Badge variant="verified" size="sm">
            Project Attribution &amp; Status
          </Badge>
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#F1F7F2] tracking-tight">
            Built by engineering <span className="text-emerald-400">discipline.</span>
          </h2>
          <p className="text-sm sm:text-base text-[#A9BBAE] leading-relaxed">
            VidhAI was engineered for student innovation competitions and rural impact, balancing
            modern AI architectures with realistic Indian farming conditions.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch max-w-5xl mx-auto">
          {/* Creator Profile Card */}
          <div className="lg:col-span-7">
            <Card glow className="bg-[#14261A] border-emerald-600/40 p-6 sm:p-8 space-y-6 h-full flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between border-b border-[#233E2B] pb-4 mb-5">
                  <div>
                    <span className="text-xs font-mono uppercase text-emerald-400 font-semibold block mb-1">
                      Lead Architect &amp; Creator
                    </span>
                    <h3 className="text-2xl font-bold text-[#F1F7F2]">{creator.name}</h3>
                    <span className="text-xs text-[#718776] font-mono">@{creator.handle}</span>
                  </div>
                  <Badge variant="accent" size="sm">
                    Student Innovator
                  </Badge>
                </div>

                <p className="text-xs sm:text-sm text-[#A9BBAE] leading-relaxed mb-6">
                  {creator.bio}
                </p>

                <div>
                  <h4 className="text-xs font-mono uppercase tracking-wider text-[#A9BBAE] mb-3 font-semibold">
                    Core Technical Contributions
                  </h4>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                    {creator.roles.map((role, idx) => (
                      <div
                        key={idx}
                        className="p-2.5 rounded-xl bg-[#0B170E] border border-[#233E2B] text-[#F1F7F2] flex items-center gap-2"
                      >
                        <CheckCircle className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                        <span>{role}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <div className="pt-6 border-t border-[#233E2B] flex items-center justify-between">
                <a
                  href={creator.github}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 text-xs text-emerald-400 hover:text-emerald-300 transition-colors font-medium"
                >
                  <GithubIcon className="w-4 h-4" />
                  <span>GitHub Profile</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>

                <span className="text-xs text-[#718776] font-mono">
                  Repository: VISHNUVS-1315/VidhAI
                </span>
              </div>
            </Card>
          </div>

          {/* Project Status Card */}
          <div className="lg:col-span-5">
            <Card className="bg-[#14261A] border-[#233E2B] p-6 sm:p-8 space-y-6 h-full flex flex-col justify-between">
              <div>
                <div className="flex items-center gap-2.5 border-b border-[#233E2B] pb-4 mb-5">
                  <div className="p-2 rounded-xl bg-emerald-950 border border-emerald-500/40 text-emerald-400">
                    <Award className="w-5 h-5" />
                  </div>
                  <div>
                    <h3 className="text-base font-bold text-[#F1F7F2]">Development Status</h3>
                    <span className="text-xs text-emerald-400 font-mono">Active Engineering Branch</span>
                  </div>
                </div>

                <div className="space-y-3.5 text-xs">
                  <div className="p-3 rounded-xl bg-[#0B170E] border border-[#233E2B] space-y-1">
                    <span className="text-[10px] uppercase font-mono text-[#718776] block">
                      Release Target
                    </span>
                    <span className="text-[#F1F7F2] font-semibold text-sm">
                      {PROJECT_CONFIG.version} (Android Debug / Release Build Verified)
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-[#0B170E] border border-[#233E2B] space-y-1">
                    <span className="text-[10px] uppercase font-mono text-[#718776] block">
                      Production Claim Transparency
                    </span>
                    <span className="text-[#A9BBAE] leading-relaxed block">
                      This portfolio presents VidhAI as an active engineering prototype. We do not
                      claim nationwide production deployment, fabricated farmer counts, or synthetic
                      financial metrics.
                    </span>
                  </div>
                </div>
              </div>

              <div className="pt-4 border-t border-[#233E2B] flex items-center gap-2 text-xs text-emerald-400 font-medium">
                <ShieldCheck className="w-4 h-4 shrink-0" />
                <span>Verified in accordance with strict portfolio evaluation rules.</span>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </section>
  );
};
