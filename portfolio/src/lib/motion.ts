'use client';

import { useSyncExternalStore } from 'react';
import type { Variants } from 'framer-motion';

function subscribeReducedMotion(callback: () => void) {
  if (typeof window === 'undefined') return () => {};
  const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  mediaQuery.addEventListener('change', callback);
  return () => mediaQuery.removeEventListener('change', callback);
}

function getSnapshotReducedMotion(): boolean {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function getServerSnapshotReducedMotion(): boolean {
  return false;
}

/**
 * Custom hook to detect if the user prefers reduced motion
 * Ensures complete accessibility compliance across all animations.
 */
export function usePrefersReducedMotion(): boolean {
  return useSyncExternalStore(
    subscribeReducedMotion,
    getSnapshotReducedMotion,
    getServerSnapshotReducedMotion
  );
}

/**
 * NAMED MOTION PATTERN 1: Seed Reveal
 * Origin seed point expands into root coordinate lines and central system node
 */
export const seedRevealVariants: Variants = {
  hidden: { scale: 0, opacity: 0 },
  visible: {
    scale: 1,
    opacity: 1,
    transition: {
      duration: 0.8,
      ease: [0.16, 1, 0.3, 1],
    },
  },
};

/**
 * NAMED MOTION PATTERN 2: Signal Draw
 * Path stroke drawing for SVG interconnects and data paths
 */
export const signalDrawVariants: Variants = {
  hidden: { pathLength: 0, opacity: 0 },
  visible: {
    pathLength: 1,
    opacity: 1,
    transition: {
      duration: 1.2,
      ease: 'easeInOut',
    },
  },
};

/**
 * NAMED MOTION PATTERN 3: Context Pulse
 * Subtle concentric wave when context is injected
 */
export const contextPulseVariants: Variants = {
  idle: { scale: 1, opacity: 0.4 },
  pulse: {
    scale: [1, 1.2, 1],
    opacity: [0.4, 0.9, 0.4],
    transition: {
      duration: 2.4,
      repeat: Infinity,
      ease: 'easeInOut',
    },
  },
};

/**
 * NAMED MOTION PATTERN 4: Data Weave
 * Braided signal transition between major thematic sections
 */
export const dataWeaveVariants: Variants = {
  hidden: { opacity: 0, scaleY: 0.8 },
  visible: {
    opacity: 1,
    scaleY: 1,
    transition: {
      duration: 0.9,
      ease: [0.22, 1, 0.36, 1],
    },
  },
};

/**
 * NAMED MOTION PATTERN 5: Flow Merge
 * Converging multi-input vectors into a single decision engine
 */
export const flowMergeVariants: Variants = {
  hidden: { opacity: 0, x: -20 },
  visible: (i: number) => ({
    opacity: 1,
    x: 0,
    transition: {
      delay: i * 0.08,
      duration: 0.6,
      ease: [0.16, 1, 0.3, 1],
    },
  }),
};

/**
 * NAMED MOTION PATTERN 6: Insight Resolve
 * Crisp blur-to-sharp resolve for recommendations and market prices
 */
export const insightResolveVariants: Variants = {
  hidden: { opacity: 0, filter: 'blur(8px)', scale: 0.96 },
  visible: {
    opacity: 1,
    filter: 'blur(0px)',
    scale: 1,
    transition: {
      duration: 0.7,
      ease: [0.16, 1, 0.3, 1],
    },
  },
};

/**
 * NAMED MOTION PATTERN 7: Orbit Focus
 * Smooth orbital rotation with active-node illumination
 */
export const orbitFocusVariants: Variants = {
  rest: { scale: 1, filter: 'brightness(1)' },
  focus: {
    scale: 1.05,
    filter: 'brightness(1.25)',
    transition: { duration: 0.3 },
  },
};

/**
 * NAMED MOTION PATTERN 8: Story Pin
 * Active card elevation and highlight line tracking
 */
export const storyPinVariants: Variants = {
  inactive: { opacity: 0.6, scale: 0.95 },
  active: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.4, ease: 'easeOut' },
  },
};

/**
 * NAMED MOTION PATTERN 9: Screenshot Cascade
 * Layered depth arrangement for genuine app screenshots
 */
export const screenshotCascadeVariants: Variants = {
  foreground: {
    opacity: 1,
    scale: 1,
    y: 0,
    zIndex: 20,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
  midground: {
    opacity: 0.45,
    scale: 0.94,
    y: 18,
    zIndex: 10,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
  background: {
    opacity: 0.2,
    scale: 0.88,
    y: 36,
    zIndex: 0,
    transition: { duration: 0.5, ease: [0.16, 1, 0.3, 1] },
  },
};

/**
 * NAMED MOTION PATTERN 10: Architecture Packet Flow
 * Micro-packet translation along directional layer paths
 */
export const packetFlowVariants: Variants = {
  flow: {
    offsetDistance: ['0%', '100%'],
    transition: {
      duration: 3,
      repeat: Infinity,
      ease: 'linear',
    },
  },
};
