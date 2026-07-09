'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import type {
  AvailabilityReport,
  AvailabilityStatus,
  FuelCode,
  PriceReport,
  Profile,
  QueueLength,
  Review,
  Station,
  StationView,
} from './types';
import { buildStationView } from './domain';
import { distanceKm } from './utils';
import { CURRENT_USER, generateMockDB } from './mock-data';

export interface Filters {
  fuel: FuelCode | null;
  brand: string | null;
  onlyAvailable: boolean;
  sort: 'distance' | 'price' | 'fresh';
  query: string;
}

export interface QuickReportInput {
  stationId: string;
  fuelCode: FuelCode;
  price?: number;
  status?: AvailabilityStatus;
  queue?: QueueLength;
}

interface PendingReport extends QuickReportInput {
  id: string;
  queuedAt: string;
}

interface StoreValue {
  user: Profile;
  stations: StationView[];
  allBrands: string[];
  reviews: Review[];
  filters: Filters;
  setFilters: (f: Partial<Filters>) => void;
  userLocation: { lat: number; lng: number } | null;
  online: boolean;
  pendingQueue: PendingReport[];
  myReports: Array<{ kind: 'price' | 'availability'; report: PriceReport | AvailabilityReport; stationName: string }>;
  submitReport: (input: QuickReportInput) => { ok: boolean; error?: string };
  voteReport: (
    reportId: string,
    type: 'price' | 'availability',
    vote: 'confirm' | 'deny',
  ) => void;
  addStation: (s: Omit<Station, 'id' | 'created_at' | 'pending'>) => string;
  addReview: (r: Omit<Review, 'id' | 'created_at' | 'user_id' | 'user_name' | 'helpful'>) => void;
  reviewsFor: (stationId: string) => Review[];
  getStation: (id: string) => StationView | undefined;
}

const StoreContext = createContext<StoreValue | null>(null);

const RATE_LIMIT_MS = 5 * 60 * 1000; // 1 report per station / 5 min
const KAZAN_CENTER = { lat: 55.7963, lng: 49.1088 };

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const initial = useMemo(() => generateMockDB(), []);
  const [stations] = useState<Station[]>(initial.stations);
  const [priceReports, setPriceReports] = useState<PriceReport[]>(initial.priceReports);
  const [availReports, setAvailReports] = useState<AvailabilityReport[]>(initial.availabilityReports);
  const [reviews, setReviews] = useState<Review[]>(initial.reviews);
  const [user, setUser] = useState<Profile>(CURRENT_USER);
  const [userStations, setUserStations] = useState<Station[]>([]);
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [online, setOnline] = useState(true);
  const [pendingQueue, setPendingQueue] = useState<PendingReport[]>([]);
  const [now, setNow] = useState(() => Date.now());
  const lastReportAt = useRef<Record<string, number>>({});
  const votedRef = useRef<Set<string>>(new Set());

  const [filters, setFiltersState] = useState<Filters>({
    fuel: null,
    brand: null,
    onlyAvailable: false,
    sort: 'distance',
    query: '',
  });

  const setFilters = useCallback((f: Partial<Filters>) => {
    setFiltersState((prev) => ({ ...prev, ...f }));
  }, []);

  // Geolocation (fallback to Kazan center).
  useEffect(() => {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setUserLocation(KAZAN_CENTER);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => setUserLocation({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      () => setUserLocation(KAZAN_CENTER),
      { enableHighAccuracy: true, timeout: 6000 },
    );
  }, []);

  // Online/offline detection for the offline report queue.
  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    setOnline(navigator.onLine);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  // Refresh "now" every 30s so "N минут назад" stays live.
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(t);
  }, []);

  const applyReport = useCallback(
    (input: QuickReportInput, queuedAt?: string) => {
      const ts = queuedAt ?? new Date().toISOString();
      const id = `local-${Math.random().toString(36).slice(2, 9)}`;
      if (input.price !== undefined) {
        setPriceReports((prev) => [
          {
            id: `pr-${id}`,
            station_id: input.stationId,
            fuel_code: input.fuelCode,
            price: input.price!,
            reported_by: user.id,
            reporter_name: user.display_name,
            reporter_trust: user.trust_score,
            confirms: 0,
            denies: 0,
            created_at: ts,
          },
          ...prev,
        ]);
      }
      if (input.status) {
        setAvailReports((prev) => [
          {
            id: `av-${id}`,
            station_id: input.stationId,
            fuel_code: input.fuelCode,
            status: input.status!,
            queue_length: input.queue ?? 'none',
            reported_by: user.id,
            reporter_name: user.display_name,
            reporter_trust: user.trust_score,
            confirms: 0,
            denies: 0,
            created_at: ts,
          },
          ...prev,
        ]);
      }
      setUser((u) => ({ ...u, reports_count: u.reports_count + 1 }));
    },
    [user.id, user.display_name, user.trust_score],
  );

  // Flush the offline queue when connectivity returns.
  useEffect(() => {
    if (online && pendingQueue.length > 0) {
      const toFlush = pendingQueue;
      setPendingQueue([]);
      toFlush.forEach((p) => applyReport(p, p.queuedAt));
    }
  }, [online, pendingQueue, applyReport]);

  const submitReport = useCallback(
    (input: QuickReportInput): { ok: boolean; error?: string } => {
      const key = input.stationId;
      const last = lastReportAt.current[key] ?? 0;
      if (Date.now() - last < RATE_LIMIT_MS) {
        const wait = Math.ceil((RATE_LIMIT_MS - (Date.now() - last)) / 60000);
        return { ok: false, error: `Вы недавно обновляли эту АЗС. Попробуйте через ${wait} мин.` };
      }
      lastReportAt.current[key] = Date.now();

      if (!online) {
        setPendingQueue((q) => [
          ...q,
          { ...input, id: `q-${Date.now()}`, queuedAt: new Date().toISOString() },
        ]);
        return { ok: true };
      }
      applyReport(input);
      return { ok: true };
    },
    [online, applyReport],
  );

  const voteReport = useCallback(
    (reportId: string, type: 'price' | 'availability', vote: 'confirm' | 'deny') => {
      const voteKey = `${reportId}:${user.id}`;
      if (votedRef.current.has(voteKey)) return;
      votedRef.current.add(voteKey);

      const bump = <T extends PriceReport | AvailabilityReport>(r: T): T => {
        if (r.id !== reportId) return r;
        return {
          ...r,
          confirms: vote === 'confirm' ? r.confirms + 1 : r.confirms,
          denies: vote === 'deny' ? r.denies + 1 : r.denies,
        };
      };

      let reporterId: string | undefined;
      if (type === 'price') {
        setPriceReports((prev) =>
          prev.map((r) => {
            if (r.id === reportId) reporterId = r.reported_by;
            return bump(r);
          }),
        );
      } else {
        setAvailReports((prev) =>
          prev.map((r) => {
            if (r.id === reportId) reporterId = r.reported_by;
            return bump(r);
          }),
        );
      }
      // Confirming someone's report raises their trust_score.
      if (vote === 'confirm' && reporterId === user.id) {
        setUser((u) => ({ ...u, trust_score: u.trust_score + 1 }));
      }
    },
    [user.id],
  );

  const addStation = useCallback(
    (s: Omit<Station, 'id' | 'created_at' | 'pending'>): string => {
      const id = `user-st-${Date.now()}`;
      setUserStations((prev) => [
        ...prev,
        { ...s, id, created_at: new Date().toISOString(), pending: true },
      ]);
      return id;
    },
    [],
  );

  const addReview = useCallback(
    (r: Omit<Review, 'id' | 'created_at' | 'user_id' | 'user_name' | 'helpful'>) => {
      setReviews((prev) => [
        {
          ...r,
          id: `rv-local-${Date.now()}`,
          user_id: user.id,
          user_name: user.display_name,
          helpful: 0,
          created_at: new Date().toISOString(),
        },
        ...prev,
      ]);
    },
    [user.id, user.display_name],
  );

  const allStations = useMemo(() => [...stations, ...userStations], [stations, userStations]);

  const stationViews = useMemo<StationView[]>(() => {
    const origin = userLocation ?? KAZAN_CENTER;
    return allStations.map((st) => {
      const view = buildStationView(
        st,
        priceReports.filter((r) => r.station_id === st.id),
        availReports.filter((r) => r.station_id === st.id),
        now,
      );
      view.distanceKm = distanceKm(origin, { lat: st.lat, lng: st.lng });
      view.pending = st.pending;
      return view;
    });
  }, [allStations, priceReports, availReports, userLocation, now]);

  const filtered = useMemo<StationView[]>(() => {
    let list = stationViews.slice();
    const q = filters.query.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.brand.toLowerCase().includes(q) ||
          s.address.toLowerCase().includes(q),
      );
    }
    if (filters.brand) list = list.filter((s) => s.brand === filters.brand);
    if (filters.fuel) {
      list = list.filter((s) => s.fuels.some((f) => f.fuel.code === filters.fuel));
    }
    if (filters.onlyAvailable) {
      list = list.filter((s) => {
        const rel = filters.fuel
          ? s.fuels.filter((f) => f.fuel.code === filters.fuel)
          : s.fuels;
        return rel.some((f) => f.status === 'available' || f.status === 'low');
      });
    }
    list.sort((a, b) => {
      if (filters.sort === 'price') {
        const pa = priceFor(a, filters.fuel);
        const pb = priceFor(b, filters.fuel);
        if (pa === undefined) return 1;
        if (pb === undefined) return -1;
        return pa - pb;
      }
      if (filters.sort === 'fresh') {
        return freshRank(a) - freshRank(b);
      }
      return (a.distanceKm ?? 9e9) - (b.distanceKm ?? 9e9);
    });
    return list;
  }, [stationViews, filters]);

  const myReports = useMemo(() => {
    const prices = priceReports
      .filter((r) => r.reported_by === user.id)
      .map((report) => ({
        kind: 'price' as const,
        report,
        stationName: allStations.find((s) => s.id === report.station_id)?.name ?? '—',
      }));
    const avails = availReports
      .filter((r) => r.reported_by === user.id)
      .map((report) => ({
        kind: 'availability' as const,
        report,
        stationName: allStations.find((s) => s.id === report.station_id)?.name ?? '—',
      }));
    return [...prices, ...avails].sort(
      (a, b) =>
        new Date(b.report.created_at).getTime() - new Date(a.report.created_at).getTime(),
    );
  }, [priceReports, availReports, user.id, allStations]);

  const allBrands = useMemo(
    () => Array.from(new Set(allStations.map((s) => s.brand))).sort(),
    [allStations],
  );

  const getStation = useCallback(
    (id: string) => stationViews.find((s) => s.id === id),
    [stationViews],
  );

  const reviewsFor = useCallback(
    (stationId: string) =>
      reviews
        .filter((r) => r.station_id === stationId)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    [reviews],
  );

  const value: StoreValue = {
    user,
    stations: filtered,
    allBrands,
    reviews,
    filters,
    setFilters,
    userLocation,
    online,
    pendingQueue,
    myReports,
    submitReport,
    voteReport,
    addStation,
    addReview,
    reviewsFor,
    getStation,
  };

  return <StoreContext.Provider value={value}>{children}</StoreContext.Provider>;
}

function priceFor(s: StationView, fuel: FuelCode | null): number | undefined {
  if (fuel) return s.fuels.find((f) => f.fuel.code === fuel)?.price;
  return s.cheapest?.price;
}

function freshRank(s: StationView): number {
  if (!s.lastUpdate) return 9e15;
  return -new Date(s.lastUpdate).getTime();
}

export function useStore(): StoreValue {
  const ctx = useContext(StoreContext);
  if (!ctx) throw new Error('useStore must be used within StoreProvider');
  return ctx;
}
