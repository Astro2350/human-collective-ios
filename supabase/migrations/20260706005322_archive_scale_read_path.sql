create index if not exists culture_packs_current_lookup_idx
  on public.culture_packs (start_date, end_date)
  where start_date is not null and end_date is not null;

create index if not exists culture_packs_archive_lookup_idx
  on public.culture_packs (end_date desc, start_date desc)
  where end_date is not null;

create index if not exists culture_pack_items_pack_position_item_idx
  on public.culture_pack_items (pack_id, position, item_id);

create index if not exists culture_items_geo_idx
  on public.culture_items (latitude, longitude)
  where latitude is not null and longitude is not null;

alter table public.culture_items enable row level security;
alter table public.culture_packs enable row level security;
alter table public.culture_pack_items enable row level security;

drop policy if exists "Public read culture items" on public.culture_items;
create policy "Public read published culture items"
  on public.culture_items
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.culture_pack_items cpi
      join public.culture_packs cp on cp.id = cpi.pack_id
      where cpi.item_id = culture_items.id
        and cp.start_date <= current_date
    )
  );

drop policy if exists "Public read culture packs" on public.culture_packs;
create policy "Public read published culture packs"
  on public.culture_packs
  for select
  to anon, authenticated
  using (start_date <= current_date);

drop policy if exists "Public read culture pack items" on public.culture_pack_items;
create policy "Public read published culture pack items"
  on public.culture_pack_items
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.culture_packs cp
      where cp.id = culture_pack_items.pack_id
        and cp.start_date <= current_date
    )
  );

grant usage on schema public to anon, authenticated;
grant select on public.culture_items to anon, authenticated;
grant select on public.culture_packs to anon, authenticated;
grant select on public.culture_pack_items to anon, authenticated;
