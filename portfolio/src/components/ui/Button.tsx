import React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  icon?: React.ReactNode;
  iconPosition?: 'left' | 'right';
  children: React.ReactNode;
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = 'primary',
      size = 'md',
      icon,
      iconPosition = 'left',
      children,
      className,
      ...props
    },
    ref
  ) => {
    const variantStyles = {
      primary:
        'bg-[#1B432C] hover:bg-[#143522] text-white shadow-sm hover:shadow transition-all duration-200 border border-[#1B432C] active:scale-[0.98]',
      secondary:
        'bg-white hover:bg-[#F4F6F4] text-[#18201B] border border-[#E2E8F0] shadow-sm hover:border-[#CBD5E1] transition-all duration-200 active:scale-[0.98]',
      outline:
        'bg-transparent hover:bg-[#E8F0EA]/60 text-[#1B432C] border border-[#C2D6C6] transition-all duration-200 active:scale-[0.98]',
      ghost:
        'bg-transparent hover:bg-[#E8F0EA]/40 text-[#4F5D54] hover:text-[#18201B] transition-all duration-200 active:scale-[0.98]',
    };

    const sizeStyles = {
      sm: 'text-xs px-3.5 py-2 rounded-xl gap-2 font-medium min-h-[38px]',
      md: 'text-sm px-5 py-2.5 rounded-xl gap-2.5 font-medium min-h-[44px]',
      lg: 'text-base px-6 py-3 rounded-xl gap-3 font-semibold min-h-[48px]',
    };

    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center transition-all duration-200 cursor-pointer select-none disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#1B432C] focus-visible:ring-offset-2 focus-visible:ring-offset-[#FAF8F5]',
          variantStyles[variant],
          sizeStyles[size],
          className
        )}
        {...props}
      >
        {icon && iconPosition === 'left' && <span className="shrink-0">{icon}</span>}
        <span>{children}</span>
        {icon && iconPosition === 'right' && <span className="shrink-0">{icon}</span>}
      </button>
    );
  }
);

Button.displayName = 'Button';
