'use client';

import React from 'react';
import { Download } from 'lucide-react';
import { VIDHAI_APK_URL } from '@/data/project';
import { cn } from '@/lib/utils';

export interface DownloadVidhaiButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'md' | 'lg';
  className?: string;
  showSubLabel?: boolean;
}

export const DownloadVidhaiButton: React.FC<DownloadVidhaiButtonProps> = ({
  variant = 'primary',
  size = 'lg',
  className,
  showSubLabel = false,
}) => {
  const baseStyles =
    'group relative inline-flex items-center justify-center gap-2.5 font-semibold transition-all duration-300 cursor-pointer min-h-[44px] select-none text-center focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#4CAF6C] focus-visible:ring-offset-2 focus-visible:ring-offset-[#0A140D] active:scale-[0.98] motion-reduce:hover:translate-y-0 motion-reduce:transition-none hover:-translate-y-0.5 overflow-hidden';

  const variantStyles = {
    primary:
      'bg-gradient-to-r from-[#205728] to-[#1B4222] hover:from-[#276B32] hover:to-[#22552B] text-[#F1F7F2] border border-emerald-500/40 hover:border-emerald-400/70 shadow-lg shadow-emerald-950/60 hover:shadow-[0_0_25px_rgba(76,175,108,0.35)]',
    secondary:
      'bg-[#14261A] hover:bg-[#1A3222] text-[#F1F7F2] border border-[#233E2B] hover:border-emerald-500/50 shadow-md shadow-black/40 hover:shadow-[0_0_20px_rgba(76,175,108,0.25)]',
  };

  const sizeStyles = {
    md: 'text-sm px-5 py-2.5 rounded-xl',
    lg: 'text-base px-6 py-3 rounded-2xl',
  };

  return (
    <div className="inline-flex flex-col items-center gap-1.5">
      <a
        href={VIDHAI_APK_URL}
        aria-label="Download VidhAI Android APK"
        className={cn(baseStyles, variantStyles[variant], sizeStyles[size], className)}
      >
        {/* Subtle dynamic signal line sweep across border on hover */}
        <span
          aria-hidden="true"
          className="absolute inset-0 w-full h-full pointer-events-none overflow-hidden rounded-2xl"
        >
          <span className="absolute -top-[50%] left-0 w-[40%] h-[200%] bg-gradient-to-r from-transparent via-emerald-400/30 to-transparent transform -skew-x-12 -translate-x-[250%] group-hover:translate-x-[400%] transition-transform duration-1000 ease-out motion-reduce:hidden" />
        </span>

        {/* Download Icon with subtle hover settlement motion */}
        <Download
          size={size === 'lg' ? 18 : 16}
          className="shrink-0 text-emerald-300 transition-transform duration-300 ease-out group-hover:translate-y-0.5 motion-reduce:group-hover:translate-y-0"
        />

        {/* Button Text */}
        <span className="relative z-10 tracking-wide">Download VidhAI</span>
      </a>

      {showSubLabel && (
        <span className="text-[11px] font-mono text-[#718776] tracking-wider uppercase select-none">
          Android APK • v1.0.0
        </span>
      )}
    </div>
  );
};
