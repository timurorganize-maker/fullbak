-- ЗаправкаТут — начальная схема БД
-- Краудсорс цен и наличия топлива на АЗС.

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- Профили водителей
-- ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  phone text,
  display_name text,
  avatar_url text,
  trust_score int not null default 0,   -- растёт за подтверждённые репорты
  reports_count int not null default 0,
  is_moderator boolean not null default false,
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- АЗС
-- ─────────────────────────────────────────────────────────────
create table if not exists public.stations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text,
  address text,
  lat double precision not null,
  lng double precision not null,
  status text not null default 'approved' check (status in ('pending','approved','rejected')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists stations_geo_idx on public.stations (lat, lng);
create index if not exists stations_status_idx on public.stations (status);

-- ─────────────────────────────────────────────────────────────
-- Виды топлива (справочник)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.fuel_types (
  id serial primary key,
  code text unique not null,   -- ai92, ai95, ai98, ai100, dt, gas
  label text not null
);

-- ─────────────────────────────────────────────────────────────
-- Репорты по цене (история — не перезаписываем, копим)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.price_reports (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations(id) on delete cascade,
  fuel_type_id int not null references public.fuel_types(id),
  price numeric(6,2) not null check (price > 0 and price < 1000),
  reported_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists price_reports_station_idx
  on public.price_reports (station_id, fuel_type_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- Репорты по наличию топлива (ключевая фича при дефиците)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.availability_reports (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations(id) on delete cascade,
  fuel_type_id int not null references public.fuel_types(id),
  status text not null check (status in ('available','low','out')),
  queue_length text check (queue_length in ('none','small','long')),
  reported_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists availability_reports_station_idx
  on public.availability_reports (station_id, fuel_type_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- Отзывы
-- ─────────────────────────────────────────────────────────────
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.stations(id) on delete cascade,
  user_id uuid references public.profiles(id),
  rating int not null check (rating between 1 and 5),
  text text,
  photo_urls text[] default '{}',
  created_at timestamptz not null default now()
);
create index if not exists reviews_station_idx on public.reviews (station_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- Голоса «подтверждаю / не актуально» по репортам — антиспам
-- ─────────────────────────────────────────────────────────────
create table if not exists public.report_votes (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null,
  report_type text not null check (report_type in ('price','availability')),
  user_id uuid references public.profiles(id),
  vote text not null check (vote in ('confirm','deny')),
  created_at timestamptz not null default now(),
  unique (report_id, report_type, user_id)  -- один голос на репорт от пользователя
);
