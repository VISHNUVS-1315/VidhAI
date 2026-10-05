'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { Variants } from 'framer-motion';
import type { LucideIcon } from 'lucide-react';
import { usePrefersReducedMotion } from '@/lib/motion';

export interface FeatureCardProps {
  icon: LucideIcon;
  category: string;
  title: string;
  description: string;
}

export const FeatureCard: React.FC<FeatureCardProps> = ({
  icon: Icon,
  category,
  title,
  description,
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();

  const cardVariants: Variants = {
    hidden: { opacity: 0, y: prefersReducedMotion ? 0 : 16 },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: prefersReducedMotion ? 0.01 : 0.45,
        ease: 'easeOut',
      },
    },
  };

  return (
    <motion.div
      variants={cardVariants}
      className="group relative flex flex-col justify-between rounded-2xl bg-white border border-[#E6ECE7] p-6 sm:p-7 shadow-[0_2px_10px_rgba(24,32,27,0.03)] transition-all duration-200 lg:hover:-translate-y-1 lg:hover:border-[#1B432C]/30 lg:hover:shadow-[0_10px_28px_-6px_rgba(27,67,44,0.09)]"
    >
      <div>
        {/* Top Icon and Category */}
        <div className="flex items-center justify-between gap-3 mb-5">
          <div className="w-11 h-11 rounded-xl bg-[#E8F0EA] border border-[#C2D6C6] text-[#1B432C] flex items-center justify-center transition-colors lg:group-hover:bg-[#1B432C] lg:group-hover:text-white lg:group-hover:border-[#1B432C]">
            <Icon className="w-5 h-5 transition-transform duration-200" />
          </div>

          <span className="text-[11px] font-semibold tracking-wider text-[#4A7356] uppercase">
            {category}
          </span>
        </div>

        {/* Feature Title */}
        <h3 className="text-lg font-bold text-[#18201B] tracking-tight mb-2.5">
          {title}
        </h3>

        {/* Feature 1-2 sentence description */}
        <p className="text-sm text-[#4F5D54] leading-relaxed font-normal">
          {description}
        </p>
      </div>

      {/* Subtle bottom indicator */}
      <div className="mt-5 pt-4 border-t border-[#F0F4F1] flex items-center justify-between">
        <span className="text-[11px] font-medium text-[#79877E]">Verified Architecture</span>
        <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]/60" />
      </div>
    </motion.div>
  );
};
