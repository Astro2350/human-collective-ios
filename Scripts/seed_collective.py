#!/usr/bin/env python3
"""Prepare and publish the curated, attributed Collective starter feed."""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import time
import unicodedata
import urllib.request
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass

from PIL import Image, ImageOps


ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "Content" / "collective_seed.json"
CATEGORIES = [
    "painting", "sculpture", "architecture", "car", "watch", "furniture", "fashion",
    "food", "drink", "instrument", "invention", "machine", "tool", "film", "music",
    "game", "book", "monument", "public_space", "engineering_feat",
]
USER_AGENT = "HumanCollectiveSeedPublisher/1.0"
ARTWORK_NAMESPACE = uuid.UUID("9622ca62-e3f9-4f23-a04e-bca95bd88f34")
CONTRIBUTOR_NAMESPACE = uuid.UUID("8131521c-06ef-4d25-9c48-5f2b76f33476")


@dataclass(frozen=True)
class ResolvedItem:
    seed_key: str
    artwork_id: uuid.UUID
    contributor_id: uuid.UUID
    creator_name: str
    significance: str
    category: str
    image_url: str
    image_path: str
    source_name: str
    source_url: str
    rights_label: str
    title: str


def get_json(url: str, attempts: int = 3) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=35) as response:
                return json.load(response)
        except Exception:
            if attempt == attempts - 1:
                raise
            time.sleep(0.5 * (attempt + 1))
    raise RuntimeError("Unreachable")


def nested_dicts(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from nested_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from nested_dicts(child)


def normalized_title(value: str) -> str:
    punctuation_normalized = value.replace("’", "'").replace("‘", "'").replace("—", "-").replace("–", "-")
    folded = unicodedata.normalize("NFKD", punctuation_normalized.casefold()).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", folded).strip()


def title_keywords(value: str) -> set[str]:
    stop_words = {"a", "an", "and", "at", "by", "for", "in", "of", "on", "the", "to", "with"}
    return {word for word in normalized_title(value).split() if word not in stop_words}


def best_loc_jpeg(data: dict) -> str:
    candidates = []
    for resource in data.get("resources") or []:
        for record in nested_dicts(resource.get("files") or []):
            url = record.get("url")
            if record.get("mimetype") == "image/jpeg" and isinstance(url, str) and url.startswith("https://"):
                width = int(record.get("width") or 0)
                height = int(record.get("height") or 0)
                size = int(record.get("size") or 0)
                candidates.append((width * height, size, url))

    if candidates:
        return max(candidates)[2]

    for resource in data.get("resources") or []:
        image = resource.get("image")
        if isinstance(image, str) and image.startswith("https://"):
            if image.endswith(".gif"):
                return image[:-4] + ".jpg"
            return image
    raise RuntimeError("Library of Congress record has no usable image.")


def resolve_item(raw: dict) -> ResolvedItem:
    provider = raw["provider"]
    source_id = str(raw["source_id"])
    seed_key = f"{provider}:{source_id}"

    if provider == "cleveland":
        data = get_json(f"https://openaccess-api.clevelandart.org/api/artworks/{source_id}").get("data") or {}
        image_url = (((data.get("images") or {}).get("print") or {}).get("url"))
        source_name = "Cleveland Museum of Art"
        source_url = data.get("url")
        rights_label = "CC0 / Cleveland Museum of Art Open Access"
        source_title = data.get("title")
    elif provider == "met":
        data = get_json(f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{source_id}")
        if not data.get("isPublicDomain"):
            raise RuntimeError(f"Met record {source_id} is not public domain.")
        image_url = data.get("primaryImage") or data.get("primaryImageSmall")
        source_name = "The Metropolitan Museum of Art"
        source_url = data.get("objectURL")
        rights_label = "Public domain / Met Open Access"
        source_title = data.get("title")
    elif provider == "loc":
        data = get_json(f"https://www.loc.gov/item/{source_id}/?fo=json")
        image_url = best_loc_jpeg(data)
        loc_item = data.get("item") or {}
        date_match = re.search(r"\b(\d{4})\b", str(loc_item.get("date") or ""))
        if not date_match or int(date_match.group(1)) > 1929:
            raise RuntimeError(f"Library of Congress record {source_id} is not dated 1929 or earlier.")
        source_name = "Library of Congress"
        source_url = f"https://www.loc.gov/item/{source_id}/"
        rights_advisory = loc_item.get("rights_advisory")
        rights_label = (
            f"{rights_advisory} / Library of Congress"
            if rights_advisory
            else "Public domain (dated 1929 or earlier) / Library of Congress"
        )
        source_title = loc_item.get("title")
    else:
        raise RuntimeError(f"Unsupported provider: {provider}")

    if not image_url or not source_url or not source_title:
        raise RuntimeError(f"Incomplete source record for {seed_key}.")
    actual_title = normalized_title(source_title)
    expected_title = normalized_title(raw["title"])
    expected_keywords = title_keywords(raw["title"])
    if (
        actual_title != expected_title
        and expected_title not in actual_title
        and not expected_keywords.issubset(title_keywords(source_title))
    ):
        raise RuntimeError(f"Title mismatch for {seed_key}: {source_title!r} != {raw['title']!r}")

    creator_name = raw["creator_name"].strip()
    artwork_id = uuid.uuid5(ARTWORK_NAMESPACE, seed_key)
    contributor_id = uuid.uuid5(CONTRIBUTOR_NAMESPACE, creator_name.casefold())
    return ResolvedItem(
        seed_key=seed_key,
        artwork_id=artwork_id,
        contributor_id=contributor_id,
        creator_name=creator_name,
        significance=raw["significance"].strip(),
        category=raw["category"],
        image_url=image_url,
        image_path=f"seed/{artwork_id}.jpg",
        source_name=source_name,
        source_url=source_url,
        rights_label=rights_label,
        title=raw["title"],
    )


def validate_manifest(data: dict) -> list[dict]:
    items = data.get("items") or []
    expected = int(data.get("posts_per_category") or 0)
    counts = Counter(item.get("category") for item in items)
    if set(counts) != set(CATEGORIES) or any(counts[category] != expected for category in CATEGORIES):
        raise RuntimeError(f"Expected {expected} items in every category; got {dict(counts)}")
    keys = [(item.get("provider"), str(item.get("source_id"))) for item in items]
    if len(keys) != len(set(keys)):
        raise RuntimeError("Seed source records must be unique.")
    for item in items:
        creator_count = len(item.get("creator_name", "").strip())
        significance_count = len(item.get("significance", "").strip())
        if not 2 <= creator_count <= 60:
            raise RuntimeError(f"Invalid creator length for {item.get('title')}")
        if not 40 <= significance_count <= 600:
            raise RuntimeError(f"Invalid significance length for {item.get('title')}")
    return items


def download_image(item: ResolvedItem, seed_directory: pathlib.Path) -> dict:
    request = urllib.request.Request(item.image_url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        source = response.read()

    with Image.open(io.BytesIO(source)) as opened:
        image = ImageOps.exif_transpose(opened).convert("RGB")
        source_size = image.size
        image.thumbnail((2400, 2400), Image.Resampling.LANCZOS)
        if min(image.size) < 480 or image.width * image.height < 500_000:
            raise RuntimeError(f"Image is too small for {item.seed_key}: {image.size}")
        output = seed_directory / f"{item.artwork_id}.jpg"
        image.save(output, "JPEG", quality=88, optimize=True, progressive=True)

    return {
        "seed_key": item.seed_key,
        "source_size": list(source_size),
        "published_size": list(image.size),
        "bytes": output.stat().st_size,
    }


def sql_literal(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def round_robin(items: list[ResolvedItem]) -> list[ResolvedItem]:
    grouped = defaultdict(list)
    for item in items:
        grouped[item.category].append(item)
    return [grouped[category][round_index] for round_index in range(3) for category in CATEGORIES]


def build_sql(items: list[ResolvedItem]) -> str:
    creators = {}
    for item in items:
        creators[item.contributor_id] = item.creator_name

    contributor_values = []
    for contributor_id, creator_name in sorted(creators.items(), key=lambda pair: str(pair[0])):
        installation_hash = hashlib.sha256(f"collective-seed:{creator_name.casefold()}".encode()).hexdigest()
        contributor_values.append(f"('{contributor_id}'::uuid, '{installation_hash}')")

    artwork_values = []
    for position, item in enumerate(round_robin(items)):
        artwork_values.append(
            "(" + ", ".join([
                f"'{item.artwork_id}'::uuid",
                f"'{item.contributor_id}'::uuid",
                sql_literal(item.creator_name),
                sql_literal(item.significance),
                sql_literal(item.category),
                sql_literal(item.image_path),
                f"now() - interval '{position * 11} minutes'",
                "true",
                sql_literal(item.seed_key),
                sql_literal(item.source_name),
                sql_literal(item.source_url),
                sql_literal(item.rights_label),
            ]) + ")"
        )

    contributor_rows = ",\n  ".join(contributor_values)
    artwork_rows = ",\n  ".join(artwork_values)
    return f"""begin;

insert into public.community_contributors (id, installation_hash)
values
  {contributor_rows}
on conflict (id) do update
set installation_hash = excluded.installation_hash;

insert into public.community_artworks (
  id, contributor_id, creator_name, significance, category, image_path,
  published_at, is_active, seed_key, source_name, source_url, rights_label
)
values
  {artwork_rows}
on conflict (seed_key) where seed_key is not null do update
set contributor_id = excluded.contributor_id,
    creator_name = excluded.creator_name,
    significance = excluded.significance,
    category = excluded.category,
    image_path = excluded.image_path,
    published_at = excluded.published_at,
    is_active = true,
    source_name = excluded.source_name,
    source_url = excluded.source_url,
    rights_label = excluded.rights_label;

commit;
"""


def run(*arguments: str) -> str:
    result = subprocess.run(arguments, cwd=ROOT, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publish", action="store_true", help="Upload images and upsert the live seed records")
    parser.add_argument("--workdir", type=pathlib.Path, default=pathlib.Path(tempfile.gettempdir()) / "human-collective-seed")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text())
    raw_items = validate_manifest(manifest)

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        items = list(executor.map(resolve_item, raw_items))

    if args.workdir.exists():
        shutil.rmtree(args.workdir)
    seed_directory = args.workdir / "seed"
    seed_directory.mkdir(parents=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        image_results = list(executor.map(lambda item: download_image(item, seed_directory), items))

    sql_path = args.workdir / "seed.sql"
    sql_path.write_text(build_sql(items))
    report = {
        "items": len(items),
        "categories": dict(Counter(item.category for item in items)),
        "publishers": len(set(item.creator_name for item in items)),
        "images": image_results,
        "sql": str(sql_path),
    }
    (args.workdir / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    if not args.publish:
        print(json.dumps({key: report[key] for key in ["items", "categories", "publishers", "sql"]}, indent=2))
        return 0

    run(
        "supabase", "storage", "cp", "-r", str(seed_directory),
        "ss:///community-artworks", "--jobs", "8", "--content-type", "image/jpeg",
        "--cache-control", "max-age=31536000", "--experimental", "--yes",
    )
    run("supabase", "db", "query", "--linked", "--agent=no", "--output", "json", "-f", str(sql_path))
    print(json.dumps({"published": len(items), "categories": report["categories"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
