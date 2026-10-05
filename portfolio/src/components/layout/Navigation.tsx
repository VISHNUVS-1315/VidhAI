'use client';

import React, { useState, useEffect } from 'react';
import Image from '@/components/ui/PortfolioImage';
import { Menu, X, ArrowUpRight } from 'lucide-react';
import { GithubIcon } from '@/components/ui/GithubIcon';
import { PROJECT_CONFIG } from '@/data/project';
import { Button } from '@/components/ui/Button';

interface NavItem {
  label: string;
  href: string;
}

const NAV_ITEMS: NavItem[] = [
  { label: 'Home', href: '#home' },
  { label: 'About', href: '#about' },
  { label: 'Features', href: '#features' },
  { label: 'How It Works', href: '#how-it-works' },
  { label: 'Telecom', href: '#telecom' },
  { label: 'Tech Stack', href: '#tech-stack' },
  { label: 'Highlights', href: '#highlights' },
];

export const Navigation: React.FC = () => {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [activeSection, setActiveSection] = useState('home');

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);

      // Section intersection detection for active tab indicator
      const sections = NAV_ITEMS.map((item) => item.href.substring(1));
      const scrollPosition = window.scrollY + 100;

      for (let i = sections.length - 1; i >= 0; i--) {
        const el = document.getElementById(sections[i]);
        if (el && el.offsetTop <= scrollPosition) {
          setActiveSection(sections[i]);
          break;
        }
      }
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleNavClick = (
    e: React.MouseEvent<HTMLAnchorElement>,
    href: string
  ) => {
    e.preventDefault();
    setMobileMenuOpen(false);
    const targetId = href.substring(1);
    const el = document.getElementById(targetId);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth' });
    } else {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-200 ${
        isScrolled
          ? 'bg-[#FAF8F5]/95 backdrop-blur-md border-b border-[#E6ECE7] shadow-[0_2px_12px_-2px_rgba(24,32,27,0.04)]'
          : 'bg-[#FAF8F5]/80 backdrop-blur-sm border-b border-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-5 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 sm:h-[72px]">
          {/* LEFT: Logo & Name */}
          <a
            href="#home"
            onClick={(e) => handleNavClick(e, '#home')}
            className="flex items-center gap-2.5 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#1B432C] rounded-xl p-1 -ml-1"
          >
            <div className="relative w-8 h-8 rounded-xl overflow-hidden bg-[#E8F0EA] border border-[#C2D6C6] p-1 flex items-center justify-center transition-colors group-hover:border-[#1B432C]">
              <Image
                src="/brand/vidhai-logo.png"
                alt="VidhAI Leaf Logo"
                width={26}
                height={26}
                className="object-contain"
                priority
              />
            </div>
            <div className="flex flex-col">
              <span className="font-bold text-base tracking-tight text-[#18201B] flex items-center gap-1.5">
                {PROJECT_CONFIG.name}
              </span>
            </div>
          </a>

          {/* CENTER: Desktop Navigation Links */}
          <nav className="hidden lg:flex items-center gap-1 px-3 py-1.5 rounded-full bg-white/80 border border-[#E6ECE7] shadow-[0_1px_2px_rgba(0,0,0,0.02)]">
            {NAV_ITEMS.map((item) => {
              const isActive = activeSection === item.href.substring(1);
              return (
                <a
                  key={item.href}
                  href={item.href}
                  onClick={(e) => handleNavClick(e, item.href)}
                  className={`px-3.5 py-1.5 rounded-full text-xs font-medium transition-all duration-150 ${
                    isActive
                      ? 'bg-[#1B432C] text-white shadow-sm'
                      : 'text-[#4F5D54] hover:text-[#18201B] hover:bg-[#F4F6F4]'
                  }`}
                >
                  {item.label}
                </a>
              );
            })}
          </nav>

          {/* RIGHT: View Project Button & GitHub Link */}
          <div className="hidden lg:flex items-center gap-2.5">
            <a
              href={PROJECT_CONFIG.repositoryUrl}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="View Source on GitHub"
              className="p-2 rounded-xl text-[#4F5D54] hover:text-[#18201B] hover:bg-[#F4F6F4] border border-transparent hover:border-[#E6ECE7] transition-all"
            >
              <GithubIcon className="w-4 h-4" />
            </a>

            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                const el = document.getElementById('project') || document.getElementById('home');
                el?.scrollIntoView({ behavior: 'smooth' });
              }}
            >
              <span>View Project</span>
              <ArrowUpRight className="w-3.5 h-3.5 ml-1" />
            </Button>
          </div>

          {/* MOBILE: Hamburger Button */}
          <div className="flex lg:hidden items-center gap-2">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              aria-label={mobileMenuOpen ? 'Close navigation menu' : 'Open navigation menu'}
              aria-expanded={mobileMenuOpen}
              className="p-2.5 min-w-[44px] min-h-[44px] flex items-center justify-center rounded-xl bg-white border border-[#E6ECE7] text-[#18201B] hover:bg-[#F4F6F4] transition-colors cursor-pointer"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>

      {/* MOBILE DRAWER */}
      {mobileMenuOpen && (
        <div className="lg:hidden border-b border-[#E6ECE7] bg-[#FAF8F5]/98 backdrop-blur-xl px-5 pt-3 pb-6 shadow-xl animate-in slide-in-from-top-2 duration-200">
          <nav className="flex flex-col gap-1 mb-4">
            {NAV_ITEMS.map((item) => {
              const isActive = activeSection === item.href.substring(1);
              return (
                <a
                  key={item.href}
                  href={item.href}
                  onClick={(e) => handleNavClick(e, item.href)}
                  className={`min-h-[44px] flex items-center px-4 rounded-xl text-sm font-medium transition-colors ${
                    isActive
                      ? 'bg-[#E8F0EA] text-[#1B432C] font-semibold'
                      : 'text-[#4F5D54] hover:bg-[#F4F6F4] hover:text-[#18201B]'
                  }`}
                >
                  {item.label}
                </a>
              );
            })}
          </nav>

          <div className="pt-3 border-t border-[#E6ECE7] flex flex-col gap-2.5">
            <Button
              variant="primary"
              size="md"
              className="w-full justify-center"
              onClick={() => {
                setMobileMenuOpen(false);
                const el = document.getElementById('project') || document.getElementById('home');
                el?.scrollIntoView({ behavior: 'smooth' });
              }}
            >
              <span>View Project</span>
              <ArrowUpRight className="w-4 h-4 ml-1.5" />
            </Button>

            <a
              href={PROJECT_CONFIG.repositoryUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="min-h-[44px] flex items-center justify-center gap-2 py-2 px-4 rounded-xl bg-white border border-[#E6ECE7] text-xs font-semibold text-[#4F5D54] hover:text-[#18201B] transition-colors"
            >
              <GithubIcon className="w-4 h-4" />
              <span>GitHub Repository</span>
            </a>
          </div>
        </div>
      )}
    </header>
  );
};
