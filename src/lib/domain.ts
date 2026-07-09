import type {
  AvailabilityReport,
  AvailabilityStatus,
  FuelState,
  FuelType,
  PriceReport,
  Station,
  StationStatus,
  StationView,
} from './types';

export const FUEL_TYPES: FuelType[] = [
  { id: 1, code: 'ai92', label: 'АИ-92' },
  { id: 2, code: 'ai95', label: 'АИ-95' },
  { id: 3, code: 'ai98', label: 'АИ-98' },
  { id: 4, code: 'ai100', label: 'АИ-100' },
  { id: 5, code: 'dt', label: 'ДТ' },
  { id: 6, code: 'gas', label: 'Газ' },
];

export const FUEL_BY_CODE = Object.fromEntries(
  FUEL_TYPES.map((f) => [f.code, f]),
) as Record<string, FuelType>;

export const STALE_MS = 6 * 60 * 60 * 1000; // >6h = серый / нет свежих данных

/** Freshness bucket for a single timestamp — drives the color dot next to a value. */
export type Freshness = 'fresh' | 'recent' | 'stale';

export function freshness(iso: string | undefined, now = Date.now()): Freshness {
  if (!iso) return 'stale';
  const age = now - new Date(iso).getTime();
  if (age < 30 * 60 * 1000) return 'fresh'; // <30 мин — зелёный
  if (age < 3 * 60 * 60 * 1000) return 'recent'; // <3 часов — жёлтый
  return 'stale';
}

const STATUS_RANK: Record<AvailabilityStatus, number> = {
  out: 3,
  low: 2,
  available: 1,
};

/**
 * Build the derived "current" view of a station from its raw report history.
 * Current value = most recent report per fuel; overall marker status is the
 * worst (most alarming) fresh availability across fuels, or "stale" if nothing
 * is fresh within 6h.
 */
export function buildStationView(
  station: Station,
  priceReports: PriceReport[],
  availReports: AvailabilityReport[],
  now = Date.now(),
  origin?: { lat: number; lng: number },
): StationView {
  const fuels: FuelState[] = FUEL_TYPES.map((fuel) => {
    const prices = priceReports
      .filter((r) => r.fuel_code === fuel.code)
      .sort((a, b) => cmpDesc(a.created_at, b.created_at));
    const avails = availReports
      .filter((r) => r.fuel_code === fuel.code)
      .sort((a, b) => cmpDesc(a.created_at, b.created_at));

    const latestPrice = prices[0];
    const latestAvail = avails[0];

    const confirmsLastHour = [...prices, ...avails].filter(
      (r) => now - new Date(r.created_at).getTime() < 60 * 60 * 1000,
    ).length;

    return {
      fuel,
      price: latestPrice?.price,
      priceAt: latestPrice?.created_at,
      priceReportId: latestPrice?.id,
      priceConfirms: latestPrice?.confirms,
      status: latestAvail?.status,
      queue: latestAvail?.queue_length,
      statusAt: latestAvail?.created_at,
      statusReportId: latestAvail?.id,
      statusConfirms: latestAvail?.confirms,
      confirmsLastHour,
    };
  }).filter((f) => f.price !== undefined || f.status !== undefined);

  // Overall status: worst fresh availability, else stale.
  let status: StationStatus = 'stale';
  let worstRank = 0;
  for (const f of fuels) {
    if (!f.status || !f.statusAt) continue;
    if (now - new Date(f.statusAt).getTime() > STALE_MS) continue;
    const rank = STATUS_RANK[f.status];
    if (rank > worstRank) {
      worstRank = rank;
      status = f.status;
    }
  }

  const timestamps = fuels
    .flatMap((f) => [f.priceAt, f.statusAt])
    .filter(Boolean) as string[];
  const lastUpdate =
    timestamps.length > 0
      ? timestamps.sort((a, b) => cmpDesc(a, b))[0]
      : undefined;

  const priced = fuels.filter((f) => f.price !== undefined) as (FuelState & {
    price: number;
  })[];
  const cheapest =
    priced.length > 0
      ? priced.reduce((min, f) => (f.price < min.price ? f : min))
      : undefined;

  return {
    ...station,
    fuels,
    status,
    lastUpdate,
    cheapest: cheapest
      ? { code: cheapest.fuel.code, price: cheapest.price }
      : undefined,
    distanceKm: undefined,
    ...(origin ? {} : {}),
  };
}

function cmpDesc(a: string, b: string): number {
  return new Date(b).getTime() - new Date(a).getTime();
}

export const STATUS_LABEL: Record<StationStatus, string> = {
  available: 'Есть топливо',
  low: 'Мало / очередь',
  out: 'Нет топлива',
  stale: 'Нет свежих данных',
};

export const AVAIL_LABEL: Record<AvailabilityStatus, string> = {
  available: 'В наличии',
  low: 'Заканчивается',
  out: 'Нет',
};

export const QUEUE_LABEL: Record<string, string> = {
  none: 'Без очереди',
  small: 'Небольшая очередь',
  long: 'Большая очередь',
};

/** Tailwind text/bg token name for a status. */
export const STATUS_COLOR: Record<StationStatus, string> = {
  available: 'avail',
  low: 'low',
  out: 'out',
  stale: 'stale',
};

/** Trust level / driver rank from trust_score. */
export function driverLevel(trust: number): {
  name: string;
  next?: number;
  min: number;
  emoji: string;
} {
  const levels = [
    { name: 'Новичок', min: 0, emoji: '🌱' },
    { name: 'Активный водитель', min: 10, emoji: '🚗' },
    { name: 'Проверенный водитель', min: 30, emoji: '⭐' },
    { name: 'Эксперт трассы', min: 75, emoji: '🏆' },
    { name: 'Легенда заправок', min: 150, emoji: '👑' },
  ];
  let current = levels[0];
  let next: number | undefined;
  for (let i = 0; i < levels.length; i++) {
    if (trust >= levels[i].min) {
      current = levels[i];
      next = levels[i + 1]?.min;
    }
  }
  return { name: current.name, min: current.min, next, emoji: current.emoji };
}
