import React from 'react';
import { cn } from '@/lib/utils';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  interactive?: boolean;
  glow?: boolean;
}

export const Card: React.FC<CardProps> = ({
  children,
  interactive = false,
  glow = false,
  className,
  ...props
}) => {
  return (
    <div
      className={cn(
        'rounded-2xl bg-white border border-[#E6ECE7] p-6 text-[#18201B] shadow-[0_2px_12px_-2px_rgba(24,32,27,0.04)] transition-all duration-200',
        interactive &&
          'hover:border-[#C2D6C6] hover:shadow-[0_8px_24px_-4px_rgba(27,67,44,0.08)] hover:-translate-y-0.5 cursor-pointer',
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
};
