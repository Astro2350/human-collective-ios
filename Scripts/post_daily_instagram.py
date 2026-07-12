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
    def __init__(
        self,
        message: str,
        *,
        category: str = "unknown",
        retry_safe: bool = False,
        may_have_posted: bool = False,
    ) -> None:
        super().__init__(message)
        self.category = category
        self.retry_safe = retry_safe
        self.may_have_posted = may_have_posted


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
    raise PostingError(
        f"Missing required environment value: {name}", category="configuration_missing"
    )


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


def parse_api_error(body: str) -> tuple[int | None, str]:
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return None, body[:500]

    error = payload.get("error") if isinstance(payload, dict) else None
    if not isinstance(error, dict):
        return None, body[:500]
    code = error.get("code")
    return code if isinstance(code, int) else None, str(error.get("message") or body[:500])


def classify_http_error(service: str, operation: str, status: int, body: str) -> PostingError:
    code, message = parse_api_error(body)
    detail = f"HTTP {status}: {message}"

    if service == "instagram":
        normalized = message.lower()
        if code == 200 and "api access blocked" in normalized:
            return PostingError(
                f"Meta developer account access is blocked. Interactive account confirmation is required. {detail}",
                category="meta_account_locked",
            )
        if code == 190 or "access token" in normalized and "invalid" in normalized:
            return PostingError(
                f"Instagram access token is invalid or expired. Reauthorization is required. {detail}",
                category="instagram_token_invalid",
            )
        if code == 200 or "permission" in normalized:
            return PostingError(
                f"Instagram publishing permission was denied. Check the app permissions and account connection. {detail}",
                category="instagram_permission_denied",
            )
        if operation == "publish":
            return PostingError(
                f"Instagram rejected media publication. Do not retry automatically. {detail}",
                category="instagram_publish_rejected",
            )
        return PostingError(
            f"Instagram rejected {operation}. {detail}",
            category=f"instagram_{operation}_rejected",
        )

    if service == "supabase":
        return PostingError(
            f"Supabase rejected the artifact lookup. HTTP {status}: {body[:500]}",
            category="source_data_http_error",
            retry_safe=status >= 500,
        )

    return PostingError(f"HTTP {status} from {operation}: {body}", category="http_error")


def request_json(
    method: str,
    url: str,
    headers: dict[str, str] | None = None,
    data: dict[str, str] | None = None,
    *,
    service: str = "generic",
    operation: str = "request",
    may_have_posted: bool = False,
):
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
        raise classify_http_error(service, operation, error.code, body) from error
    except urllib.error.URLError as error:
        raise PostingError(
            f"Network request failed during {operation}: {error.reason}",
            category=f"{service}_{operation}_network_error",
            retry_safe=not may_have_posted,
            may_have_posted=may_have_posted,
        ) from error

    if not body:
        return {}

    try:
        return json.loads(body)
    except json.JSONDecodeError as error:
        raise PostingError(
            f"Non-JSON response during {operation}: {body[:500]}",
            category=f"{service}_{operation}_invalid_response",
            may_have_posted=may_have_posted,
        ) from error


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
    packs = request_json(
        "GET", url, headers=supabase_headers(key), service="supabase", operation="fetch_pack"
    )
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
    rows = request_json(
        "GET", url, headers=supabase_headers(key), service="supabase", operation="fetch_items"
    )
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
    except json.JSONDecodeError as error:
        raise PostingError(
            f"Posting state is invalid JSON: {path}. Refusing to risk a duplicate post.",
            category="posting_state_invalid",
        ) from error


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = path.with_name(path.name + ".tmp")
    temporary_path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary_path, path)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def instagram_connection() -> tuple[str, str, dict[str, str]]:
    ig_user_id = required_value("INSTAGRAM_ACCOUNT_ID")
    access_token = required_value("INSTAGRAM_ACCESS_TOKEN")
    graph_version = optional_value("INSTAGRAM_GRAPH_API_VERSION", DEFAULT_GRAPH_VERSION) or DEFAULT_GRAPH_VERSION
    graph_root = f"https://graph.instagram.com/{graph_version}"
    auth_headers = {"Authorization": f"Bearer {access_token}", "Accept": "application/json"}
    return ig_user_id, graph_root, auth_headers


def preflight_instagram(ig_user_id: str, graph_root: str, auth_headers: dict[str, str]) -> dict:
    account = request_json(
        "GET",
        f"{graph_root}/me?fields=id,username,account_type",
        headers=auth_headers,
        service="instagram",
        operation="preflight",
    )
    actual_id = str(account.get("id") or "")
    if actual_id != ig_user_id:
        raise PostingError(
            f"Instagram token belongs to account {actual_id or '<unknown>'}, not configured account {ig_user_id}.",
            category="instagram_account_mismatch",
        )
    account_type = str(account.get("account_type") or "").upper()
    if account_type and account_type not in {"BUSINESS", "CREATOR", "MEDIA_CREATOR"}:
        raise PostingError(
            f"Instagram account is not publishable through this API (account_type={account_type}).",
            category="instagram_account_not_professional",
        )
    return account


def create_media_container(
    ig_user_id: str,
    graph_root: str,
    auth_headers: dict[str, str],
    image_url: str,
    caption: str,
) -> str:
    container = request_json(
        "POST",
        f"{graph_root}/{ig_user_id}/media",
        headers=auth_headers,
        data={"image_url": image_url, "caption": caption},
        service="instagram",
        operation="container_create",
    )
    creation_id = str(container.get("id") or "")
    if not creation_id:
        raise PostingError(
            f"Instagram did not return a media container id: {container}",
            category="instagram_container_invalid_response",
        )
    return creation_id


def wait_for_container(
    graph_root: str,
    auth_headers: dict[str, str],
    creation_id: str,
    *,
    timeout_seconds: int | None = None,
    poll_seconds: int | None = None,
) -> dict:
    timeout = timeout_seconds if timeout_seconds is not None else int(
        optional_value("INSTAGRAM_CONTAINER_TIMEOUT_SECONDS", "60") or "60"
    )
    interval = poll_seconds if poll_seconds is not None else int(
        optional_value("INSTAGRAM_CONTAINER_POLL_SECONDS", "3") or "3"
    )
    deadline = time.monotonic() + max(timeout, 0)

    while True:
        container = request_json(
            "GET",
            f"{graph_root}/{creation_id}?fields=status_code,status",
            headers=auth_headers,
            service="instagram",
            operation="container_status",
        )
        status_code = str(container.get("status_code") or "").upper()
        if status_code in {"FINISHED", "PUBLISHED"}:
            return container
        if status_code in {"ERROR", "EXPIRED"}:
            detail = container.get("status") or status_code
            raise PostingError(
                f"Instagram media container {creation_id} failed: {detail}",
                category="instagram_container_failed",
            )
        if time.monotonic() >= deadline:
            raise PostingError(
                f"Instagram media container {creation_id} was not ready within {timeout} seconds.",
                category="instagram_container_timeout",
                retry_safe=True,
            )
        if interval > 0:
            time.sleep(interval)


def publish_media_container(
    ig_user_id: str,
    graph_root: str,
    auth_headers: dict[str, str],
    creation_id: str,
) -> str:
    published = request_json(
        "POST",
        f"{graph_root}/{ig_user_id}/media_publish",
        headers=auth_headers,
        data={"creation_id": creation_id},
        service="instagram",
        operation="publish",
        may_have_posted=True,
    )
    media_id = str(published.get("id") or "")
    if not media_id:
        raise PostingError(
            f"Instagram did not return a published media id: {published}",
            category="instagram_publish_invalid_response",
            may_have_posted=True,
        )
    return media_id


def find_matching_recent_media(
    ig_user_id: str,
    graph_root: str,
    auth_headers: dict[str, str],
    caption: str,
    started_at: str | None = None,
) -> dict | None:
    earliest_timestamp = None
    if started_at:
        try:
            earliest_timestamp = dt.datetime.fromisoformat(started_at.replace("Z", "+00:00"))
        except ValueError as error:
            raise PostingError(
                f"Posting state has an invalid started_at timestamp: {started_at}",
                category="posting_state_invalid",
            ) from error
        earliest_timestamp -= dt.timedelta(minutes=5)

    params = urllib.parse.urlencode({"fields": "id,caption,timestamp,permalink", "limit": "25"})
    payload = request_json(
        "GET",
        f"{graph_root}/{ig_user_id}/media?{params}",
        headers=auth_headers,
        service="instagram",
        operation="reconcile",
    )
    for media in payload.get("data") or []:
        if str(media.get("caption") or "") != caption:
            continue
        if earliest_timestamp:
            timestamp = str(media.get("timestamp") or "")
            try:
                media_timestamp = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            except ValueError:
                continue
            if media_timestamp < earliest_timestamp:
                continue
        return media
    return None


def state_entry_is_published(entry: dict | None) -> bool:
    if not entry:
        return False
    return bool(entry.get("instagram_media_id")) or entry.get("stage") == "published"


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

    if previous and state_entry_is_published(previous) and not force:
        if previous.get("item_id") == item.get("id"):
            print(f"\nAlready posted {item.get('id')} for {state_key}; skipping.")
            return 0
        raise PostingError(
            f"Posting state already contains a published item for {state_key}: "
            f"{previous.get('item_id')}. Refusing to post changed item {item.get('id')} without --force.",
            category="posting_state_date_conflict",
        )

    if previous and previous.get("item_id") != item.get("id") and not force:
        raise PostingError(
            f"Posting state for {state_key} belongs to {previous.get('item_id')}, not {item.get('id')}. "
            "Manual review is required.",
            category="posting_state_item_conflict",
        )

    if dry_run:
        print("\nDry run only; Instagram was not called.")
        return 0

    image_url = (item.get("image_url") or "").strip()
    if not image_url:
        raise PostingError(
            f"Item {item.get('id')} has no image_url.", category="artifact_image_missing"
        )

    ig_user_id, graph_root, auth_headers = instagram_connection()
    account = preflight_instagram(ig_user_id, graph_root, auth_headers)
    print(f"\nInstagram preflight passed for @{account.get('username') or ig_user_id}.")

    creation_id = ""
    if previous and previous.get("item_id") == item.get("id") and not force:
        matching_media = find_matching_recent_media(
            ig_user_id,
            graph_root,
            auth_headers,
            previous.get("caption") or caption,
            previous.get("started_at"),
        )
        if matching_media:
            media_id = str(matching_media.get("id") or "")
            previous.update(
                {
                    "stage": "published",
                    "instagram_media_id": media_id,
                    "posted_at": matching_media.get("timestamp") or utc_now(),
                    "reconciled_at": utc_now(),
                }
            )
            save_state(state_path, state)
            print(f"Reconciled an existing Instagram post as media id {media_id}; no new post created.")
            return 0

        previous_stage = previous.get("stage")
        if previous_stage == "container_created" and previous.get("container_id"):
            creation_id = str(previous["container_id"])
            print(f"Resuming saved media container {creation_id}.")
        elif previous_stage == "creating_container":
            print("Previous container creation did not return an id; creating a replacement container.")
        elif previous_stage in {
            "publishing",
            "publishing_unknown",
            "publish_failed",
            "container_create_failed",
        }:
            raise PostingError(
                f"Previous attempt is in stage '{previous_stage}' and no matching post was found. "
                "Manual review is required before another publish attempt.",
                category="instagram_pending_manual_review",
                may_have_posted=previous_stage in {"publishing", "publishing_unknown"},
            )
        else:
            raise PostingError(
                f"Previous attempt has unknown stage {previous_stage!r}. "
                "Manual review is required before publishing.",
                category="posting_state_unknown_stage",
            )

    if not creation_id:
        state[state_key] = {
            "stage": "creating_container",
            "item_id": item.get("id"),
            "title": item.get("title"),
            "caption": caption,
            "image_url": image_url,
            "started_at": utc_now(),
            "updated_at": utc_now(),
        }
        save_state(state_path, state)
        try:
            creation_id = create_media_container(
                ig_user_id, graph_root, auth_headers, image_url, caption
            )
        except PostingError as error:
            state[state_key].update(
                {
                    "stage": "container_create_failed",
                    "last_error_category": error.category,
                    "last_error": str(error),
                    "updated_at": utc_now(),
                }
            )
            save_state(state_path, state)
            raise
        state[state_key].update(
            {"stage": "container_created", "container_id": creation_id, "updated_at": utc_now()}
        )
        save_state(state_path, state)

    try:
        wait_for_container(graph_root, auth_headers, creation_id)
    except PostingError as error:
        state[state_key].update(
            {
                "stage": "container_created",
                "last_error_category": error.category,
                "last_error": str(error),
                "updated_at": utc_now(),
            }
        )
        save_state(state_path, state)
        raise

    state[state_key].update({"stage": "publishing", "updated_at": utc_now()})
    save_state(state_path, state)
    try:
        media_id = publish_media_container(
            ig_user_id, graph_root, auth_headers, creation_id
        )
    except PostingError as error:
        state[state_key].update(
            {
                "stage": "publishing_unknown" if error.may_have_posted else "publish_failed",
                "last_error_category": error.category,
                "last_error": str(error),
                "updated_at": utc_now(),
            }
        )
        save_state(state_path, state)
        raise

    state[state_key].update(
        {
            "stage": "published",
            "instagram_media_id": media_id,
            "posted_at": utc_now(),
            "updated_at": utc_now(),
        }
    )
    save_state(state_path, state)
    print(f"\nPosted to Instagram as media id {media_id}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PostingError as error:
        print(f"Error [{error.category}]: {error}", file=sys.stderr)
        raise SystemExit(1)
