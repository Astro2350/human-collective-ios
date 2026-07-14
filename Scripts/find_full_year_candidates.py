#!/usr/bin/env python3
import concurrent.futures
import json
import re
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date, timedelta
from pathlib import Path

TARGET_COUNT = 311
ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "Content" / "admin_seed_sample.json"
OUTPUT_PATH = ROOT / "Content" / "full_year_candidate_pool.json"

MET_SEARCH_URL = "https://collectionapi.metmuseum.org/public/collection/v1/search"
MET_OBJECT_URL = "https://collectionapi.metmuseum.org/public/collection/v1/objects"
CLEVELAND_URL = "https://openaccess-api.clevelandart.org/api/artworks/"
ARTIC_SEARCH_URL = "https://api.artic.edu/api/v1/artworks/search"
LOC_FILM_URL = "https://www.loc.gov/collections/national-screening-room/"

BROAD_QUERY_TERMS = [
    "painting", "sculpture", "architecture", "building", "automobile", "car",
    "carriage", "bicycle", "motorcycle", "watch", "timepiece", "furniture",
    "chair", "table", "cabinet", "fashion", "costume", "food", "bread", "recipe",
    "menu", "drink", "tea", "coffee", "wine", "musical instrument", "guitar",
    "piano", "drum", "flute", "violin", "invention", "machine", "engine", "tool", "hand tool", "camera",
    "typewriter", "film", "cinema", "movie poster", "sheet music", "music",
    "board game", "playing cards", "book", "monument", "memorial", "public square",
    "plaza", "park", "bridge", "aqueduct", "engineering",
]

QUERY_TERMS = BROAD_QUERY_TERMS + [
    "dog", "cat", "rabbit", "frog", "owl", "monkey", "fish", "turtle", "bird",
    "horse", "bull", "lion", "elephant", "deer", "dragon", "bear", "fox",
    "animal", "creature", "mask", "face", "portrait vessel", "head", "figurine",
    "figure", "puppet", "toy", "game", "chess", "dice", "netsuke", "miniature",
    "amulet", "jewelry", "ring", "bead", "comb", "mirror", "fan", "box",
    "vessel", "jar", "bowl", "cup", "rhyton", "lamp", "tile", "textile",
    "garment", "robe", "shoe", "book", "manuscript", "map", "globe",
    "astrolabe", "compass", "tool", "instrument", "spoon", "seal", "whistle",
    "doll", "samurai", "warrior", "guardian", "sphinx", "griffin", "kimono",
    "snuff bottle", "inro", "armor", "sword", "basket", "screen", "dress",
    "hat", "crown", "pin", "brooch", "teapot", "clock", "key"
]

SOURCE_LIMITS = {
    "The Metropolitan Museum of Art": 110,
    "Cleveland Museum of Art": 220,
    "Art Institute of Chicago": 220,
    "Library of Congress": 12,
}

COUNTRY_COORDS = {
    "egypt": (26.8206, 30.8025),
    "china": (35.8617, 104.1954),
    "japan": (36.2048, 138.2529),
    "india": (20.5937, 78.9629),
    "iran": (32.4279, 53.6880),
    "persia": (32.4279, 53.6880),
    "iraq": (33.2232, 43.6793),
    "mesopotamia": (33.2232, 43.6793),
    "syria": (34.8021, 38.9968),
    "turkey": (38.9637, 35.2433),
    "anatolia": (39.0000, 35.0000),
    "greece": (39.0742, 21.8243),
    "roman": (41.8719, 12.5674),
    "italy": (41.8719, 12.5674),
    "france": (46.2276, 2.2137),
    "england": (52.3555, -1.1743),
    "britain": (54.0000, -2.0000),
    "united kingdom": (54.0000, -2.0000),
    "ireland": (53.1424, -7.6921),
    "spain": (40.4637, -3.7492),
    "netherlands": (52.1326, 5.2913),
    "germany": (51.1657, 10.4515),
    "austria": (47.5162, 14.5501),
    "russia": (61.5240, 105.3188),
    "mexico": (23.6345, -102.5528),
    "peru": (-9.1900, -75.0152),
    "colombia": (4.5709, -74.2973),
    "guatemala": (15.7835, -90.2308),
    "united states": (37.0902, -95.7129),
    "canada": (56.1304, -106.3468),
    "korea": (35.9078, 127.7669),
    "thailand": (15.8700, 100.9925),
    "cambodia": (12.5657, 104.9910),
    "indonesia": (-0.7893, 113.9213),
    "vietnam": (14.0583, 108.2772),
    "nigeria": (9.0820, 8.6753),
    "mali": (17.5707, -3.9962),
    "ghana": (7.9465, -1.0232),
    "congo": (-4.0383, 21.7587),
    "benin": (9.3077, 2.3158),
    "ethiopia": (9.1450, 40.4897),
    "morocco": (31.7917, -7.0926)
}

STRONG_TERMS = {
    "painting", "sculpture", "architecture", "building", "automobile", "car",
    "carriage", "bicycle", "motorcycle", "watch", "timepiece", "furniture",
    "chair", "table", "cabinet", "fashion", "costume", "food", "bread", "recipe",
    "menu", "drink", "tea", "coffee", "wine", "guitar", "piano", "drum", "flute",
    "violin", "invention", "machine", "engine", "camera", "typewriter", "film",
    "cinema", "music", "card", "monument", "memorial", "square", "plaza", "park",
    "bridge", "aqueduct", "engineering",
    "dog", "cat", "rabbit", "frog", "owl", "monkey", "fish", "turtle", "bird",
    "horse", "bull", "lion", "elephant", "deer", "dragon", "bear", "fox",
    "animal", "mask", "face", "vessel", "jar", "bowl", "toy", "game",
    "netsuke", "miniature", "amulet", "ring", "jewelry", "map", "book",
    "manuscript", "astrolabe", "instrument", "guardian", "sphinx", "griffin",
    "kimono", "armor", "sword", "basket", "screen", "dress", "hat", "crown",
    "pin", "brooch", "teapot", "clock", "key"
}

EXPANDED_CATEGORY_MINIMUMS = {
    "painting": 3,
    "sculpture": 3,
    "architecture": 3,
    "car": 3,
    "watch": 3,
    "furniture": 3,
    "fashion": 3,
    "food": 3,
    "drink": 3,
    "instrument": 3,
    "invention": 3,
    "machine": 3,
    "tool": 3,
    "film": 3,
    "music": 3,
    "game": 3,
    "book": 3,
    "monument": 3,
    "public_space": 3,
    "engineering_feat": 3,
}

CATEGORY_LIMITS = {
    "painting": 42,
    "object": 70,
    "architecture": 24,
    "car": 18,
    "furniture": 24,
    "fashion": 24,
    "food": 18,
    "drink": 24,
    "instrument": 18,
    "music": 24,
    "monument": 18,
    "engineering_feat": 18,
}

WEAK_TITLE_PATTERNS = [
    r"^fragment$", r"^fragments?$", r"^untitled", r"^negative$", r"^button$",
    r"^sample$", r"^sherd$", r"^stud(y|ies)$", r"^print$"
]


def get_json(url, params=None, retries=3):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
    request = urllib.request.Request(url, headers={"User-Agent": "HumanCollectiveContentResearch/1.0"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            if attempt == retries - 1:
                return None
            time.sleep(0.4 * (attempt + 1))
    return None


def slugify(value):
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")[:64] or "object"


def clean(value):
    if value is None:
        return None
    if isinstance(value, list):
        value = ", ".join(str(item) for item in value if item)
    value = re.sub(r"\s+", " ", str(value)).strip()
    return value or None


def text_blob(*values):
    parts = []
    for value in values:
        if isinstance(value, list):
            parts.extend(str(item) for item in value if item)
        elif value:
            parts.append(str(value))
    return " ".join(parts).lower()


def is_weak_title(title):
    lowered = title.lower().strip()
    return any(re.search(pattern, lowered) for pattern in WEAK_TITLE_PATTERNS)


def has_term(text, term):
    suffix = "" if term.endswith("s") else "s?"
    pattern = rf"(?<![a-z0-9]){re.escape(term)}{suffix}(?![a-z0-9])"
    return re.search(pattern, text) is not None


def has_any_term(text, terms):
    return any(has_term(text, term) for term in terms)


def category_for(text):
    if has_any_term(text, ["automobile", "car", "motorcar", "carriage", "bicycle", "motorcycle"]):
        return "car"
    if has_any_term(text, ["watch", "timepiece", "wristwatch", "pocket watch"]):
        return "watch"
    if has_any_term(text, ["furniture", "chair", "table", "cabinet", "desk", "stool", "sofa"]):
        return "furniture"
    if has_any_term(text, ["fashion", "costume", "dress", "gown", "shoe", "hat", "handbag"]):
        return "fashion"
    if has_any_term(text, ["food", "bread", "meal", "recipe", "cuisine", "fruit", "cake"]):
        return "food"
    if has_any_term(text, ["drink", "beverage", "wine", "coffee", "tea", "beer", "cocktail"]):
        return "drink"
    if has_any_term(text, ["musical instrument", "guitar", "piano", "drum", "flute", "violin", "lute", "harp", "trumpet"]):
        return "instrument"
    if has_any_term(text, ["invention", "patent", "prototype"]):
        return "invention"
    if has_any_term(text, ["machine", "engine", "typewriter", "sewing machine", "printing press"]):
        return "machine"
    if has_any_term(text, ["film", "cinema", "motion picture", "movie"]):
        return "film"
    if has_any_term(text, ["sheet music", "musical score", "music"]):
        return "music"
    if has_any_term(text, ["game", "chess", "dice", "playing card", "board game"]):
        return "game"
    if has_any_term(text, ["manuscript", "page", "codex", "folio"]):
        return "manuscript"
    if has_any_term(text, ["book", "novel", "volume"]):
        return "book"
    if has_any_term(text, ["monument", "memorial", "obelisk", "mausoleum"]):
        return "monument"
    if has_any_term(text, ["public square", "plaza", "public park", "public garden"]):
        return "public_space"
    if has_any_term(text, ["engineering", "bridge", "aqueduct", "dam", "canal", "railway", "skyscraper"]):
        return "engineering_feat"
    if has_any_term(text, ["architecture", "building", "house", "palace", "temple", "cathedral"]):
        return "architecture"
    if has_any_term(text, ["mask", "helmet", "theater face"]):
        return "mask"
    if has_any_term(text, ["map", "globe", "atlas"]):
        return "map"
    if has_any_term(text, ["textile", "robe", "garment", "cloth", "tapestry", "carpet"]):
        return "textile"
    if has_any_term(text, ["painting", "watercolor", "canvas", "panel"]):
        return "painting"
    if has_any_term(text, ["ring", "necklace", "bracelet", "bead", "jewelry", "earring", "amulet", "brooch", "pin"]):
        return "jewelry"
    if has_any_term(text, ["vase", "vessel", "jar", "bowl", "cup", "rhyton", "ceramic", "pottery"]):
        return "pottery"
    if has_any_term(text, ["tool", "astrolabe", "compass", "knife", "spoon", "seal"]):
        return "tool"
    if has_any_term(text, ["poster", "print", "screenprint"]):
        return "poster"
    if has_any_term(text, ["sculpture", "statue", "figurine", "figure", "relief", "statuette", "head"]):
        return "sculpture"
    return "object"


def coords_for(*values):
    blob = text_blob(*values)
    for key, coords in COUNTRY_COORDS.items():
        if key in blob:
            return coords
    return (None, None)


def tags_for(text):
    tags = [term for term in sorted(STRONG_TERMS) if has_term(text, term)]
    return tags[:8]


def score_candidate(candidate):
    text = text_blob(
        candidate.get("title"),
        candidate.get("maker"),
        candidate.get("culture"),
        candidate.get("country"),
        candidate.get("region"),
        candidate.get("category"),
        candidate.get("source_type"),
        candidate.get("source_classification"),
        candidate.get("tags")
    )
    score = 0
    for term in STRONG_TERMS:
        if has_term(text, term):
            score += 5
    if candidate.get("latitude") is not None and candidate.get("longitude") is not None:
        score += 6
    if candidate.get("maker") and not candidate["maker"].lower().startswith("unknown"):
        score += 2
    if len(candidate.get("title", "")) <= 48:
        score += 2
    if candidate.get("category") in {"mask", "map", "jewelry", "pottery", "tool", "manuscript", "textile"}:
        score += 3
    if candidate.get("category") == "painting":
        score -= 4
    return score


def starter_copy(candidate):
    title = candidate["title"]
    culture = candidate.get("culture") or candidate.get("country") or "unknown origin"
    date_display = candidate.get("date_display") or "date unknown"
    category = candidate["category"]
    source_type = candidate.get("source_type") or category
    hook = f"A {source_type.lower()} from {culture} that earns a closer look."
    story = (
        f"Official metadata identifies this as {title}, dated {date_display}. "
        f"It is included as a candidate because the object has an open-access image, a traceable source page, "
        f"and a strong fit for Human Collective's daily archive of memorable human-made things."
    )
    why = (
        "It can help the archive show how culture lives in small details: material, place, use, image, "
        "and the human decision to make something worth keeping."
    )
    return hook, story, why


def make_candidate(raw):
    hook, story, why = starter_copy(raw)
    note = (
        f"Candidate selected from {raw['source_name']} open-access metadata. "
        "Verify image, place/date, and rewrite final editorial copy before publishing."
    )
    item = {
        "id": raw["id"],
        "content_source_id": raw["content_source_id"],
        "source_object_id": raw["source_object_id"],
        "title": raw["title"],
        "maker": raw.get("maker"),
        "culture": raw.get("culture"),
        "country": raw.get("country"),
        "region": raw.get("region"),
        "date_display": raw.get("date_display") or "Date unknown",
        "category": raw["category"],
        "image_url": raw["image_url"],
        "source_name": raw["source_name"],
        "source_url": raw["source_url"],
        "license": raw["license"],
        "hook": hook,
        "story": story,
        "why_it_matters": why,
        "latitude": raw.get("latitude"),
        "longitude": raw.get("longitude"),
        "primary_week_key": None,
        "tags": raw.get("tags", []),
        "curator_note": note,
        "editorial_status": "source-verified candidate",
        "selection_score": raw["selection_score"]
    }
    return item


def load_existing():
    seed = json.loads(SEED_PATH.read_text())
    existing_ids = {item["id"] for item in seed.get("curated_items", [])}
    existing_sources = {
        (item.get("source_name"), str(item.get("source_object_id")))
        for item in seed.get("curated_items", [])
        if item.get("source_name") and item.get("source_object_id")
    }
    return existing_ids, existing_sources


def met_search_ids():
    ids = []
    seen = set()
    for term in QUERY_TERMS:
        data = get_json(MET_SEARCH_URL, {
            "hasImages": "true",
            "isPublicDomain": "true",
            "q": term
        })
        for object_id in (data or {}).get("objectIDs") or []:
            if object_id not in seen:
                seen.add(object_id)
                ids.append(object_id)
            if len(ids) >= 1400:
                return ids
    return ids


def met_detail(object_id):
    data = get_json(f"{MET_OBJECT_URL}/{object_id}")
    if not data or not data.get("isPublicDomain"):
        return None
    title = clean(data.get("title"))
    image_url = clean(data.get("primaryImageSmall") or data.get("primaryImage"))
    source_url = clean(data.get("objectURL"))
    if not title or not image_url or not source_url or is_weak_title(title):
        return None
    source_type = clean(data.get("objectName") or data.get("classification") or data.get("department"))
    culture = clean(data.get("culture") or data.get("period") or data.get("dynasty"))
    country = clean(data.get("country"))
    region = clean(data.get("region") or data.get("city"))
    tag_terms = [tag.get("term") for tag in data.get("tags") or [] if isinstance(tag, dict)]
    blob = text_blob(title, source_type, data.get("classification"), data.get("department"), culture, country, region, tag_terms)
    if not has_any_term(blob, STRONG_TERMS):
        return None
    latitude, longitude = coords_for(culture, country, region, data.get("geographyType"))
    raw = {
        "id": f"met-{slugify(title)}-{object_id}",
        "content_source_id": "met-open",
        "source_object_id": str(object_id),
        "title": title,
        "maker": clean(data.get("artistDisplayName")) or (f"Unknown {culture} creator" if culture else "Creator unknown"),
        "culture": culture,
        "country": country,
        "region": region,
        "date_display": clean(data.get("objectDate")),
        "category": category_for(blob),
        "image_url": image_url,
        "source_name": "The Metropolitan Museum of Art",
        "source_url": source_url,
        "license": "Public domain / Met Open Access",
        "latitude": latitude,
        "longitude": longitude,
        "tags": tags_for(blob),
        "source_type": source_type,
        "source_classification": clean(data.get("classification") or data.get("department"))
    }
    raw["selection_score"] = score_candidate(raw)
    return raw


def cleveland_search_items():
    records = []
    seen = set()
    for index, term in enumerate(QUERY_TERMS):
        data = get_json(CLEVELAND_URL, {
            "q": term,
            "has_image": "1",
            "cc0": "1",
            "limit": "100"
        })
        for record in (data or {}).get("data") or []:
            object_id = str(record.get("id") or record.get("accession_number") or "")
            if object_id and object_id not in seen:
                seen.add(object_id)
                records.append(record)
            if index >= len(BROAD_QUERY_TERMS) - 1 and len(records) >= 1800:
                return records
    return records


def cleveland_candidate(record):
    title = clean(record.get("title"))
    image_url = clean((((record.get("images") or {}).get("web") or {}).get("url")))
    source_url = clean(record.get("url"))
    object_id = str(record.get("id") or record.get("accession_number") or "")
    if not title or not image_url or not source_url or not object_id or is_weak_title(title):
        return None
    creators = record.get("creators") or []
    maker = None
    if creators and isinstance(creators[0], dict):
        maker = clean(creators[0].get("description") or creators[0].get("name"))
    culture = clean(record.get("culture"))
    country = clean(record.get("country"))
    region = clean(record.get("tombstone") or record.get("department"))
    source_type = clean(record.get("type") or record.get("collection") or record.get("department"))
    blob = text_blob(title, source_type, culture, country, region, record.get("technique"), record.get("tags"))
    if not has_any_term(blob, STRONG_TERMS):
        return None
    latitude, longitude = coords_for(culture, country, region)
    raw = {
        "id": f"cma-{slugify(title)}-{object_id}",
        "content_source_id": "cleveland-open-access",
        "source_object_id": object_id,
        "title": title,
        "maker": maker or (f"Unknown {culture} creator" if culture else "Creator unknown"),
        "culture": culture,
        "country": country,
        "region": region,
        "date_display": clean(record.get("creation_date")),
        "category": category_for(blob),
        "image_url": image_url,
        "source_name": "Cleveland Museum of Art",
        "source_url": source_url,
        "license": "CC0 / Cleveland Museum of Art Open Access",
        "latitude": latitude,
        "longitude": longitude,
        "tags": tags_for(blob),
        "source_type": source_type,
        "source_classification": clean(record.get("collection") or record.get("department"))
    }
    raw["selection_score"] = score_candidate(raw)
    return raw


def artic_search_items():
    records = []
    seen = set()
    fields = ",".join([
        "id",
        "title",
        "artist_display",
        "date_display",
        "place_of_origin",
        "image_id",
        "classification_titles",
        "subject_titles",
        "api_link",
        "web_url"
    ])
    for index, term in enumerate(QUERY_TERMS):
        data = get_json(ARTIC_SEARCH_URL, {
            "q": term,
            "query[term][is_public_domain]": "true",
            "fields": fields,
            "limit": "100"
        })
        for record in (data or {}).get("data") or []:
            object_id = str(record.get("id") or "")
            if object_id and object_id not in seen:
                seen.add(object_id)
                records.append(record)
            if index >= len(BROAD_QUERY_TERMS) - 1 and len(records) >= 1800:
                return records
    return records


def artic_candidate(record):
    title = clean(record.get("title"))
    image_id = clean(record.get("image_id"))
    object_id = str(record.get("id") or "")
    if not title or not image_id or not object_id or is_weak_title(title):
        return None
    classification = clean(record.get("classification_titles"))
    subjects = clean(record.get("subject_titles"))
    place = clean(record.get("place_of_origin"))
    blob = text_blob(title, classification, subjects, place, record.get("artist_display"))
    if not has_any_term(blob, STRONG_TERMS):
        return None
    latitude, longitude = coords_for(place, record.get("artist_display"))
    raw = {
        "id": f"artic-{slugify(title)}-{object_id}",
        "content_source_id": "artic-public-domain",
        "source_object_id": object_id,
        "title": title,
        "maker": clean(record.get("artist_display")) or (f"Unknown {place} creator" if place else "Creator unknown"),
        "culture": place,
        "country": place,
        "region": None,
        "date_display": clean(record.get("date_display")),
        "category": category_for(blob),
        "image_url": f"https://www.artic.edu/iiif/2/{image_id}/full/843,/0/default.jpg",
        "source_name": "Art Institute of Chicago",
        "source_url": clean(record.get("web_url")) or f"https://www.artic.edu/artworks/{object_id}",
        "license": "Public domain / Art Institute of Chicago",
        "latitude": latitude,
        "longitude": longitude,
        "tags": tags_for(blob),
        "source_type": classification,
        "source_classification": subjects
    }
    raw["selection_score"] = score_candidate(raw)
    return raw


def loc_film_items():
    data = get_json(LOC_FILM_URL, {
        "fo": "json",
        "c": "100",
        "dates": "1900-1929",
        "fa": "location:united states",
    })
    return (data or {}).get("results") or []


def loc_film_candidate(record):
    title = clean(record.get("title"))
    source_url = clean(record.get("url"))
    source_id = (clean(record.get("id")) or "").rstrip("/").rsplit("/", 1)[-1]
    image_urls = record.get("image_url") or []
    image_url = clean(image_urls[0] if image_urls else None)
    year_match = re.search(r"\b(18|19|20)\d{2}\b", clean(record.get("date")) or "")
    year = int(year_match.group(0)) if year_match else None

    if not title or not source_url or not source_id or not image_url or not year or year > 1929 or is_weak_title(title):
        return None

    if image_url.endswith(".gif"):
        image_url = image_url[:-4] + ".jpg"

    contributors = record.get("contributor") or []
    locations = record.get("location") or []
    maker = clean(contributors[0] if contributors else None) or "Creator unknown"
    region = clean(", ".join(locations[1:3])) if len(locations) > 1 else None
    raw = {
        "id": f"loc-film-{slugify(title)}-{source_id}",
        "content_source_id": "loc-national-screening-room",
        "source_object_id": source_id,
        "title": title,
        "maker": maker,
        "culture": "American film",
        "country": "United States",
        "region": region,
        "date_display": str(year),
        "category": "film",
        "image_url": image_url,
        "source_name": "Library of Congress",
        "source_url": source_url,
        "license": "Public domain (published 1929 or earlier) / Library of Congress",
        "latitude": COUNTRY_COORDS["united states"][0],
        "longitude": COUNTRY_COORDS["united states"][1],
        "tags": ["film"],
        "source_type": "Film",
        "source_classification": "National Screening Room",
    }
    raw["selection_score"] = score_candidate(raw)
    return raw


def week_keys(start="2026-W30", count=60):
    year, week = start.split("-W")
    cursor = date.fromisocalendar(int(year), int(week), 1)
    keys = []
    for _ in range(count):
        iso = cursor.isocalendar()
        keys.append(f"{iso.year}-W{iso.week:02d}")
        cursor += timedelta(days=7)
    return keys


def build_candidate_packs(items):
    themes = [
        ("Pocket Creatures", "Small animals and charming companions from across the archive."),
        ("Faces With Presence", "Masks, heads, portraits, and figures that meet the viewer directly."),
        ("Hands and Tools", "Objects made for measuring, making, carrying, playing, and daily use."),
        ("Bright Vessels", "Jars, cups, bowls, and animal-shaped containers with strong visual character."),
        ("Maps and Knowledge", "Pages, maps, diagrams, books, and instruments for reading the world."),
        ("Jewelry and Amulets", "Tiny precious objects made to be worn, kept close, or carried."),
        ("Guardians and Beasts", "Protective figures, mythical animals, and creatures with attitude.")
    ]
    keys = week_keys(count=(len(items) + 6) // 7)
    packs = []
    for index, start in enumerate(range(0, len(items), 7)):
        group = items[start:start + 7]
        theme = themes[index % len(themes)]
        packs.append({
            "id": f"candidate-pack-{keys[index]}",
            "week_key": keys[index],
            "title": theme[0],
            "subtitle": theme[1],
            "item_ids": [item["id"] for item in group],
            "curator_note": "Generated candidate pack order. Review theme balance before publishing."
        })
    return packs


def main():
    existing_ids, existing_sources = load_existing()
    candidates = []
    seen_ids = set(existing_ids)
    seen_sources = set(existing_sources)

    def add_candidate(raw):
        if not raw:
            return
        source_key = (raw["source_name"], raw["source_object_id"])
        if raw["id"] in seen_ids or source_key in seen_sources:
            return
        seen_ids.add(raw["id"])
        seen_sources.add(source_key)
        candidates.append(raw)

    for record in loc_film_items():
        add_candidate(loc_film_candidate(record))

    for record in cleveland_search_items():
        add_candidate(cleveland_candidate(record))

    for record in artic_search_items():
        add_candidate(artic_candidate(record))

    if len(candidates) < TARGET_COUNT:
        met_ids = met_search_ids()
        with concurrent.futures.ThreadPoolExecutor(max_workers=18) as executor:
            for raw in executor.map(met_detail, met_ids):
                add_candidate(raw)

    candidates.sort(key=lambda item: (item["selection_score"], item["source_name"], item["title"]), reverse=True)

    selected = []
    selected_ids = set()
    source_counts = Counter()
    category_counts = Counter()

    def select(raw):
        source_name = raw["source_name"]
        if raw["id"] in selected_ids or source_counts[source_name] >= SOURCE_LIMITS[source_name]:
            return False
        category_limit = CATEGORY_LIMITS.get(raw["category"])
        if category_limit is not None and category_counts[raw["category"]] >= category_limit:
            return False
        selected.append(make_candidate(raw))
        selected_ids.add(raw["id"])
        source_counts[source_name] += 1
        category_counts[raw["category"]] += 1
        return True

    for category, minimum in EXPANDED_CATEGORY_MINIMUMS.items():
        for raw in candidates:
            if raw["category"] != category:
                continue
            select(raw)
            if category_counts[category] >= minimum or len(selected) == TARGET_COUNT:
                break

    for raw in candidates:
        select(raw)
        if len(selected) == TARGET_COUNT:
            break

    if len(selected) < TARGET_COUNT:
        raise SystemExit(f"Only found {len(selected)} candidates; widen query terms or source limits.")

    output = {
        "schema_version": "1.0",
        "generated_at": date.today().isoformat(),
        "target_count": TARGET_COUNT,
        "source_summary": dict(source_counts),
        "category_summary": dict(category_counts),
        "candidate_content_sources": [
            {
                "id": "loc-national-screening-room",
                "name": "Library of Congress",
                "type": "archive",
                "base_url": "https://www.loc.gov/collections/national-screening-room/",
                "api_url": "https://www.loc.gov/collections/national-screening-room/?fo=json",
                "rights_summary": "U.S. films published in 1929 or earlier, with source records and still images.",
                "preferred_credit_line": "Public domain / Library of Congress"
            },
            {
                "id": "artic-public-domain",
                "name": "Art Institute of Chicago",
                "type": "museum",
                "base_url": "https://www.artic.edu/",
                "api_url": "https://api.artic.edu/api/v1/artworks/search",
                "rights_summary": "Public-domain artwork records with IIIF image delivery.",
                "preferred_credit_line": "Public domain / Art Institute of Chicago"
            },
            {
                "id": "cleveland-open-access",
                "name": "Cleveland Museum of Art",
                "type": "museum",
                "base_url": "https://www.clevelandart.org/",
                "api_url": "https://openaccess-api.clevelandart.org/api/artworks/",
                "rights_summary": "CC0 open-access artwork metadata and images.",
                "preferred_credit_line": "CC0 / Cleveland Museum of Art Open Access"
            }
        ],
        "notes": [
            "These are source-verified candidates, not final published daily copy.",
            "Each item has an official source URL and open-access image metadata from the source API.",
            "Selection makes a best-effort pass across the expanded human-made categories before filling by score.",
            "Review rights, image quality, coordinates, date parsing, and rewrite final app copy before Supabase import."
        ],
        "candidate_curated_items": selected,
        "candidate_weekly_packs": build_candidate_packs(selected)
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, ensure_ascii=True) + "\n")
    print(json.dumps({
        "written": str(OUTPUT_PATH.relative_to(ROOT)),
        "items": len(selected),
        "sources": dict(source_counts),
        "categories": dict(category_counts),
        "packs": len(output["candidate_weekly_packs"])
    }, indent=2))


if __name__ == "__main__":
    main()
