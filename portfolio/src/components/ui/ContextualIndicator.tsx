'use client';

import React, { useEffect, useState, useSyncExternalStore } from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';

function subscribeFinePointer(callback: () => void) {
  if (typeof window === 'undefined') return () => {};
  const mediaQuery = window.matchMedia('(pointer: fine)');
  mediaQuery.addEventListener('change', callback);
  return () => mediaQuery.removeEventListener('change', callback);
}

function getSnapshotFinePointer(): boolean {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(pointer: fine)').matches;
}

function getServerSnapshotFinePointer(): boolean {
  return false;
}

export const ContextualIndicator: React.FC = () => {
  const prefersReducedMotion = usePrefersReducedMotion();
  const isFinePointer = useSyncExternalStore(
    subscribeFinePointer,
    getSnapshotFinePointer,
    getServerSnapshotFinePointer
  );
  const [position, setPosition] = useState<{ x: number; y: number }>({ x: -100, y: -100 });
  const [activeLabel, setActiveLabel] = useState<string | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    if (!isFinePointer || prefersReducedMotion) return;

    const handleMouseMove = (e: MouseEvent) => {
      setPosition({ x: e.clientX, y: e.clientY });

      // Look for data-context-label on target or closest ancestor
      const target = e.target as HTMLElement | null;
      const contextEl = target?.closest('[data-context-label]');

      if (contextEl) {
        const label = contextEl.getAttribute('data-context-label');
        setActiveLabel(label);
        setIsVisible(true);
      } else {
        setIsVisible(false);
      }
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, [isFinePointer, prefersReducedMotion]);

  if (!isFinePointer || prefersReducedMotion || !isVisible || !activeLabel) {
    return null;
  }

  return (
    <div
      aria-hidden="true"
      style={{
        transform: `translate3d(${position.x + 14}px, ${position.y + 14}px, 0)`,
      }}
      className="fixed top-0 left-0 pointer-events-none z-50 transition-opacity duration-150 ease-out"
    >
      <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#0E1C12]/95 border border-emerald-500/50 text-emerald-300 shadow-[0_0_15px_rgba(46,125,50,0.4)] backdrop-blur-md">
        <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
        <span className="text-[10px] font-mono uppercase tracking-wider font-semibold">
          {activeLabel}
        </span>
      </div>
    </div>
  );
};
