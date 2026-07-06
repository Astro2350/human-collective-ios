#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POOL_PATH = ROOT / "Content" / "full_year_candidate_pool.json"
OUTPUT_PATH = ROOT / "Content" / "full_year_import.sql"


def sql_json(value):
    payload = json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    return f"$_hc${payload}$_hc$::jsonb"


def main():
    data = json.loads(POOL_PATH.read_text())
    items = []
    cleanup_item_ids = set(data.get("cleanup_item_ids", []))
    item_ids = set()

    for item in data["candidate_curated_items"]:
        item_ids.add(item["id"])
        cleanup_item_ids.add(item["id"])
        items.append({
            "id": item["id"],
            "title": item.get("title") or "Untitled",
            "maker": item.get("maker"),
            "culture": item.get("culture"),
            "country": item.get("country"),
            "region": item.get("region"),
            "date_display": item.get("date_display") or "Date unknown",
            "category": item.get("category") or "object",
            "image_url": item.get("image_url") or "",
            "source_name": item.get("source_name") or "",
            "source_url": item.get("source_url") or "",
            "license": item.get("license") or "",
            "hook": item.get("hook") or "",
            "story": item.get("story") or "",
            "why_it_matters": item.get("why_it_matters") or "",
            "latitude": item.get("latitude"),
            "longitude": item.get("longitude"),
            "week_key": item.get("primary_week_key") or ""
        })

    packs = []
    pack_items = []
    for pack in data["candidate_weekly_packs"]:
        packs.append({
            "id": pack["id"],
            "week_key": pack["week_key"],
            "title": pack.get("title") or "Archive Week",
            "subtitle": pack.get("subtitle"),
            "start_date": pack.get("start_date"),
            "end_date": pack.get("end_date")
        })
        for position, item_id in enumerate(pack["item_ids"], start=1):
            if item_id not in item_ids:
                raise SystemExit(f"Pack {pack['id']} references missing item {item_id}")
            pack_items.append({
                "id": f"{pack['id']}-{position:02d}",
                "pack_id": pack["id"],
                "item_id": item_id,
                "position": position
            })

    cleanup_item_ids = sorted(cleanup_item_ids)

    sql = f"""begin;

delete from public.culture_pack_items
where pack_id like 'full-archive-2025-W%'
   or pack_id like 'full-archive-2026-W%'
   or item_id in (
      select value
      from jsonb_array_elements_text({sql_json(cleanup_item_ids)})
   );

delete from public.culture_packs
where id like 'full-archive-2025-W%'
   or id like 'full-archive-2026-W%';

delete from public.culture_items
where id in (
  select value
  from jsonb_array_elements_text({sql_json(cleanup_item_ids)})
);

with payload as (
  select {sql_json(items)} as doc
)
insert into public.culture_items (
  id,
  title,
  maker,
  culture,
  country,
  region,
  date_display,
  category,
  image_url,
  source_name,
  source_url,
  license,
  hook,
  story,
  why_it_matters,
  latitude,
  longitude,
  week_key
)
select
  id,
  title,
  maker,
  culture,
  country,
  region,
  date_display,
  category,
  image_url,
  source_name,
  source_url,
  license,
  hook,
  story,
  why_it_matters,
  latitude,
  longitude,
  week_key
from jsonb_to_recordset((select doc from payload)) as x(
  id text,
  title text,
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
  week_key text
);

with payload as (
  select {sql_json(packs)} as doc
)
insert into public.culture_packs (
  id,
  week_key,
  title,
  subtitle,
  start_date,
  end_date
)
select
  id,
  week_key,
  title,
  subtitle,
  start_date,
  end_date
from jsonb_to_recordset((select doc from payload)) as x(
  id text,
  week_key text,
  title text,
  subtitle text,
  start_date date,
  end_date date
);

with payload as (
  select {sql_json(pack_items)} as doc
)
insert into public.culture_pack_items (
  id,
  pack_id,
  item_id,
  position
)
select
  id,
  pack_id,
  item_id,
  position
from jsonb_to_recordset((select doc from payload)) as x(
  id text,
  pack_id text,
  item_id text,
  position int
);

commit;
"""

    OUTPUT_PATH.write_text(sql)
    print(json.dumps({
        "written": str(OUTPUT_PATH.relative_to(ROOT)),
        "items": len(items),
        "cleanup_items": len(cleanup_item_ids),
        "packs": len(packs),
        "pack_items": len(pack_items)
    }, indent=2))


if __name__ == "__main__":
    main()
