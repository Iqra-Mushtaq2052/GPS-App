-- ════════════════════════════════════════════════════════════════════════
--  Masjid Store migration
--  • Imam accounts (Supabase Auth) + admin approval (imam_profiles)
--  • One imam per mosque + committee members
--  • Nearby registered-mosque search (5 / 10 km) — plain SQL, no PostGIS
--  • Duplicate protection (no two active mosques within 50 m)
--  • Followers (anonymous namazi devices) + Realtime on times/announcements
--
--  Safe to run more than once (idempotent). Run it in:
--  Supabase Dashboard → SQL Editor → New query → paste → Run
-- ════════════════════════════════════════════════════════════════════════

-- ── 1. Base tables (created only if missing, then upgraded) ─────────────
create table if not exists public.mosques (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  latitude       double precision not null,
  longitude      double precision not null,
  radius_meters  integer not null default 40,
  share_code     text unique,
  imam_device_id text,
  created_at     timestamptz not null default now()
);

alter table public.mosques add column if not exists imam_user_id uuid;
alter table public.mosques add column if not exists address      text;
alter table public.mosques add column if not exists is_active    boolean not null default true;
alter table public.mosques add column if not exists updated_at   timestamptz not null default now();
alter table public.mosques alter column imam_device_id drop not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'mosques_imam_user_id_fkey') then
    alter table public.mosques
      add constraint mosques_imam_user_id_fkey
      foreign key (imam_user_id) references auth.users(id) on delete set null;
  end if;
end $$;

create index if not exists mosques_lat_lng_idx on public.mosques (latitude, longitude);
create index if not exists mosques_imam_idx    on public.mosques (imam_user_id);

create table if not exists public.prayer_times (
  mosque_id  uuid not null,
  fajr       text not null default '05:00',
  dhuhr      text not null default '13:00',
  asr        text not null default '17:00',
  maghrib    text not null default '18:30',
  isha       text not null default '20:00',
  updated_at timestamptz not null default now()
);
alter table public.prayer_times add column if not exists jumuah     text;
alter table public.prayer_times add column if not exists updated_by uuid;

create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  mosque_id  uuid not null,
  title      text not null,
  content    text not null,
  created_at timestamptz not null default now()
);
alter table public.announcements add column if not exists created_by uuid;
create index if not exists announcements_mosque_idx on public.announcements (mosque_id, created_at desc);

-- Remove orphans, keep one prayer_times row per mosque, then (re)build FKs
-- with ON DELETE CASCADE so deleting a mosque cleans up its data.
delete from public.prayer_times  pt where not exists (select 1 from public.mosques m where m.id = pt.mosque_id);
delete from public.announcements a  where not exists (select 1 from public.mosques m where m.id = a.mosque_id);
delete from public.prayer_times a using public.prayer_times b
  where a.mosque_id = b.mosque_id and a.ctid < b.ctid;
create unique index if not exists prayer_times_mosque_id_uidx on public.prayer_times (mosque_id);

do $$
declare r record;
begin
  for r in
    select conname, conrelid::regclass as tbl
    from pg_constraint
    where contype = 'f'
      and conrelid in ('public.prayer_times'::regclass, 'public.announcements'::regclass)
      and confrelid = 'public.mosques'::regclass
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
end $$;
alter table public.prayer_times
  add constraint prayer_times_mosque_id_fkey foreign key (mosque_id) references public.mosques(id) on delete cascade;
alter table public.announcements
  add constraint announcements_mosque_id_fkey foreign key (mosque_id) references public.mosques(id) on delete cascade;

-- ── 2. New tables ────────────────────────────────────────────────────────
create table if not exists public.imam_profiles (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null,
  phone       text,
  status      text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note  text,
  created_at  timestamptz not null default now(),
  reviewed_at timestamptz
);

create table if not exists public.mosque_committee (
  mosque_id  uuid not null references public.mosques(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null default 'Committee Member',
  added_by   uuid,
  created_at timestamptz not null default now(),
  primary key (mosque_id, user_id)
);

create table if not exists public.mosque_followers (
  mosque_id  uuid not null references public.mosques(id) on delete cascade,
  device_id  text not null check (char_length(device_id) between 8 and 80),
  created_at timestamptz not null default now(),
  primary key (mosque_id, device_id)
);

-- ── 3. updated_at triggers ──────────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

drop trigger if exists mosques_touch on public.mosques;
create trigger mosques_touch before update on public.mosques
  for each row execute function public.touch_updated_at();
drop trigger if exists prayer_times_touch on public.prayer_times;
create trigger prayer_times_touch before insert or update on public.prayer_times
  for each row execute function public.touch_updated_at();

-- ── 4. Helper functions (used by RLS) ───────────────────────────────────
create or replace function public.is_approved_imam(p_uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from imam_profiles where user_id = p_uid and status = 'approved');
$$;

create or replace function public.is_mosque_imam(p_mosque_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from mosques where id = p_mosque_id and imam_user_id = auth.uid());
$$;

create or replace function public.can_manage_mosque(p_mosque_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from mosques where id = p_mosque_id and imam_user_id = auth.uid())
    or exists (select 1 from mosque_committee where mosque_id = p_mosque_id and user_id = auth.uid())
  );
$$;

create or replace function public._haversine_m(lat1 double precision, lng1 double precision,
                                               lat2 double precision, lng2 double precision)
returns double precision language sql immutable as $$
  select 2 * 6371000 * asin(least(1, sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  )));
$$;

-- ── 5. Row Level Security ───────────────────────────────────────────────
alter table public.mosques          enable row level security;
alter table public.prayer_times     enable row level security;
alter table public.announcements    enable row level security;
alter table public.imam_profiles    enable row level security;
alter table public.mosque_committee enable row level security;
alter table public.mosque_followers enable row level security;

-- Drop every old policy on these tables (the old ones were device-id based
-- and allowed anyone to edit anything).
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname from pg_policies
    where schemaname = 'public'
      and tablename in ('mosques','prayer_times','announcements','imam_profiles','mosque_committee','mosque_followers')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- mosques: everyone reads active ones; only the imam edits/deletes.
-- Inserts only through register_mosque() (approval + duplicate checks).
create policy mosques_read on public.mosques for select
  using (is_active or public.can_manage_mosque(id));
create policy mosques_imam_update on public.mosques for update to authenticated
  using (imam_user_id = auth.uid()) with check (imam_user_id = auth.uid());
create policy mosques_imam_delete on public.mosques for delete to authenticated
  using (imam_user_id = auth.uid());

-- prayer_times: public read; imam + committee write.
create policy prayer_times_read on public.prayer_times for select using (true);
create policy prayer_times_insert on public.prayer_times for insert to authenticated
  with check (public.can_manage_mosque(mosque_id));
create policy prayer_times_update on public.prayer_times for update to authenticated
  using (public.can_manage_mosque(mosque_id)) with check (public.can_manage_mosque(mosque_id));

-- announcements: public read; imam + committee post/delete.
create policy announcements_read on public.announcements for select using (true);
create policy announcements_insert on public.announcements for insert to authenticated
  with check (public.can_manage_mosque(mosque_id) and created_by = auth.uid());
create policy announcements_update on public.announcements for update to authenticated
  using (public.can_manage_mosque(mosque_id)) with check (public.can_manage_mosque(mosque_id));
create policy announcements_delete on public.announcements for delete to authenticated
  using (public.can_manage_mosque(mosque_id));

-- imam_profiles: a user can only read their own row. Writes go through
-- request_imam_access(); approval is done by the admin in the dashboard.
create policy imam_profiles_own on public.imam_profiles for select to authenticated
  using (user_id = auth.uid());

-- committee: members see their own rows, the imam sees the mosque's list.
create policy committee_read on public.mosque_committee for select to authenticated
  using (user_id = auth.uid() or public.is_mosque_imam(mosque_id));

-- followers: no direct access; only via follow/unfollow RPCs.

-- ── 6. RPC functions ────────────────────────────────────────────────────

-- Imam signs up → asks for access (status = pending until admin approves).
create or replace function public.request_imam_access(p_full_name text, p_phone text default null)
returns text language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if coalesce(trim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;

  insert into imam_profiles (user_id, full_name, phone)
  values (auth.uid(), trim(p_full_name), nullif(trim(coalesce(p_phone, '')), ''))
  on conflict (user_id) do update
    set full_name = excluded.full_name,
        phone     = excluded.phone,
        status    = case when imam_profiles.status = 'rejected' then 'pending' else imam_profiles.status end
  returning status into v_status;
  return v_status;
end $$;

-- Registered, approved mosques near a point (radius capped at 10 km).
create or replace function public.nearby_mosques(p_lat double precision, p_lng double precision,
                                                 p_radius_km double precision default 5)
returns table (id uuid, name text, latitude double precision, longitude double precision,
               radius_meters integer, share_code text, address text,
               distance_m double precision, follower_count bigint, has_times boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  v_km   double precision := least(greatest(coalesce(p_radius_km, 5), 0.5), 10);
  v_dlat double precision := v_km / 111.045;
  v_dlng double precision := v_km / (111.045 * greatest(cos(radians(p_lat)), 0.01));
begin
  return query
  select c.id, c.name, c.latitude, c.longitude, c.radius_meters, c.share_code, c.address, c.dist,
         (select count(*) from mosque_followers f where f.mosque_id = c.id),
         exists (select 1 from prayer_times pt where pt.mosque_id = c.id)
  from (
    select m.*, public._haversine_m(p_lat, p_lng, m.latitude, m.longitude) as dist
    from mosques m
    join imam_profiles ip on ip.user_id = m.imam_user_id and ip.status = 'approved'
    where m.is_active
      and m.latitude  between p_lat - v_dlat and p_lat + v_dlat
      and m.longitude between p_lng - v_dlng and p_lng + v_dlng
  ) c
  where c.dist <= v_km * 1000
  order by c.dist
  limit 100;
end $$;

-- Approved imam registers a mosque. Rejects duplicates within 50 m.
create or replace function public.register_mosque(p_name text, p_lat double precision, p_lng double precision,
                                                  p_radius integer default 40, p_address text default null)
returns public.mosques language plpgsql security definer set search_path = public as $$
declare
  v_uid   uuid := auth.uid();
  v_dup   text;
  v_code  text;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_row   mosques;
  i       int;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if not public.is_approved_imam(v_uid) then raise exception 'IMAM_NOT_APPROVED'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'BAD_LOCATION'; end if;

  select m.name into v_dup from mosques m
  where m.is_active
    and m.latitude  between p_lat - 0.001 and p_lat + 0.001
    and m.longitude between p_lng - 0.0015 and p_lng + 0.0015
    and public._haversine_m(p_lat, p_lng, m.latitude, m.longitude) < 50
  limit 1;
  if v_dup is not null then
    raise exception 'DUPLICATE_MOSQUE' using detail = v_dup;
  end if;

  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;
    exit when not exists (select 1 from mosques where share_code = v_code);
  end loop;

  insert into mosques (name, latitude, longitude, radius_meters, share_code, imam_user_id, address)
  values (trim(p_name), p_lat, p_lng, least(greatest(coalesce(p_radius, 40), 15), 150), v_code, v_uid,
          nullif(trim(coalesce(p_address, '')), ''))
  returning * into v_row;

  insert into prayer_times (mosque_id, updated_by) values (v_row.id, v_uid)
  on conflict (mosque_id) do nothing;

  return v_row;
end $$;

-- Mosques the signed-in user manages (as imam or committee).
create or replace function public.my_managed_mosques()
returns table (id uuid, name text, latitude double precision, longitude double precision,
               radius_meters integer, share_code text, address text, is_active boolean,
               my_role text, follower_count bigint)
language sql stable security definer set search_path = public as $$
  select m.id, m.name, m.latitude, m.longitude, m.radius_meters, m.share_code, m.address, m.is_active,
         case when m.imam_user_id = auth.uid() then 'imam' else 'committee' end,
         (select count(*) from mosque_followers f where f.mosque_id = m.id)
  from mosques m
  where m.imam_user_id = auth.uid()
     or exists (select 1 from mosque_committee c where c.mosque_id = m.id and c.user_id = auth.uid())
  order by m.name;
$$;

-- Imam adds a committee member by the email they signed up with.
create or replace function public.add_committee_member(p_mosque_id uuid, p_email text,
                                                       p_title text default 'Committee Member')
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare v_user uuid;
begin
  if not public.is_mosque_imam(p_mosque_id) then raise exception 'ONLY_IMAM'; end if;
  select id into v_user from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_user is null then raise exception 'USER_NOT_FOUND'; end if;
  if v_user = auth.uid() then raise exception 'ALREADY_IMAM'; end if;

  insert into public.mosque_committee (mosque_id, user_id, title, added_by)
  values (p_mosque_id, v_user, coalesce(nullif(trim(p_title), ''), 'Committee Member'), auth.uid())
  on conflict (mosque_id, user_id) do update set title = excluded.title;
  return v_user;
end $$;

create or replace function public.remove_committee_member(p_mosque_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_mosque_imam(p_mosque_id) or p_user_id = auth.uid()) then
    raise exception 'ONLY_IMAM';
  end if;
  delete from mosque_committee where mosque_id = p_mosque_id and user_id = p_user_id;
end $$;

create or replace function public.list_committee(p_mosque_id uuid)
returns table (user_id uuid, email text, full_name text, title text, created_at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.can_manage_mosque(p_mosque_id) then raise exception 'NOT_ALLOWED'; end if;
  return query
  select c.user_id, u.email::text, coalesce(u.raw_user_meta_data->>'full_name', '')::text, c.title, c.created_at
  from public.mosque_committee c join auth.users u on u.id = c.user_id
  where c.mosque_id = p_mosque_id
  order by c.created_at;
end $$;

-- Anonymous namazi devices follow / unfollow (used for follower counts).
create or replace function public.follow_mosque(p_mosque_id uuid, p_device_id text)
returns void language sql security definer set search_path = public as $$
  insert into mosque_followers (mosque_id, device_id) values (p_mosque_id, p_device_id)
  on conflict do nothing;
$$;

create or replace function public.unfollow_mosque(p_mosque_id uuid, p_device_id text)
returns void language sql security definer set search_path = public as $$
  delete from mosque_followers where mosque_id = p_mosque_id and device_id = p_device_id;
$$;

-- ── 7. Grants ───────────────────────────────────────────────────────────
revoke all on function public.request_imam_access(text, text)            from public, anon;
revoke all on function public.register_mosque(text, double precision, double precision, integer, text) from public, anon;
revoke all on function public.my_managed_mosques()                       from public, anon;
revoke all on function public.add_committee_member(uuid, text, text)     from public, anon;
revoke all on function public.remove_committee_member(uuid, uuid)        from public, anon;
revoke all on function public.list_committee(uuid)                       from public, anon;
grant execute on function public.request_imam_access(text, text)         to authenticated;
grant execute on function public.register_mosque(text, double precision, double precision, integer, text) to authenticated;
grant execute on function public.my_managed_mosques()                    to authenticated;
grant execute on function public.add_committee_member(uuid, text, text)  to authenticated;
grant execute on function public.remove_committee_member(uuid, uuid)     to authenticated;
grant execute on function public.list_committee(uuid)                    to authenticated;
grant execute on function public.nearby_mosques(double precision, double precision, double precision) to anon, authenticated;
grant execute on function public.follow_mosque(uuid, text)               to anon, authenticated;
grant execute on function public.unfollow_mosque(uuid, text)             to anon, authenticated;

-- Admin helper view (NOT exposed to the app).
create or replace view public.admin_imam_requests as
  select p.user_id, u.email, p.full_name, p.phone, p.status, p.created_at, p.reviewed_at, p.admin_note
  from public.imam_profiles p join auth.users u on u.id = p.user_id
  order by (p.status = 'pending') desc, p.created_at desc;
revoke all on public.admin_imam_requests from anon, authenticated;

-- ── 8. Realtime ─────────────────────────────────────────────────────────
alter table public.mosques       replica identity full;
alter table public.prayer_times  replica identity full;
alter table public.announcements replica identity full;

do $$
declare t text;
begin
  foreach t in array array['mosques','prayer_times','announcements'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ════════════════════════════════════════════════════════════════════════
--  ADMIN: approve an imam (run in SQL Editor, replace the email):
--    update public.imam_profiles set status = 'approved', reviewed_at = now()
--    where user_id = (select id from auth.users where email = 'imam@example.com');
--
--  See pending requests:
--    select * from public.admin_imam_requests;
-- ════════════════════════════════════════════════════════════════════════
