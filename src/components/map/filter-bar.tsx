'use client';

import { useState } from 'react';
import { Check, Search, SlidersHorizontal, X } from 'lucide-react';
import { useStore } from '@/lib/store';
import { FUEL_TYPES } from '@/lib/domain';
import { cn } from '@/lib/utils';
import { hapticTap } from '@/lib/haptics';

export function FilterBar() {
  const { filters, setFilters, allBrands } = useStore();
  const [expanded, setExpanded] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  const activeCount =
    (filters.fuel ? 1 : 0) + (filters.brand ? 1 : 0) + (filters.onlyAvailable ? 1 : 0);

  return (
    <div className="pointer-events-none absolute inset-x-0 top-0 z-20 px-3 pt-[calc(env(safe-area-inset-top)+10px)]">
      <div className="pointer-events-auto mx-auto max-w-lg">
        {/* Search + filter toggle row */}
        <div className="flex items-center gap-2">
          <div className="flex h-12 flex-1 items-center gap-2 rounded-2xl bg-bg-elevated/90 px-3.5 shadow-card backdrop-blur-xl">
            <Search className="h-4.5 w-4.5 shrink-0 text-fg-subtle" />
            <input
              value={filters.query}
              onChange={(e) => setFilters({ query: e.target.value })}
              onFocus={() => setSearchOpen(true)}
              placeholder="Поиск АЗС, бренда, адреса"
              className="h-full w-full bg-transparent text-[15px] outline-none placeholder:text-fg-subtle"
            />
            {filters.query && (
              <button onClick={() => setFilters({ query: '' })}>
                <X className="h-4.5 w-4.5 text-fg-subtle" />
              </button>
            )}
          </div>
          <button
            onClick={() => {
              setExpanded((v) => !v);
              hapticTap();
            }}
            className={cn(
              'relative flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl shadow-card backdrop-blur-xl transition-colors',
              expanded || activeCount > 0
                ? 'bg-brand text-brand-fg'
                : 'bg-bg-elevated/90 text-fg',
            )}
          >
            <SlidersHorizontal className="h-5 w-5" />
            {activeCount > 0 && (
              <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-out text-[11px] font-bold text-white">
                {activeCount}
              </span>
            )}
          </button>
        </div>

        {/* Expanded filters */}
        {expanded && (
          <div className="mt-2 animate-fade-in rounded-2xl bg-bg-elevated/95 p-3 shadow-card backdrop-blur-xl">
            <FilterLabel>Вид топлива</FilterLabel>
            <div className="no-scrollbar -mx-1 flex gap-1.5 overflow-x-auto px-1 pb-1">
              <Chip active={!filters.fuel} onClick={() => setFilters({ fuel: null })}>
                Все
              </Chip>
              {FUEL_TYPES.map((f) => (
                <Chip
                  key={f.code}
                  active={filters.fuel === f.code}
                  onClick={() =>
                    setFilters({ fuel: filters.fuel === f.code ? null : f.code })
                  }
                >
                  {f.label}
                </Chip>
              ))}
            </div>

            <FilterLabel className="mt-3">Бренд</FilterLabel>
            <div className="no-scrollbar -mx-1 flex gap-1.5 overflow-x-auto px-1 pb-1">
              <Chip active={!filters.brand} onClick={() => setFilters({ brand: null })}>
                Все
              </Chip>
              {allBrands.map((b) => (
                <Chip
                  key={b}
                  active={filters.brand === b}
                  onClick={() => setFilters({ brand: filters.brand === b ? null : b })}
                >
                  {b}
                </Chip>
              ))}
            </div>

            <FilterLabel className="mt-3">Сортировка</FilterLabel>
            <div className="flex gap-1.5">
              {(
                [
                  ['distance', 'Ближе'],
                  ['price', 'Дешевле'],
                  ['fresh', 'Свежее'],
                ] as const
              ).map(([v, l]) => (
                <Chip
                  key={v}
                  active={filters.sort === v}
                  onClick={() => setFilters({ sort: v })}
                >
                  {l}
                </Chip>
              ))}
            </div>

            <button
              onClick={() => {
                setFilters({ onlyAvailable: !filters.onlyAvailable });
                hapticTap();
              }}
              className="mt-3 flex w-full items-center justify-between rounded-xl bg-surface-2 px-3.5 py-3"
            >
              <span className="text-sm font-semibold">Только где есть топливо</span>
              <span
                className={cn(
                  'flex h-6 w-6 items-center justify-center rounded-lg border-2 transition-colors',
                  filters.onlyAvailable
                    ? 'border-brand bg-brand text-white'
                    : 'border-fg-subtle/40',
                )}
              >
                {filters.onlyAvailable && <Check className="h-4 w-4" strokeWidth={3} />}
              </span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function FilterLabel({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <p className={cn('mb-1.5 text-xs font-semibold text-fg-subtle', className)}>{children}</p>
  );
}

function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={() => {
        onClick();
        hapticTap();
      }}
      className={cn(
        'shrink-0 rounded-full px-3.5 py-2 text-sm font-semibold transition-colors active:scale-95',
        active ? 'bg-brand text-brand-fg' : 'bg-surface-2 text-fg-muted',
      )}
    >
      {children}
    </button>
  );
}
