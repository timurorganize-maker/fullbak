'use client';

import { forwardRef } from 'react';
import { cn } from '@/lib/utils';
import { hapticTap } from '@/lib/haptics';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';
type Size = 'sm' | 'md' | 'lg';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  haptics?: boolean;
}

const VARIANT: Record<Variant, string> = {
  primary: 'bg-brand text-brand-fg active:bg-brand/90 shadow-pill',
  secondary: 'bg-surface-2 text-fg active:bg-surface-2/70',
  ghost: 'bg-transparent text-fg active:bg-surface-2',
  danger: 'bg-out text-white active:bg-out/90',
  success: 'bg-avail text-white active:bg-avail/90 shadow-pill',
};

const SIZE: Record<Size, string> = {
  sm: 'h-9 px-3.5 text-sm rounded-xl',
  md: 'h-12 px-5 text-[15px] rounded-2xl',
  lg: 'h-14 px-6 text-base rounded-2xl',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', haptics = true, className, onClick, children, ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      onClick={(e) => {
        if (haptics) hapticTap();
        onClick?.(e);
      }}
      className={cn(
        'inline-flex select-none items-center justify-center gap-2 font-semibold transition-transform duration-100 active:scale-[0.97] disabled:pointer-events-none disabled:opacity-40',
        VARIANT[variant],
        SIZE[size],
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
});
