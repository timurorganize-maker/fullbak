'use client';

import { cn } from '@/lib/utils';
import { freshness, STATUS_LABEL } from '@/lib/domain';
import type { StationStatus } from '@/lib/types';

const FRESH_COLOR: Record<string, string> = {
  fresh: 'bg-avail',
  recent: 'bg-low',
  stale: 'bg-stale',
};

/** Small colored dot conveying how fresh a value is. */
export function FreshnessDot({ at, className }: { at?: string; className?: string }) {
  const f = freshness(at);
  return (
    <span
      className={cn('inline-block h-2 w-2 shrink-0 rounded-full', FRESH_COLOR[f], className)}
      aria-hidden
    />
  );
}

const STATUS_BG: Record<StationStatus, string> = {
  available: 'bg-avail/12 text-avail',
  low: 'bg-low/15 text-low',
  out: 'bg-out/12 text-out',
  stale: 'bg-stale/15 text-fg-muted',
};

const STATUS_DOT: Record<StationStatus, string> = {
  available: 'bg-avail',
  low: 'bg-low',
  out: 'bg-out',
  stale: 'bg-stale',
};

export function StatusPill({
  status,
  className,
  label,
}: {
  status: StationStatus;
  className?: string;
  label?: string;
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold',
        STATUS_BG[status],
        className,
      )}
    >
      <span className={cn('h-2 w-2 rounded-full', STATUS_DOT[status])} />
      {label ?? STATUS_LABEL[status]}
    </span>
  );
}
