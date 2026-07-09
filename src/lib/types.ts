export type FuelCode = 'ai92' | 'ai95' | 'ai98' | 'ai100' | 'dt' | 'gas';

export interface FuelType {
  id: number;
  code: FuelCode;
  label: string;
}

export type AvailabilityStatus = 'available' | 'low' | 'out';
export type QueueLength = 'none' | 'small' | 'long';

export interface Profile {
  id: string;
  display_name: string;
  avatar_url?: string | null;
  trust_score: number;
  reports_count: number;
  created_at: string;
}

export interface PriceReport {
  id: string;
  station_id: string;
  fuel_code: FuelCode;
  price: number;
  reported_by: string;
  reporter_name: string;
  reporter_trust: number;
  confirms: number;
  denies: number;
  created_at: string;
}

export interface AvailabilityReport {
  id: string;
  station_id: string;
  fuel_code: FuelCode;
  status: AvailabilityStatus;
  queue_length: QueueLength;
  reported_by: string;
  reporter_name: string;
  reporter_trust: number;
  confirms: number;
  denies: number;
  created_at: string;
}

export interface Review {
  id: string;
  station_id: string;
  user_id: string;
  user_name: string;
  rating: number;
  text: string;
  photo_urls: string[];
  helpful: number;
  created_at: string;
}

export interface Station {
  id: string;
  name: string;
  brand: string;
  address: string;
  lat: number;
  lng: number;
  pending?: boolean; // added by user, awaiting moderation
  created_at: string;
}

/** Derived, per-fuel "current" state for a station. */
export interface FuelState {
  fuel: FuelType;
  price?: number;
  priceAt?: string;
  priceReportId?: string;
  priceConfirms?: number;
  status?: AvailabilityStatus;
  queue?: QueueLength;
  statusAt?: string;
  statusReportId?: string;
  statusConfirms?: number;
  confirmsLastHour: number;
}

/** Overall marker status for map coloring. */
export type StationStatus = 'available' | 'low' | 'out' | 'stale';

export interface StationView extends Station {
  fuels: FuelState[];
  status: StationStatus;
  lastUpdate?: string; // most recent report across all fuels
  cheapest?: { code: FuelCode; price: number };
  distanceKm?: number;
}
