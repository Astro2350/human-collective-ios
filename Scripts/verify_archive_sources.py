#!/usr/bin/env python3
import concurrent.futures
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

from editorialize_full_year_candidates import (
    ARCHIVE_TODAY,
    ARCHIVE_YEAR,
    clean,
    completed_archive_week_count,
    iso_week_dates,
    normalize_origin_text,
    useful_date,
    useful_maker,
)

ROOT = Path(__file__).resolve().parents[1]
POOL_PATH = ROOT / "Content" / "full_year_candidate_pool.json"
REPORT_PATH = ROOT / "Content" / "year_to_date_archive_validation.json"


def get_json(url, params=None, retries=2):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
    request = urllib.request.Request(url, headers={"User-Agent": "HumanCollectiveSourceAudit/1.0"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=12) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            if attempt == retries - 1:
                return None
            time.sleep(0.35 * (attempt + 1))
    return None


def clean_url(value):
    value = clean(value)
    if value and value.endswith("/"):
        return value[:-1]
    return value


def official_artic(item):
    object_id = str(item.get("source_object_id") or "")
    fields = ",".join([
        "id",
        "title",
        "artist_display",
        "date_display",
        "place_of_origin",
        "image_id",
    ])
    data = get_json(f"https://api.artic.edu/api/v1/artworks/{object_id}", {"fields": fields})
    record = (data or {}).get("data") or {}
    image_id = clean(record.get("image_id"))
    return {
        "found": bool(record),
        "title": clean(record.get("title")),
        "date": clean(record.get("date_display")),
        "maker": clean(record.get("artist_display")),
        "origin": clean(record.get("place_of_origin")),
        "source_url": f"https://www.artic.edu/artworks/{object_id}" if object_id else None,
        "image_url": f"https://www.artic.edu/iiif/2/{image_id}/full/843,/0/default.jpg" if image_id else None,
    }


def official_cleveland(item):
    object_id = str(item.get("source_object_id") or "")
    data = get_json(f"https://openaccess-api.clevelandart.org/api/artworks/{object_id}")
    record = (data or {}).get("data") or {}
    creators = record.get("creators") or []
    maker = None
    if creators and isinstance(creators[0], dict):
        maker = clean(creators[0].get("description") or creators[0].get("name"))
    images = record.get("images") or {}
    web_image = images.get("web") if isinstance(images, dict) else None
    image_url = web_image.get("url") if isinstance(web_image, dict) else None
    origin = clean(record.get("culture") or record.get("country"))
    return {
        "found": bool(record),
        "title": clean(record.get("title")),
        "date": clean(record.get("creation_date")),
        "maker": maker,
        "origin": origin,
        "source_url": clean(record.get("url")),
        "image_url": clean(image_url),
    }


def official_detail(item):
    source = item.get("content_source_id")
    if source == "artic-public-domain":
        return official_artic(item)
    if source == "cleveland-open-access":
        return official_cleveland(item)
    return {"found": False}


def expected_maker(item, official):
    probe_item = {
        "maker": official.get("maker"),
        "culture": official.get("origin") or item.get("culture"),
        "country": item.get("country"),
        "region": item.get("region"),
    }
    return useful_maker(probe_item, {"maker": official.get("maker"), "place": official.get("origin")})


def normalized(value):
    value = clean(value)
    if not value:
        return None
    value = value.replace("\u2013", "-").replace("\u2014", "-")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def same_text(left, right):
    return normalized(left) == normalized(right)


def origin_is_source_derived(item, official):
    item_origin = normalize_origin_text(item.get("culture"))
    if not item_origin:
        return True
    official_origin = normalize_origin_text(official.get("origin"))
    if not official_origin:
        return False
    return (
        item_origin.lower() == official_origin.lower()
        or item_origin.lower() in official_origin.lower()
        or official_origin.lower() in item_origin.lower()
    )


def verify_item(item):
    issues = []
    official = official_detail(item)
    if not official.get("found"):
        return {
            "id": item["id"],
            "title": item.get("title"),
            "issues": ["source_record_not_found"],
        }

    if not same_text(item.get("title"), official.get("title")):
        issues.append("title_mismatch")

    if useful_date(item.get("date_display")) != useful_date(official.get("date")):
        issues.append("date_mismatch")

    if clean_url(item.get("source_url")) != clean_url(official.get("source_url")):
        issues.append("source_url_mismatch")

    if clean_url(item.get("image_url")) != clean_url(official.get("image_url")):
        issues.append("image_url_mismatch")

    expected = expected_maker(item, official)
    actual = clean(item.get("maker"))
    if actual != expected:
        issues.append("maker_mismatch")

    if not origin_is_source_derived(item, official):
        issues.append("origin_not_source_derived")

    return {
        "id": item["id"],
        "title": item.get("title"),
        "source": item.get("source_name"),
        "issues": issues,
        "expected": {
            "title": official.get("title"),
            "date_display": official.get("date") or "Date unknown",
            "maker": expected,
            "origin": normalize_origin_text(official.get("origin")),
            "source_url": official.get("source_url"),
            "image_url": official.get("image_url"),
        },
        "actual": {
            "title": item.get("title"),
            "date_display": item.get("date_display"),
            "maker": item.get("maker"),
            "origin": item.get("culture"),
            "source_url": item.get("source_url"),
            "image_url": item.get("image_url"),
        },
    }


def verify_packs(data):
    issues = []
    packs = data["candidate_weekly_packs"]
    items = data["candidate_curated_items"]
    item_ids = [item["id"] for item in items]
    source_keys = [
        f"{item.get('source_name')}:{item.get('source_object_id')}"
        for item in items
    ]
    expected_week_count = completed_archive_week_count(ARCHIVE_YEAR, ARCHIVE_TODAY)

    if len(packs) != expected_week_count:
        issues.append(f"pack_count_expected_{expected_week_count}_got_{len(packs)}")

    if len(items) != expected_week_count * 7:
        issues.append(f"item_count_expected_{expected_week_count * 7}_got_{len(items)}")

    duplicates = [item_id for item_id, count in Counter(item_ids).items() if count > 1]
    if duplicates:
        issues.append(f"duplicate_item_ids:{','.join(duplicates[:10])}")

    duplicate_sources = [key for key, count in Counter(source_keys).items() if count > 1]
    if duplicate_sources:
        issues.append(f"duplicate_source_objects:{','.join(duplicate_sources[:10])}")

    pack_item_ids = []
    for index, pack in enumerate(packs, start=1):
        calendar_week_key = f"{ARCHIVE_YEAR}-W{index:02d}"
        expected_week_key = f"full-archive-{calendar_week_key}"
        expected_start, expected_end = iso_week_dates(ARCHIVE_YEAR, index)
        if pack.get("week_key") != expected_week_key:
            issues.append(f"week_key_mismatch:{pack.get('week_key')}:{expected_week_key}")
        if pack.get("start_date") != expected_start or pack.get("end_date") != expected_end:
            issues.append(f"week_date_mismatch:{pack.get('week_key')}")
        if date.fromisoformat(pack["end_date"]) >= ARCHIVE_TODAY:
            issues.append(f"pack_not_completed:{pack.get('week_key')}")
        if len(pack.get("item_ids") or []) != 7:
            issues.append(f"pack_size_mismatch:{pack.get('week_key')}")
        pack_item_ids.extend(pack.get("item_ids") or [])

    duplicate_pack_items = [item_id for item_id, count in Counter(pack_item_ids).items() if count > 1]
    if duplicate_pack_items:
        issues.append(f"duplicate_week_usage:{','.join(duplicate_pack_items[:10])}")

    if set(pack_item_ids) != set(item_ids):
        issues.append("pack_items_do_not_match_selected_items")

    for item in items:
        if item.get("primary_week_key") not in {pack.get("week_key") for pack in packs}:
            issues.append(f"item_week_key_missing:{item['id']}")
            break

    return issues


def main():
    data = json.loads(POOL_PATH.read_text())
    items = data["candidate_curated_items"]
    pack_issues = verify_packs(data)

    with concurrent.futures.ThreadPoolExecutor(max_workers=18) as executor:
        item_reports = list(executor.map(verify_item, items))

    item_failures = [report for report in item_reports if report["issues"]]
    issue_counts = Counter(issue for report in item_failures for issue in report["issues"])
    report = {
        "archive_year": ARCHIVE_YEAR,
        "archive_today": ARCHIVE_TODAY.isoformat(),
        "items_checked": len(items),
        "packs_checked": len(data["candidate_weekly_packs"]),
        "pack_issues": pack_issues,
        "item_issue_counts": dict(issue_counts),
        "item_failures": item_failures,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n")
    print(json.dumps({
        "items_checked": report["items_checked"],
        "packs_checked": report["packs_checked"],
        "pack_issues": len(pack_issues),
        "item_failures": len(item_failures),
        "issue_counts": dict(issue_counts),
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }, indent=2))

    if pack_issues or item_failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
