import React from 'react';
import Image from '@/components/ui/PortfolioImage';
import { cn } from '@/lib/utils';

export interface PhoneFrameProps {
  src: string;
  alt: string;
  className?: string;
  priority?: boolean;
  onImageClick?: () => void;
  statusBadge?: string;
}

export const PhoneFrame: React.FC<PhoneFrameProps> = ({
  src,
  alt,
  className,
  priority = false,
  onImageClick,
  statusBadge,
}) => {
  return (
    <div
      className={cn(
        'relative mx-auto rounded-[36px] p-2.5 sm:p-3 bg-[#18201B] shadow-[0_20px_50px_-10px_rgba(24,32,27,0.18),0_10px_20px_-5px_rgba(24,32,27,0.1)] border border-[#2D3830] transition-all duration-300',
        className
      )}
    >
      {/* Outer Phone Bezel & Camera Speaker Pill */}
      <div className="relative rounded-[28px] overflow-hidden bg-[#0A140D] border border-black/30 aspect-[9/19.5]">
        {/* Top Speaker / Dynamic Island pill */}
        <div className="absolute top-2 left-1/2 -translate-x-1/2 z-20 w-20 h-3.5 bg-black/80 backdrop-blur-md rounded-full flex items-center justify-center gap-1.5 pointer-events-none">
          <div className="w-2 h-2 rounded-full bg-[#222] border border-white/10" />
          <div className="w-1.5 h-1.5 rounded-full bg-[#1B432C]/80" />
        </div>

        {/* Real Screenshot Container */}
        <div
          onClick={onImageClick}
          className={cn(
            'relative w-full h-full overflow-hidden select-none bg-neutral-900',
            onImageClick && 'cursor-pointer group'
          )}
        >
          <Image
            src={src}
            alt={alt}
            fill
            sizes="(max-width: 768px) 100vw, 480px"
            priority={priority}
            className="object-cover object-top transition-transform duration-300 group-hover:scale-[1.01]"
          />

          {/* Genuine Screenshot Verification Badge */}
          {statusBadge && (
            <div className="absolute bottom-3 left-1/2 -translate-x-1/2 z-20 px-3 py-1 bg-black/80 backdrop-blur-md rounded-full border border-white/15 text-[10px] text-white/95 font-medium tracking-wide flex items-center gap-1.5 shadow-lg whitespace-nowrap">
              <span className="w-1.5 h-1.5 rounded-full bg-[#4ADE80]" />
              <span>{statusBadge}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
