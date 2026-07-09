'use client';

import { ChevronRight, Fuel, MapPin } from 'lucide-react';
import type { StationView } from '@/lib/types';
import { useStore } from '@/lib/store';
import { STATUS_LABEL } from '@/lib/domain';
import { cn, formatDistance, formatPrice, timeAgo } from '@/lib/utils';
import { FreshnessDot } from '@/components/ui/indicators';

const DOT: Record<string, string> = {
  available: 'bg-avail',
  low: 'bg-low',
  out: 'bg-out',
  stale: 'bg-stale',
};

export function StationList({ onSelect }: { onSelect: (id: string) => void }) {
  const { stations, filters } = useStore();

  return (
    <div>
      <div className="sticky top-0 z-10 -mx-4 mb-1 bg-bg-elevated/95 px-4 pb-2 pt-1 backdrop-blur">
        <h2 className="text-xl font-bold">Заправки рядом</h2>
        <p className="text-sm text-fg-muted">
          {stations.length}{' '}
          {stations.length === 1 ? 'станция' : 'станций'} · сортировка:{' '}
          {filters.sort === 'price' ? 'дешевле' : filters.sort === 'fresh' ? 'свежее' : 'ближе'}
        </p>
      </div>
      <div className="space-y-2.5 pt-1">
        {stations.map((s) => (
          <StationCard key={s.id} station={s} onSelect={onSelect} activeFuel={filters.fuel} />
        ))}
        {stations.length === 0 && (
          <p className="py-10 text-center text-sm text-fg-subtle">
            Ничего не найдено. Попробуйте изменить фильтры.
          </p>
        )}
      </div>
    </div>
  );
}

export function StationCard({
  station,
  onSelect,
  activeFuel,
}: {
  station: StationView;
  onSelect: (id: string) => void;
  activeFuel?: string | null;
}) {
  const shown =
    (activeFuel && station.fuels.find((f) => f.fuel.code === activeFuel)) ||
    station.fuels.find((f) => f.price != null) ||
    station.fuels[0];

  return (
    <button
      onClick={() => onSelect(station.id)}
      className="flex w-full items-center gap-3 rounded-2xl border border-border/50 bg-surface p-3 text-left transition-transform active:scale-[0.99]"
    >
      <div className="relative flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-surface-2">
        <Fuel className="h-5 w-5 text-fg-muted" />
        <span
          className={cn(
            'absolute -right-0.5 -top-0.5 h-3.5 w-3.5 rounded-full border-2 border-surface',
            DOT[station.status],
          )}
        />
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate font-bold">{station.name}</span>
          <span className="shrink-0 text-xs font-semibold text-fg-subtle">{station.brand}</span>
        </div>
        <div className="mt-0.5 flex items-center gap-2 text-xs text-fg-muted">
          <span className="inline-flex items-center gap-1 truncate">
            <MapPin className="h-3 w-3 shrink-0" />
            <span className="truncate">{station.address}</span>
          </span>
        </div>
        <div className="mt-1.5 flex items-center gap-2">
          <span className={cn('text-[11px] font-bold', statusText(station.status))}>
            {STATUS_LABEL[station.status]}
          </span>
          {station.lastUpdate && (
            <span className="inline-flex items-center gap-1 text-[11px] text-fg-subtle">
              <FreshnessDot at={station.lastUpdate} />
              {timeAgo(station.lastUpdate)}
            </span>
          )}
        </div>
      </div>

      <div className="flex shrink-0 flex-col items-end">
        {shown?.price != null ? (
          <>
            <div className="flex items-baseline gap-0.5">
              <span className="text-xl font-extrabold tnum">{formatPrice(shown.price)}</span>
            </div>
            <span className="text-[11px] font-semibold text-fg-subtle">
              {shown.fuel.label} · ₽/л
            </span>
          </>
        ) : (
          <span className="text-xs text-fg-subtle">нет цены</span>
        )}
        {station.distanceKm != null && (
          <span className="mt-1 rounded-md bg-surface-2 px-1.5 py-0.5 text-[11px] font-bold text-fg-muted tnum">
            {formatDistance(station.distanceKm)}
          </span>
        )}
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-fg-subtle" />
    </button>
  );
}

function statusText(status: StationView['status']): string {
  return {
    available: 'text-avail',
    low: 'text-low',
    out: 'text-out',
    stale: 'text-fg-subtle',
  }[status];
}
