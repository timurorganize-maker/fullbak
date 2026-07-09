-- Row Level Security: читать может любой, писать репорты — только авторизованные,
-- редактировать/удалять — только автор или модератор.

alter table public.profiles enable row level security;
alter table public.stations enable row level security;
alter table public.fuel_types enable row level security;
alter table public.price_reports enable row level security;
alter table public.availability_reports enable row level security;
alter table public.reviews enable row level security;
alter table public.report_votes enable row level security;

-- Helper: текущий пользователь — модератор?
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select is_moderator from public.profiles where id = auth.uid()),
    false
  );
$$;

-- ── profiles ────────────────────────────────────────────────
create policy "profiles are public read"
  on public.profiles for select using (true);
create policy "user manages own profile"
  on public.profiles for update using (auth.uid() = id);
create policy "user inserts own profile"
  on public.profiles for insert with check (auth.uid() = id);

-- ── fuel_types (справочник) ─────────────────────────────────
create policy "fuel types public read"
  on public.fuel_types for select using (true);

-- ── stations ────────────────────────────────────────────────
create policy "stations public read"
  on public.stations for select using (true);
create policy "authed users add stations"
  on public.stations for insert
  with check (auth.uid() is not null and created_by = auth.uid());
create policy "author or moderator edits station"
  on public.stations for update
  using (created_by = auth.uid() or public.is_moderator());
create policy "author or moderator deletes station"
  on public.stations for delete
  using (created_by = auth.uid() or public.is_moderator());

-- ── price_reports ───────────────────────────────────────────
create policy "price reports public read"
  on public.price_reports for select using (true);
create policy "authed users add price reports"
  on public.price_reports for insert
  with check (auth.uid() is not null and reported_by = auth.uid());
create policy "author or moderator edits price report"
  on public.price_reports for update
  using (reported_by = auth.uid() or public.is_moderator());
create policy "author or moderator deletes price report"
  on public.price_reports for delete
  using (reported_by = auth.uid() or public.is_moderator());

-- ── availability_reports ────────────────────────────────────
create policy "availability reports public read"
  on public.availability_reports for select using (true);
create policy "authed users add availability reports"
  on public.availability_reports for insert
  with check (auth.uid() is not null and reported_by = auth.uid());
create policy "author or moderator edits availability report"
  on public.availability_reports for update
  using (reported_by = auth.uid() or public.is_moderator());
create policy "author or moderator deletes availability report"
  on public.availability_reports for delete
  using (reported_by = auth.uid() or public.is_moderator());

-- ── reviews ─────────────────────────────────────────────────
create policy "reviews public read"
  on public.reviews for select using (true);
create policy "authed users add reviews"
  on public.reviews for insert
  with check (auth.uid() is not null and user_id = auth.uid());
create policy "author or moderator edits review"
  on public.reviews for update
  using (user_id = auth.uid() or public.is_moderator());
create policy "author or moderator deletes review"
  on public.reviews for delete
  using (user_id = auth.uid() or public.is_moderator());

-- ── report_votes ────────────────────────────────────────────
create policy "votes public read"
  on public.report_votes for select using (true);
create policy "authed users vote"
  on public.report_votes for insert
  with check (auth.uid() is not null and user_id = auth.uid());
create policy "user removes own vote"
  on public.report_votes for delete
  using (user_id = auth.uid());
