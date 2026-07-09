'use client';

import { useState } from 'react';
import {
  Check,
  ChevronRight,
  MapPin,
  Navigation,
  RefreshCw,
  Star,
  ThumbsUp,
  Users,
} from 'lucide-react';
import type { FuelState, StationView } from '@/lib/types';
import { AVAIL_LABEL, QUEUE_LABEL } from '@/lib/domain';
import { cn, formatDistance, formatPrice, timeAgo } from '@/lib/utils';
import { FreshnessDot, StatusPill } from '@/components/ui/indicators';
import { Button } from '@/components/ui/button';
import { useStore } from '@/lib/store';
import { hapticSuccess } from '@/lib/haptics';
import { ReviewsSection } from './reviews-section';

const AVAIL_COLOR: Record<string, string> = {
  available: 'text-avail',
  low: 'text-low',
  out: 'text-out',
};

export function StationDetail({
  station,
  onUpdate,
}: {
  station: StationView;
  onUpdate: () => void;
}) {
  const { voteReport } = useStore();
  const confirmsHour = station.fuels.reduce((n, f) => n + f.confirmsLastHour, 0);

  return (
    <div className="animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <h2 className="truncate text-2xl font-bold tracking-tight">{station.name}</h2>
            {station.pending && (
              <span className="rounded-full bg-low/15 px-2 py-0.5 text-[11px] font-semibold text-low">
                на модерации
              </span>
            )}
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-fg-muted">
            <span className="rounded-md bg-surface-2 px-2 py-0.5 font-semibold text-fg">
              {station.brand}
            </span>
            <span className="inline-flex items-center gap-1">
              <MapPin className="h-3.5 w-3.5" /> {station.address}
            </span>
          </div>
        </div>
        {station.distanceKm != null && (
          <div className="flex shrink-0 flex-col items-center rounded-2xl bg-surface-2 px-3 py-2">
            <Navigation className="h-4 w-4 text-brand" />
            <span className="mt-0.5 text-sm font-bold tnum">
              {formatDistance(station.distanceKm)}
            </span>
          </div>
        )}
      </div>

      {/* Status summary */}
      <div className="mt-3 flex flex-wrap items-center gap-2">
        <StatusPill status={station.status} />
        {station.lastUpdate && (
          <span className="inline-flex items-center gap-1.5 text-sm text-fg-muted">
            <FreshnessDot at={station.lastUpdate} />
            обновлено {timeAgo(station.lastUpdate)}
          </span>
        )}
      </div>
      {confirmsHour > 0 && (
        <div className="mt-2 inline-flex items-center gap-1.5 rounded-full bg-brand/10 px-2.5 py-1 text-xs font-semibold text-brand">
          <Users className="h-3.5 w-3.5" />
          {confirmsHour} водител{confirmsHour === 1 ? 'ь' : 'ей'} обновил{confirmsHour === 1 ? '' : 'и'} за последний час
        </div>
      )}

      {/* Fuel prices */}
      <div className="mt-4 grid grid-cols-2 gap-2.5">
        {station.fuels.map((f) => (
          <FuelCard key={f.fuel.code} f={f} onConfirm={voteReport} />
        ))}
      </div>

      {/* Actions */}
      <div className="sticky bottom-0 mt-4 flex gap-2.5 bg-gradient-to-t from-bg-elevated via-bg-elevated to-transparent pb-1 pt-3">
        <ConfirmAllButton station={station} />
        <Button variant="primary" size="lg" className="flex-1" onClick={onUpdate}>
          <RefreshCw className="h-4.5 w-4.5" /> Обновить данные
        </Button>
      </div>

      <ReviewsSection stationId={station.id} />
    </div>
  );
}

function FuelCard({
  f,
  onConfirm,
}: {
  f: FuelState;
  onConfirm: (id: string, type: 'price' | 'availability', vote: 'confirm' | 'deny') => void;
}) {
  const [confirmed, setConfirmed] = useState(false);
  const at = f.priceAt ?? f.statusAt;

  return (
    <div className="rounded-2xl border border-border/60 bg-surface p-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-fg-muted">{f.fuel.label}</span>
        {f.status && (
          <span className={cn('text-xs font-bold', AVAIL_COLOR[f.status])}>
            {AVAIL_LABEL[f.status]}
          </span>
        )}
      </div>
      <div className="mt-1 flex items-baseline gap-1">
        {f.price != null ? (
          <>
            <span className="text-3xl font-extrabold tracking-tight tnum">
              {formatPrice(f.price)}
            </span>
            <span className="text-sm font-semibold text-fg-subtle">₽/л</span>
          </>
        ) : (
          <span className="text-lg font-semibold text-fg-subtle">нет цены</span>
        )}
      </div>
      <div className="mt-1.5 flex items-center justify-between">
        <span className="inline-flex items-center gap-1.5 text-[11px] text-fg-subtle">
          <FreshnessDot at={at} />
          {at ? timeAgo(at) : 'нет данных'}
        </span>
        {f.status === 'low' && f.queue && f.queue !== 'none' && (
          <span className="text-[11px] font-semibold text-low">{QUEUE_LABEL[f.queue]}</span>
        )}
      </div>
      {(f.priceReportId || f.statusReportId) && (
        <button
          disabled={confirmed}
          onClick={() => {
            const id = f.priceReportId ?? f.statusReportId!;
            const type = f.priceReportId ? 'price' : 'availability';
            onConfirm(id, type, 'confirm');
            setConfirmed(true);
            hapticSuccess();
          }}
          className={cn(
            'mt-2.5 flex w-full items-center justify-center gap-1.5 rounded-xl py-2 text-xs font-bold transition-colors',
            confirmed
              ? 'bg-avail/15 text-avail'
              : 'bg-surface-2 text-fg-muted active:bg-surface-2/60',
          )}
        >
          {confirmed ? (
            <>
              <Check className="h-3.5 w-3.5" /> Подтверждено
            </>
          ) : (
            <>
              <ThumbsUp className="h-3.5 w-3.5" /> Всё верно
            </>
          )}
        </button>
      )}
    </div>
  );
}

function ConfirmAllButton({ station }: { station: StationView }) {
  const { voteReport } = useStore();
  const [done, setDone] = useState(false);
  return (
    <Button
      variant={done ? 'success' : 'secondary'}
      size="lg"
      className="shrink-0 px-4"
      disabled={done}
      onClick={() => {
        station.fuels.forEach((f) => {
          if (f.priceReportId) voteReport(f.priceReportId, 'price', 'confirm');
          if (f.statusReportId) voteReport(f.statusReportId, 'availability', 'confirm');
        });
        setDone(true);
        hapticSuccess();
      }}
    >
      {done ? <Check className="h-5 w-5" /> : <ThumbsUp className="h-5 w-5" />}
      {done ? 'Спасибо!' : 'Всё верно'}
    </Button>
  );
}

/** Compact rating stars used in a few places. */
export function Stars({ value, size = 14 }: { value: number; size?: number }) {
  return (
    <span className="inline-flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((i) => (
        <Star
          key={i}
          className={i <= Math.round(value) ? 'fill-low text-low' : 'text-fg-subtle/40'}
          style={{ width: size, height: size }}
        />
      ))}
    </span>
  );
}

export { ChevronRight };
