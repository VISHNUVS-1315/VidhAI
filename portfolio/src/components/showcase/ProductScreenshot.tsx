'use client';

import React from 'react';
import Image from '@/components/ui/PortfolioImage';

export interface ProductScreenshotData {
  id: string;
  file: string;
  title: string;
  category: string;
  description: string;
  width: number;
  height: number;
  featured?: boolean;
}

interface ProductScreenshotProps {
  screenshot: ProductScreenshotData;
  isMain?: boolean;
  onClick?: () => void;
  isActive?: boolean;
}

/**
 * Reusable ProductScreenshot component.
 * Renders verified screenshots in a minimal, premium device frame
 * with un-distorted aspect ratios, subtle borders, and authentic captions.
 */
export const ProductScreenshot: React.FC<ProductScreenshotProps> = ({
  screenshot,
  isMain = false,
  onClick,
  isActive = false,
}) => {
  return (
    <div
      onClick={onClick}
      className={`group flex flex-col h-full rounded-2xl bg-white border transition-all duration-300 ${
        isActive
          ? 'border-[#1B432C] ring-2 ring-[#1B432C]/10 shadow-[0_8px_24px_-4px_rgba(27,67,44,0.08)]'
          : 'border-[#E6ECE7] hover:border-[#C2D6C6] hover:shadow-[0_6px_20px_-4px_rgba(27,67,44,0.06)]'
      } ${onClick ? 'cursor-pointer' : ''}`}
    >
      {/* Device Frame Window Header */}
      <div className="px-4 py-3 border-b border-[#F0F4F1] flex items-center justify-between gap-3 bg-[#FAF8F5]/80 rounded-t-2xl">
        <div className="flex items-center gap-2">
          {/* Subtle minimal frame dots */}
          <span className="w-2 h-2 rounded-full bg-[#E6ECE7] group-hover:bg-[#C2D6C6] transition-colors" />
          <span className="w-2 h-2 rounded-full bg-[#E6ECE7]" />
          <span className="w-2 h-2 rounded-full bg-[#E6ECE7]" />
          <span className="ml-1 text-[11px] font-mono text-[#79877E] font-medium tracking-tight">
            {screenshot.category}
          </span>
        </div>
        <div className="flex items-center gap-1.5 text-[11px] font-medium text-[#1B432C]">
          <span className="w-1.5 h-1.5 rounded-full bg-[#1B432C]" />
          <span>Verified Screen</span>
        </div>
      </div>

      {/* Screenshot Image Container */}
      <div
        className={`relative w-full overflow-hidden bg-[#F6F5F0] flex items-center justify-center p-2 sm:p-3 ${
          isMain ? 'min-h-[280px] sm:min-h-[360px] md:min-h-[440px]' : 'min-h-[200px] sm:min-h-[240px]'
        }`}
      >
        <div className="relative w-full flex items-center justify-center">
          <Image
            src={screenshot.file}
            alt={screenshot.title}
            width={screenshot.width}
            height={screenshot.height}
            className={`rounded-xl object-contain shadow-xs transition-transform duration-300 group-hover:scale-[1.01] ${
              isMain
                ? 'max-h-[380px] sm:max-h-[460px] md:max-h-[520px] w-auto'
                : 'max-h-[220px] sm:max-h-[260px] w-auto'
            }`}
            sizes={
              isMain
                ? '(max-width: 768px) 100vw, (max-width: 1200px) 80vw, 900px'
                : '(max-width: 768px) 100vw, (max-width: 1200px) 33vw, 400px'
            }
          />
        </div>
      </div>

      {/* Caption Content */}
      <div className="p-4 sm:p-5 flex flex-col justify-between flex-1 border-t border-[#F0F4F1]">
        <div>
          <h4
            className={`font-bold text-[#18201B] tracking-tight group-hover:text-[#1B432C] transition-colors ${
              isMain ? 'text-lg sm:text-xl' : 'text-base'
            }`}
          >
            {screenshot.title}
          </h4>
          <p className="text-xs sm:text-sm text-[#4F5D54] leading-relaxed mt-1.5 font-normal">
            {screenshot.description}
          </p>
        </div>
      </div>
    </div>
  );
};
