-- Триггеры доверия и антиспама.

-- 1. Автосоздание профиля при регистрации.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone, display_name)
  values (new.id, new.phone, coalesce(new.raw_user_meta_data->>'display_name', 'Водитель'))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Rate limit: не более 1 репорта по одной станции с аккаунта в 5 минут.
create or replace function public.enforce_report_rate_limit()
returns trigger
language plpgsql
as $$
declare
  recent_ct int;
begin
  if tg_table_name = 'price_reports' then
    select count(*) into recent_ct from public.price_reports
      where station_id = new.station_id
        and reported_by = new.reported_by
        and created_at > now() - interval '5 minutes';
  else
    select count(*) into recent_ct from public.availability_reports
      where station_id = new.station_id
        and reported_by = new.reported_by
        and created_at > now() - interval '5 minutes';
  end if;

  if recent_ct > 0 then
    raise exception 'rate_limited: не более 1 репорта по станции в 5 минут';
  end if;
  return new;
end;
$$;

drop trigger if exists rate_limit_price on public.price_reports;
create trigger rate_limit_price
  before insert on public.price_reports
  for each row execute function public.enforce_report_rate_limit();

drop trigger if exists rate_limit_avail on public.availability_reports;
create trigger rate_limit_avail
  before insert on public.availability_reports
  for each row execute function public.enforce_report_rate_limit();

-- 3. reports_count++ при добавлении репорта.
create or replace function public.bump_reports_count()
returns trigger
language plpgsql
as $$
begin
  update public.profiles
    set reports_count = reports_count + 1
    where id = new.reported_by;
  return new;
end;
$$;

drop trigger if exists count_price on public.price_reports;
create trigger count_price after insert on public.price_reports
  for each row execute function public.bump_reports_count();

drop trigger if exists count_avail on public.availability_reports;
create trigger count_avail after insert on public.availability_reports
  for each row execute function public.bump_reports_count();

-- 4. trust_score++ автору репорта, когда его подтверждают (confirm),
--    и −1 при deny (не ниже нуля).
create or replace function public.apply_vote_trust()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  author uuid;
begin
  if new.report_type = 'price' then
    select reported_by into author from public.price_reports where id = new.report_id;
  else
    select reported_by into author from public.availability_reports where id = new.report_id;
  end if;

  if author is null then
    return new;
  end if;

  if new.vote = 'confirm' then
    update public.profiles set trust_score = trust_score + 1 where id = author;
  else
    update public.profiles set trust_score = greatest(0, trust_score - 1) where id = author;
  end if;
  return new;
end;
$$;

drop trigger if exists vote_trust on public.report_votes;
create trigger vote_trust after insert on public.report_votes
  for each row execute function public.apply_vote_trust();
