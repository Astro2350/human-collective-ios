#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from editorialize_full_year_candidates import (
    hook_for,
    normalize_origin_text,
    story_for,
    useful_date,
    why_for,
)
from verify_archive_sources import official_detail, expected_maker

ROOT = Path(__file__).resolve().parents[1]
POOL_PATH = ROOT / "Content" / "full_year_candidate_pool.json"


def main():
    data = json.loads(POOL_PATH.read_text())
    failures = []

    for item in data["candidate_curated_items"]:
        official = official_detail(item)
        if not official.get("found"):
            failures.append(item["id"])
            continue

        item["title"] = official.get("title") or item["title"]
        item["date_display"] = useful_date(official.get("date")) or "Date unknown"
        item["maker"] = expected_maker(item, official)
        item["culture"] = normalize_origin_text(official.get("origin")) or item.get("culture")
        item["country"] = None
        item["region"] = None
        item["source_url"] = official.get("source_url") or item.get("source_url")
        item["image_url"] = official.get("image_url") or item.get("image_url")
        item["hook"] = hook_for(item, {})
        item["story"] = story_for(item, {})
        item["why_it_matters"] = why_for(item, {})
        item["editorial_status"] = "source-audited"
        item["curator_note"] = "Title, date, creator, origin, image, and source URL checked against the official source record."

    if failures:
        print(json.dumps({"source_failures": failures}, indent=2))
        sys.exit(1)

    data["source_audit"] = {
        "status": "source_fields_applied",
        "checked_items": len(data["candidate_curated_items"]),
        "fields": [
            "title",
            "date_display",
            "maker",
            "culture",
            "source_url",
            "image_url"
        ],
        "note": "Creator values are concise source-derived names or attribution labels; culture-only maker labels are left empty."
    }
    POOL_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n")
    print(json.dumps({
        "items_updated": len(data["candidate_curated_items"]),
        "written": str(POOL_PATH.relative_to(ROOT))
    }, indent=2))


if __name__ == "__main__":
    main()
