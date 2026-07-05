create extension if not exists "pgcrypto";

create table if not exists public.culture_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  maker text,
  culture text,
  country text,
  region text,
  date_display text,
  category text,
  image_url text,
  source_name text,
  source_url text,
  license text,
  hook text,
  story text,
  why_it_matters text,
  latitude double precision,
  longitude double precision,
  week_key text,
  created_at timestamp with time zone default now()
);

create table if not exists public.culture_packs (
  id uuid primary key default gen_random_uuid(),
  week_key text unique not null,
  title text not null,
  subtitle text,
  start_date date,
  end_date date,
  created_at timestamp with time zone default now()
);

create table if not exists public.culture_pack_items (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid references public.culture_packs(id) on delete cascade,
  item_id uuid references public.culture_items(id) on delete cascade,
  position int not null
);

create index if not exists culture_items_week_key_idx
  on public.culture_items (week_key);

create index if not exists culture_items_category_idx
  on public.culture_items (category);

create index if not exists culture_packs_week_dates_idx
  on public.culture_packs (start_date desc, end_date desc);

create index if not exists culture_pack_items_pack_position_idx
  on public.culture_pack_items (pack_id, position);

create index if not exists culture_pack_items_item_idx
  on public.culture_pack_items (item_id);

alter table public.culture_items enable row level security;
alter table public.culture_packs enable row level security;
alter table public.culture_pack_items enable row level security;

drop policy if exists "Public read culture items" on public.culture_items;
create policy "Public read culture items"
  on public.culture_items
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Public read culture packs" on public.culture_packs;
create policy "Public read culture packs"
  on public.culture_packs
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Public read culture pack items" on public.culture_pack_items;
create policy "Public read culture pack items"
  on public.culture_pack_items
  for select
  to anon, authenticated
  using (true);

grant usage on schema public to anon, authenticated;
grant select on public.culture_items to anon, authenticated;
grant select on public.culture_packs to anon, authenticated;
grant select on public.culture_pack_items to anon, authenticated;
