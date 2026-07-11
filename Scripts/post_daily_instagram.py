#!/usr/bin/env python3
"""Post Human Collective's daily culture item to Instagram.

The script intentionally uses only public app data plus Instagram credentials
provided through the local environment. It does not store tokens in the repo.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from zoneinfo import ZoneInfo


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ENV_PATH = Path.home() / ".human_collective_instagram.env"
DEFAULT_STATE_PATH = Path.home() / ".human_collective_instagram_posts.json"
DEFAULT_TIME_ZONE = "America/Chicago"
DEFAULT_GRAPH_VERSION = "v25.0"


class PostingError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Post the current Human Collective daily artifact to Instagram."
    )
    parser.add_argument("--dry-run", action="store_true", help="Print the selected post without publishing.")
    parser.add_argument("--force", action="store_true", help="Allow reposting today's item.")
    parser.add_argument("--date", help="Override today's date as YYYY-MM-DD for testing.")
    return parser.parse_args()


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if key and key not in os.environ:
            os.environ[key] = value


def read_xcconfig_value(name: str) -> str | None:
    config_paths = [
        PROJECT_ROOT / "HumanCollective" / "Config" / "Release.xcconfig",
        PROJECT_ROOT / "HumanCollective" / "Config" / "Debug.xcconfig",
    ]

    for path in config_paths:
        if not path.exists():
            continue
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("//") or "=" not in line:
                continue
            key, value = [part.strip() for part in line.split("=", 1)]
            if key == name:
                return clean_xcconfig_value(value)
    return None


def clean_xcconfig_value(value: str | None) -> str | None:
    if not value:
        return None
    value = value.strip().strip("'\"")
    value = value.replace("/$()/", "//")
    value = value.replace("$()", "")
    if not value or "$(" in value:
        return None
    return value


def required_value(name: str) -> str:
    value = os.environ.get(name)
    if value:
        return value.strip()
    raise PostingError(f"Missing required environment value: {name}")


def optional_value(name: str, fallback: str | None = None) -> str | None:
    value = os.environ.get(name)
    if value is None or not value.strip():
        return fallback
    return value.strip()


def today_for_run(args: argparse.Namespace) -> dt.date:
    if args.date:
        return dt.date.fromisoformat(args.date)

    env_date = optional_value("TODAY_OVERRIDE")
    if env_date:
        return dt.date.fromisoformat(env_date)

    tz = ZoneInfo(optional_value("POST_TIME_ZONE", DEFAULT_TIME_ZONE) or DEFAULT_TIME_ZONE)
    return dt.datetime.now(tz).date()


def request_json(method: str, url: str, headers: dict[str, str] | None = None, data: dict[str, str] | None = None):
    encoded_data = None
    request_headers = dict(headers or {})

    if data is not None:
        encoded_data = urllib.parse.urlencode(data).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/x-www-form-urlencoded")

    request = urllib.request.Request(url, data=encoded_data, headers=request_headers, method=method)

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise PostingError(f"HTTP {error.code} from {url}: {body}") from error
    except urllib.error.URLError as error:
        raise PostingError(f"Request failed for {url}: {error.reason}") from error

    if not body:
        return {}

    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        raise PostingError(f"Non-JSON response from {url}: {body[:500]}") from error


def supabase_headers(key: str) -> dict[str, str]:
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
    }


def fetch_current_pack(base_url: str, key: str, today: dt.date) -> dict:
    params = urllib.parse.urlencode(
        {
            "select": "*",
            "start_date": f"lte.{today.isoformat()}",
            "end_date": f"gte.{today.isoformat()}",
            "order": "start_date.desc",
            "limit": "1",
        }
    )
    url = f"{base_url.rstrip('/')}/rest/v1/culture_packs?{params}"
    packs = request_json("GET", url, headers=supabase_headers(key))
    if not packs:
        raise PostingError(f"No published Human Collective pack found for {today.isoformat()}.")
    return packs[0]


def fetch_pack_items(base_url: str, key: str, pack_id: str) -> list[dict]:
    params = urllib.parse.urlencode(
        {
            "select": "pack_id,position,item:culture_items(*)",
            "pack_id": f"eq.{pack_id}",
            "order": "position.asc",
        }
    )
    url = f"{base_url.rstrip('/')}/rest/v1/culture_pack_items?{params}"
    rows = request_json("GET", url, headers=supabase_headers(key))
    rows = [row for row in rows if row.get("item")]
    if not rows:
        raise PostingError(f"No items found for Human Collective pack {pack_id}.")
    return sorted(rows, key=lambda row: row.get("position") or 0)


def daily_selection(pack: dict, rows: list[dict], today: dt.date) -> tuple[int, dict]:
    start_text = pack.get("start_date")
    if not start_text:
        raise PostingError(f"Pack {pack.get('id')} is missing a start_date.")

    start_date = dt.date.fromisoformat(start_text)
    candidates = rows[:7]
    index = min(max((today - start_date).days, 0), len(candidates) - 1)
    return index + 1, candidates[index]["item"]


def hashtag(text: str) -> str | None:
    compact = re.sub(r"[^A-Za-z0-9]+", " ", text or "").strip()
    if not compact:
        return None
    parts = compact.split()
    tag = "#" + "".join(part[:1].upper() + part[1:] for part in parts)
    return tag if len(tag) > 1 else None


def caption_for(item: dict) -> str:
    title = (item.get("title") or "Today's artifact").strip()
    hook = (item.get("hook") or item.get("why_it_matters") or "").strip()
    source_name = (item.get("source_name") or "").strip()

    hashtags = [
        "#HumanCollective",
        "#DailyArtifact",
        "#ArtHistory",
        "#CulturalHeritage",
        "#OpenAccessArt",
    ]

    for value in [
        item.get("category"),
        item.get("culture"),
        item.get("country"),
        source_name,
    ]:
        tag = hashtag(value or "")
        if tag and tag not in hashtags:
            hashtags.append(tag)

    lines = [title]
    if hook:
        lines.append(hook)
    if source_name:
        lines.append(f"Source: {source_name}")
    lines.append(" ".join(hashtags[:12]))
    return "\n\n".join(lines)


def load_state(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_state(path: Path, state: dict) -> None:
    path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def publish_to_instagram(item: dict, caption: str) -> dict:
    ig_user_id = required_value("INSTAGRAM_ACCOUNT_ID")
    access_token = required_value("INSTAGRAM_ACCESS_TOKEN")
    graph_version = optional_value("INSTAGRAM_GRAPH_API_VERSION", DEFAULT_GRAPH_VERSION) or DEFAULT_GRAPH_VERSION
    image_url = (item.get("image_url") or "").strip()
    if not image_url:
        raise PostingError(f"Item {item.get('id')} has no image_url.")

    base = f"https://graph.instagram.com/{graph_version}/{ig_user_id}"
    auth_headers = {"Authorization": f"Bearer {access_token}", "Accept": "application/json"}

    container = request_json(
        "POST",
        f"{base}/media",
        headers=auth_headers,
        data={"image_url": image_url, "caption": caption},
    )
    creation_id = str(container.get("id") or "")
    if not creation_id:
        raise PostingError(f"Instagram did not return a media container id: {container}")

    wait_seconds = int(optional_value("INSTAGRAM_PUBLISH_WAIT_SECONDS", "3") or "3")
    if wait_seconds > 0:
        time.sleep(wait_seconds)

    published = request_json(
        "POST",
        f"{base}/media_publish",
        headers=auth_headers,
        data={"creation_id": creation_id},
    )
    if not published.get("id"):
        raise PostingError(f"Instagram did not return a published media id: {published}")

    return {"container_id": creation_id, "media_id": published["id"]}


def main() -> int:
    args = parse_args()
    env_path = Path(optional_value("HUMAN_COLLECTIVE_IG_ENV", str(DEFAULT_ENV_PATH)) or DEFAULT_ENV_PATH)
    load_env_file(env_path)

    supabase_url = optional_value("SUPABASE_URL") or read_xcconfig_value("SUPABASE_URL")
    supabase_key = optional_value("SUPABASE_ANON_KEY") or read_xcconfig_value("SUPABASE_ANON_KEY")
    if not supabase_url or not supabase_key:
        raise PostingError("Missing Supabase URL or publishable key.")

    today = today_for_run(args)
    pack = fetch_current_pack(supabase_url, supabase_key, today)
    rows = fetch_pack_items(supabase_url, supabase_key, pack["id"])
    day_number, item = daily_selection(pack, rows, today)
    caption = caption_for(item)
    dry_run = args.dry_run or optional_value("DRY_RUN", "").lower() in {"1", "true", "yes"}
    force = args.force or optional_value("FORCE_POST", "").lower() in {"1", "true", "yes"}

    state_path = Path(optional_value("HUMAN_COLLECTIVE_IG_STATE", str(DEFAULT_STATE_PATH)) or DEFAULT_STATE_PATH)
    state = load_state(state_path)
    state_key = today.isoformat()
    previous = state.get(state_key)

    print(f"Human Collective daily artifact for {state_key}:")
    print(f"Pack: {pack.get('title')} ({pack.get('week_key')})")
    print(f"Day: {day_number} of {min(len(rows), 7)}")
    print(f"Item: {item.get('title')} [{item.get('id')}]")
    print(f"Image: {item.get('image_url')}")
    print("\nCaption:\n")
    print(caption)

    if previous and previous.get("item_id") == item.get("id") and not force:
        print(f"\nAlready posted {item.get('id')} for {state_key}; skipping.")
        return 0

    if dry_run:
        print("\nDry run only; Instagram was not called.")
        return 0

    result = publish_to_instagram(item, caption)
    state[state_key] = {
        "item_id": item.get("id"),
        "title": item.get("title"),
        "instagram_media_id": result["media_id"],
        "posted_at": dt.datetime.now(dt.timezone.utc).isoformat(),
    }
    save_state(state_path, state)
    print(f"\nPosted to Instagram as media id {result['media_id']}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PostingError as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1)
