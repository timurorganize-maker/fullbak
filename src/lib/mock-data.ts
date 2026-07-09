import type {
  AvailabilityReport,
  AvailabilityStatus,
  FuelCode,
  PriceReport,
  Profile,
  QueueLength,
  Review,
  Station,
} from './types';

// Deterministic pseudo-random so SSR and client agree, and the demo is stable.
function mulberry32(seed: number) {
  return function () {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rnd = mulberry32(20260709);

function pick<T>(arr: T[]): T {
  return arr[Math.floor(rnd() * arr.length)];
}

export const CURRENT_USER: Profile = {
  id: 'me',
  display_name: 'Тимур',
  avatar_url: null,
  trust_score: 42,
  reports_count: 37,
  created_at: '2025-11-02T10:00:00Z',
};

const DRIVERS: Profile[] = [
  CURRENT_USER,
  { id: 'u1', display_name: 'Айгуль', trust_score: 88, reports_count: 120, created_at: '2025-09-01T00:00:00Z' },
  { id: 'u2', display_name: 'Рустам', trust_score: 61, reports_count: 74, created_at: '2025-10-11T00:00:00Z' },
  { id: 'u3', display_name: 'Денис', trust_score: 24, reports_count: 30, created_at: '2025-12-01T00:00:00Z' },
  { id: 'u4', display_name: 'Ленар', trust_score: 7, reports_count: 8, created_at: '2026-01-15T00:00:00Z' },
  { id: 'u5', display_name: 'Марат', trust_score: 155, reports_count: 300, created_at: '2025-06-20T00:00:00Z' },
];

// Base prices (₽/л) with brand variance around these.
const BASE_PRICE: Record<FuelCode, number> = {
  ai92: 54.9,
  ai95: 59.4,
  ai98: 71.2,
  ai100: 82.5,
  dt: 68.3,
  gas: 27.4,
};

interface StationSeed {
  name: string;
  brand: string;
  address: string;
  lat: number;
  lng: number;
  fuels: FuelCode[];
  bias: number; // price offset
  scenario: 'good' | 'low' | 'out' | 'mixed' | 'stale';
}

// ~18 real-ish АЗС spread across Kazan.
const SEEDS: StationSeed[] = [
  { name: 'АЗС №12', brand: 'Татнефть', address: 'ул. Пушкина, 44', lat: 55.7905, lng: 49.1245, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: -0.6, scenario: 'good' },
  { name: 'АЗС Лукойл', brand: 'Лукойл', address: 'пр. Ямашева, 71', lat: 55.8265, lng: 49.1360, fuels: ['ai92', 'ai95', 'ai98', 'ai100', 'dt'], bias: 1.1, scenario: 'mixed' },
  { name: 'Роснефть 116', brand: 'Роснефть', address: 'ул. Декабристов, 133', lat: 55.8320, lng: 49.0930, fuels: ['ai92', 'ai95', 'dt'], bias: 0.4, scenario: 'low' },
  { name: 'Татнефть №27', brand: 'Татнефть', address: 'Сибирский тракт, 34', lat: 55.7830, lng: 49.1720, fuels: ['ai92', 'ai95', 'ai98', 'dt', 'gas'], bias: -0.8, scenario: 'good' },
  { name: 'Газпромнефть', brand: 'Газпромнефть', address: 'пр. Победы, 100', lat: 55.7590, lng: 49.2050, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: 0.9, scenario: 'out' },
  { name: 'ИРБИС', brand: 'ИРБИС', address: 'ул. Космонавтов, 3', lat: 55.8130, lng: 49.2260, fuels: ['ai92', 'ai95', 'dt', 'gas'], bias: -1.4, scenario: 'low' },
  { name: 'Татнефть №5', brand: 'Татнефть', address: 'ул. Баумана, 82', lat: 55.7887, lng: 49.1220, fuels: ['ai92', 'ai95', 'ai98'], bias: -0.5, scenario: 'good' },
  { name: 'Лукойл Центр', brand: 'Лукойл', address: 'ул. Островского, 12', lat: 55.7940, lng: 49.1150, fuels: ['ai92', 'ai95', 'ai98', 'ai100', 'dt'], bias: 1.3, scenario: 'mixed' },
  { name: 'Роснефть Азино', brand: 'Роснефть', address: 'ул. Фучика, 90', lat: 55.7360, lng: 49.1980, fuels: ['ai92', 'ai95', 'dt'], bias: 0.2, scenario: 'out' },
  { name: 'Нефтегаз', brand: 'Нефтегаз', address: 'Оренбургский тракт, 5', lat: 55.7350, lng: 49.1520, fuels: ['ai92', 'ai95', 'dt', 'gas'], bias: -1.1, scenario: 'good' },
  { name: 'Татнефть №41', brand: 'Татнефть', address: 'ул. Гвардейская, 56', lat: 55.7720, lng: 49.1900, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: -0.7, scenario: 'low' },
  { name: 'Газпромнефть Сити', brand: 'Газпромнефть', address: 'ул. Вишневского, 26', lat: 55.7830, lng: 49.1420, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: 1.0, scenario: 'mixed' },
  { name: 'АЗС №8', brand: 'ИРБИС', address: 'Горьковское шоссе, 47', lat: 55.8410, lng: 49.0670, fuels: ['ai92', 'ai95', 'dt', 'gas'], bias: -1.5, scenario: 'good' },
  { name: 'Лукойл Север', brand: 'Лукойл', address: 'пр. Ибрагимова, 88', lat: 55.8300, lng: 49.1080, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: 1.2, scenario: 'stale' },
  { name: 'Татнефть №63', brand: 'Татнефть', address: 'ул. Мавлютова, 24', lat: 55.7290, lng: 49.1780, fuels: ['ai92', 'ai95', 'ai98', 'dt', 'gas'], bias: -0.6, scenario: 'good' },
  { name: 'Роснефть Кремль', brand: 'Роснефть', address: 'ул. Батурина, 7', lat: 55.7980, lng: 49.1050, fuels: ['ai92', 'ai95', 'dt'], bias: 0.5, scenario: 'low' },
  { name: 'Нефтегаз Юг', brand: 'Нефтегаз', address: 'Дубравная ул., 61', lat: 55.7250, lng: 49.1350, fuels: ['ai92', 'ai95', 'dt'], bias: -1.0, scenario: 'out' },
  { name: 'Газпромнефть Восток', brand: 'Газпромнефть', address: 'ул. Академика Глушко, 43', lat: 55.7500, lng: 49.2150, fuels: ['ai92', 'ai95', 'ai98', 'dt'], bias: 0.8, scenario: 'stale' },
];

const HOUR = 60 * 60 * 1000;
const MIN = 60 * 1000;

function iso(msAgo: number, now: number): string {
  return new Date(now - msAgo).toISOString();
}

interface MockDB {
  stations: Station[];
  priceReports: PriceReport[];
  availabilityReports: AvailabilityReport[];
  reviews: Review[];
  drivers: Profile[];
}

export function generateMockDB(now: number = Date.parse('2026-07-09T14:20:00Z')): MockDB {
  const stations: Station[] = [];
  const priceReports: PriceReport[] = [];
  const availabilityReports: AvailabilityReport[] = [];
  const reviews: Review[] = [];

  SEEDS.forEach((seed, si) => {
    const stationId = `st-${si + 1}`;
    stations.push({
      id: stationId,
      name: seed.name,
      brand: seed.brand,
      address: seed.address,
      lat: seed.lat,
      lng: seed.lng,
      created_at: '2025-08-01T00:00:00Z',
    });

    // Freshness per scenario: how long ago the latest reports were.
    const freshMsAgo =
      seed.scenario === 'stale'
        ? 8 * HOUR + Math.floor(rnd() * 4 * HOUR)
        : Math.floor(rnd() * 40 * MIN) + 3 * MIN;

    seed.fuels.forEach((code, fi) => {
      // A few price reports over time (history — we keep them all).
      const basePrice = BASE_PRICE[code] + seed.bias + (rnd() - 0.5) * 0.6;
      for (let k = 0; k < 3; k++) {
        const msAgo = freshMsAgo + k * (40 * MIN + Math.floor(rnd() * HOUR));
        const reporter = pick(DRIVERS);
        priceReports.push({
          id: `pr-${stationId}-${code}-${k}`,
          station_id: stationId,
          fuel_code: code,
          price: Math.round((basePrice - k * 0.1) * 100) / 100,
          reported_by: reporter.id,
          reporter_name: reporter.display_name,
          reporter_trust: reporter.trust_score,
          confirms: Math.floor(rnd() * 6),
          denies: rnd() < 0.2 ? 1 : 0,
          created_at: iso(msAgo, now),
        });
      }

      // Availability status by scenario (first fuel drives the marker most).
      const status = scenarioStatus(seed.scenario, fi);
      const queue = scenarioQueue(status);
      const reporter = pick(DRIVERS);
      availabilityReports.push({
        id: `av-${stationId}-${code}`,
        station_id: stationId,
        fuel_code: code,
        status,
        queue_length: queue,
        reported_by: reporter.id,
        reporter_name: reporter.display_name,
        reporter_trust: reporter.trust_score,
        confirms: Math.floor(rnd() * 8),
        denies: rnd() < 0.15 ? 1 : 0,
        created_at: iso(freshMsAgo + fi * 5 * MIN, now),
      });
    });

    // A couple of reviews per station for a few stations.
    if (si % 2 === 0) {
      const nrev = 1 + Math.floor(rnd() * 3);
      for (let r = 0; r < nrev; r++) {
        const reviewer = pick(DRIVERS);
        reviews.push({
          id: `rv-${stationId}-${r}`,
          station_id: stationId,
          user_id: reviewer.id,
          user_name: reviewer.display_name,
          rating: 3 + Math.floor(rnd() * 3),
          text: pick(REVIEW_TEXTS),
          photo_urls: [],
          helpful: Math.floor(rnd() * 12),
          created_at: iso(Math.floor(rnd() * 20) * HOUR, now),
        });
      }
    }
  });

  return {
    stations,
    priceReports,
    availabilityReports,
    reviews,
    drivers: DRIVERS,
  };
}

function scenarioStatus(
  scenario: StationSeed['scenario'],
  fuelIndex: number,
): AvailabilityStatus {
  switch (scenario) {
    case 'good':
      return 'available';
    case 'low':
      return fuelIndex === 0 ? 'low' : 'available';
    case 'out':
      return fuelIndex <= 1 ? 'out' : 'low';
    case 'mixed':
      return fuelIndex === 0 ? 'available' : fuelIndex === 1 ? 'low' : 'available';
    case 'stale':
      return 'available';
  }
}

function scenarioQueue(status: AvailabilityStatus): QueueLength {
  if (status === 'out') return 'none';
  if (status === 'low') return rnd() < 0.6 ? 'long' : 'small';
  return rnd() < 0.3 ? 'small' : 'none';
}

const REVIEW_TEXTS = [
  'Быстро заправился, очередь небольшая. 95-й был в наличии.',
  'Цены норм для города. Кофе на заправке вкусный ☕',
  'Утром был дизель, к обеду закончился. Обновляйте почаще, ребята.',
  'Всё чётко, работает автомат оплаты картой.',
  'Очередь минут на 20, но топливо есть. Терпимо.',
  'Заправка чистая, персонал вежливый.',
];

export { DRIVERS };
