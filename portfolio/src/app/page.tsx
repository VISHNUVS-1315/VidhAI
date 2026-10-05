'use client';

import React from 'react';
import { Navigation } from '@/components/layout/Navigation';
import { Hero } from '@/components/hero/Hero';
import { AboutSection } from '@/components/about/AboutSection';
import { FeaturesSection } from '@/components/features/FeaturesSection';

import { HowItWorks } from '@/components/how-it-works/HowItWorks';
import { TelecomSection } from '@/components/telecom/TelecomSection';
import { TechStack } from '@/components/tech-stack/TechStack';
import { ProductShowcase } from '@/components/showcase/ProductShowcase';
import { ProjectHighlights } from '@/components/highlights/ProjectHighlights';

export default function Home() {
  return (
    <div className="min-h-screen bg-[#FAF8F5] text-[#18201B] relative selection:bg-[#E8F0EA] selection:text-[#1B432C]">
      {/* Global Sticky Navigation */}
      <Navigation />

      {/* Main Content Area */}
      <main>
        {/* Hero Section */}
        <Hero />

        {/* 1. About VidhAI Section */}
        <AboutSection />

        {/* 2. Key Features Section */}
        <FeaturesSection />

        {/* 3. How VidhAI Works Section */}
        <HowItWorks />

        {/* 4. VidhAI Telecom Call Flow Section */}
        <TelecomSection />

        {/* 5. Technology Stack Section */}
        <TechStack />

        {/* 5. Product Showcase Section */}
        <ProductShowcase />

        {/* 6. Project Highlights Section */}
        <ProjectHighlights />

        {/* Placeholder Anchors for Future Sections Navigation */}
        <div id="project" className="sr-only" />
      </main>
    </div>
  );
}
