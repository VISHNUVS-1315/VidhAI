import React from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps {
  children: React.ReactNode;
  variant?: 'verified' | 'demo' | 'dev' | 'neutral' | 'accent';
  className?: string;
  size?: 'sm' | 'md';
}

export const Badge: React.FC<BadgeProps> = ({
  children,
  variant = 'neutral',
  className,
  size = 'md',
}) => {
  const variantStyles = {
    verified: 'bg-[#E8F0EA] text-[#1B432C] border-[#C2D6C6]',
    demo: 'bg-[#FEF3C7] text-[#92400E] border-[#FDE68A]',
    dev: 'bg-[#EFF6FF] text-[#1E40AF] border-[#DBEAFE]',
    neutral: 'bg-[#F4F6F4] text-[#4F5D54] border-[#E2E8F0]',
    accent: 'bg-[#E8F0EA] text-[#1B432C] border-[#C2D6C6]',
  };

  const sizeStyles = {
    sm: 'text-[11px] px-2.5 py-0.5 rounded-full font-medium tracking-wide',
    md: 'text-xs px-3 py-1 rounded-full font-medium tracking-wide',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 border transition-colors',
        variantStyles[variant],
        sizeStyles[size],
        className
      )}
    >
      {variant === 'verified' && (
        <span className="h-1.5 w-1.5 rounded-full bg-[#1B432C]" />
      )}
      {variant === 'demo' && (
        <span className="h-1.5 w-1.5 rounded-full bg-[#D97706]" />
      )}
      {children}
    </span>
  );
};
