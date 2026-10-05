'use client';

import React from 'react';
import { usePrefersReducedMotion } from '@/lib/motion';

interface LivingSignalGridProps {
  density?: 'low' | 'normal' | 'high';
  className?: string;
}

export const LivingSignalGrid: React.FC<LivingSignalGridProps> = ({
  density = 'normal',
  className = '',
}) => {
  const prefersReducedMotion = usePrefersReducedMotion();

  return (
    <div
      aria-hidden="true"
      className={`absolute inset-0 pointer-events-none overflow-hidden select-none ${className}`}
    >
      <svg
        className="w-full h-full opacity-[0.14]"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 1200 800"
        preserveAspectRatio="xMidYMid slice"
      >
        <defs>
          {/* Subtle agricultural grid pattern */}
          <pattern
            id="agri-grid"
            width={density === 'high' ? '40' : '64'}
            height={density === 'high' ? '40' : '64'}
            patternUnits="userSpaceOnUse"
          >
            <path
              d="M 64 0 L 0 0 0 64"
              fill="none"
              stroke="#2E7D32"
              strokeWidth="0.5"
              strokeOpacity="0.4"
            />
            <circle cx="0" cy="0" r="1.5" fill="#4CAF50" fillOpacity="0.6" />
          </pattern>

          {/* Traveling pulse gradient */}
          <linearGradient id="signal-pulse" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#4CAF50" stopOpacity="0" />
            <stop offset="50%" stopColor="#4CAF50" stopOpacity="0.8" />
            <stop offset="100%" stopColor="#81C784" stopOpacity="0" />
          </linearGradient>
        </defs>

        {/* Base Grid Layer */}
        <rect width="100%" height="100%" fill="url(#agri-grid)" />

        {/* Agricultural Elevation / Contour Pathways */}
        <path
          d="M -100 250 C 200 180, 500 320, 800 240 C 1000 190, 1150 280, 1350 220"
          fill="none"
          stroke="#4CAF50"
          strokeWidth="1"
          strokeOpacity="0.35"
          strokeDasharray="6 4"
        />
        <path
          d="M -50 480 C 250 560, 550 420, 850 510 C 1050 570, 1200 460, 1350 500"
          fill="none"
          stroke="#2E7D32"
          strokeWidth="1.2"
          strokeOpacity="0.3"
        />
        <path
          d="M -80 700 C 300 650, 600 780, 950 680 C 1100 640, 1250 720, 1400 660"
          fill="none"
          stroke="#81C784"
          strokeWidth="0.8"
          strokeOpacity="0.25"
          strokeDasharray="8 6"
        />

        {/* Active Signal Trails */}
        {!prefersReducedMotion && (
          <>
            <path
              d="M -100 250 C 200 180, 500 320, 800 240 C 1000 190, 1150 280, 1350 220"
              fill="none"
              stroke="url(#signal-pulse)"
              strokeWidth="2"
              className="contour-pulse-1"
            />
            <path
              d="M -50 480 C 250 560, 550 420, 850 510 C 1050 570, 1200 460, 1350 500"
              fill="none"
              stroke="url(#signal-pulse)"
              strokeWidth="2.5"
              className="contour-pulse-2"
            />
          </>
        )}

        {/* Micro Field Sensing Coordinate Intersections */}
        <g fill="#4CAF50" fillOpacity="0.6">
          <circle cx="200" cy="180" r="2.5" />
          <circle cx="500" cy="320" r="2.5" />
          <circle cx="800" cy="240" r="3" />
          <circle cx="250" cy="560" r="2" />
          <circle cx="850" cy="510" r="2.5" />
          <circle cx="600" cy="780" r="2" />
        </g>
      </svg>
    </div>
  );
};
