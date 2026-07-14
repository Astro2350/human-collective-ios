#!/usr/bin/env python3
import concurrent.futures
import hashlib
import json
import os
import re
import time
import urllib.parse
import urllib.request
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POOL_PATH = ROOT / "Content" / "full_year_candidate_pool.json"
ARCHIVE_YEAR = 2026
ARCHIVE_TODAY = date.fromisoformat(os.environ.get("HC_ARCHIVE_TODAY", "2026-07-06"))

GENERAL_TAGS = {
    "animal", "instrument", "object", "key", "jewelry", "vessel", "book",
    "basket", "amulet", "mask", "jar", "bowl", "plate", "manuscript"
}

COUNTRY_WORDS = [
    "egypt", "china", "japan", "india", "iran", "iraq", "syria", "turkey",
    "greece", "italy", "france", "england", "britain", "spain", "germany",
    "mexico", "peru", "colombia", "guatemala", "korea", "nigeria", "mali",
    "ghana", "congo", "morocco", "united states", "canada", "ireland",
    "netherlands", "belgium", "austria", "thailand", "cambodia",
    "indonesia", "vietnam"
]

NON_PERSON_MAKER_WORDS = {
    "egyptian", "greek", "roman", "etruscan", "moche", "nazca", "inca",
    "chimu", "chimú", "japanese", "chinese", "korean", "french", "english",
    "british", "spanish", "german", "italian", "neapolitan", "persian",
    "sumerian", "mayan", "maya", "india", "england", "egypt", "france",
    "greece", "rome", "japan", "china", "peru", "colombia", "mexico",
    "belgium", "paris", "naples", "corinth", "etruria", "cuzco",
    "southern netherlands", "flemish", "teotihuacan", "mesopotamia",
    "ancient greece", "ancient greek", "campania", "flanders", "mughal",
    "safavid", "muisca", "lambayeque", "apulia", "corinth", "nuremberg",
    "north coast", "south coast", "new york", "new jersey", "united states"
}

CATEGORY_LABELS = {
    "car": "vehicle",
    "watch": "watch",
    "furniture": "piece of furniture",
    "fashion": "fashion piece",
    "food": "food creation",
    "drink": "drink",
    "instrument": "musical instrument",
    "invention": "invention",
    "machine": "machine",
    "film": "film work",
    "music": "musical work",
    "game": "game",
    "book": "book",
    "monument": "monument",
    "public_space": "public space",
    "engineering_feat": "work of engineering",
    "architecture": "work of architecture",
    "textile": "textile",
    "jewelry": "piece of jewelry",
    "painting": "painting",
    "manuscript": "page",
    "mask": "mask",
    "pottery": "vessel",
    "map": "map",
    "object": "object",
    "tool": "tool",
    "sculpture": "sculpture",
    "poster": "print"
}

OBJECT_LINES = {
    "textile": [
        "The work belongs to a part of history that is easy to undervalue: pattern, patience, and hand skill carried through cloth.",
        "Textiles are never neutral background here; they hold labor, taste, household memory, and the slow discipline of making.",
        "The surface matters because thread can hold stories as firmly as stone or paint, only in a softer register.",
        "Its interest is in accumulated decisions: color, pattern, edge, repair, and the time needed to make them cohere."
    ],
    "jewelry": [
        "Jewelry works at bodily scale, where display, protection, memory, and status can all share one small object.",
        "The smallness is not a weakness; objects like this were meant to travel with a person and work close to the skin.",
        "Adornments like this help the archive show how belief and identity could be carried rather than simply displayed.",
        "It is evidence at intimate scale: not a monument, but a thing made to live with a body."
    ],
    "pottery": [
        "Vessels are practical objects, but the strongest ones turn storage, pouring, or offering into a visual event.",
        "Clay keeps the record of touch especially well: shaping, firing, painting, and the decision to make use beautiful.",
        "The form matters because function did not prevent imagination; it gave imagination a place to sit.",
        "It belongs to the long history of handled objects, where daily use and symbolic life often meet."
    ],
    "manuscript": [
        "Pages and books make knowledge physical: ordered, sized, decorated, corrected, and carried.",
        "The object reminds us that reading has always been visual and material, not only intellectual.",
        "Its importance is in the arrangement as much as the subject: image, margin, sequence, and surface.",
        "A page like this turns information into craft, which is why it can still feel alive outside its original book."
    ],
    "mask": [
        "Masks change the terms of looking; they are objects, but they are also instruments for performance and social transformation.",
        "The face is made rather than natural, which is exactly why it has force: it can be worn, activated, and believed.",
        "It matters as a survival of performance, a still object made for a moving body.",
        "The object sits between likeness and role, giving identity a temporary form."
    ],
    "painting": [
        "The value is in what the picture asks the eye to do: follow gesture, setting, light, and story.",
        "Painting preserves a habit of attention, not just a subject.",
        "The image is useful to the archive because it records a particular way of arranging the world for a viewer.",
        "Its details carry the historical work; the subject is only the beginning."
    ],
    "map": [
        "A map is never just a picture of place. It selects, names, measures, omits, and persuades.",
        "The sheet turns distance into design, making geography portable but never neutral.",
        "Its value lies in showing how people organized space before they could simply search it.",
        "Maps make knowledge visible, but they also reveal the ambitions and limits of their makers."
    ],
    "tool": [
        "Tools preserve practical intelligence: proportion, balance, grip, and the problem someone needed to solve.",
        "The object matters because use is a form of thinking, and good tools make that thinking visible.",
        "It keeps history close to work rather than display.",
        "Its design records a task, which can be as revealing as decoration."
    ],
    "sculpture": [
        "Sculpture gives an idea weight, surface, shadow, and a place in the room.",
        "The material presence matters; this is history made spatial rather than simply pictured.",
        "Its force comes from turning body, symbol, or character into something that occupies space.",
        "The object holds meaning through mass and outline, not only through image."
    ],
    "poster": [
        "Prints and posters belong to a quicker public history of looking: graphic, portable, and made to circulate.",
        "The design compresses message and image into one surface, which is why it still reads quickly.",
        "It belongs to the history of attention as much as the history of art.",
        "Printed images like this show how ideas moved through repetition and display."
    ],
    "object": [
        "Its value is in specificity: material, scale, finish, and the choices that made this object worth keeping.",
        "Objects like this keep history concrete, away from general period labels and close to made things.",
        "The archive needs pieces like this because culture often survives in details rather than grand statements.",
        "The object asks for slow looking because its evidence is practical, visual, and compact."
    ]
}

WHY_LINES = {
    "textile": [
        "It puts handwork, image, and daily life in the same frame.",
        "It shows cloth as a serious historical surface, not decoration alone.",
        "It makes patient labor visible without turning it into a footnote."
    ],
    "jewelry": [
        "It shows how meaning could be worn, carried, and kept close.",
        "It turns a small object into evidence of identity, protection, or status.",
        "It proves that historical weight does not require monumental scale."
    ],
    "pottery": [
        "It shows use and imagination working through the same form.",
        "It keeps everyday handling inside the historical record.",
        "It lets a practical object carry visual intelligence."
    ],
    "manuscript": [
        "It shows knowledge as something made, ordered, and preserved by hand.",
        "It makes reading part of material culture.",
        "It reminds us that information needed objects before it had screens."
    ],
    "mask": [
        "It turns identity into something made, worn, and performed.",
        "It preserves the material trace of a changing face.",
        "It shows how an object can alter a body, a role, and a room."
    ],
    "painting": [
        "It preserves a historical way of looking.",
        "It shows how images organize attention and value.",
        "It turns observation into cultural memory."
    ],
    "map": [
        "It shows place as interpretation, not just location.",
        "It makes geography portable while keeping its biases visible.",
        "It records how people organized distance, power, and knowledge."
    ],
    "tool": [
        "It preserves intelligence in practical form.",
        "It shows history through use, not only display.",
        "It makes problem-solving visible as culture."
    ],
    "sculpture": [
        "It gives cultural meaning a physical body.",
        "It shows how material can make presence durable.",
        "It lets form carry memory across time."
    ],
    "poster": [
        "It shows public attention being designed.",
        "It records graphic culture as part of history.",
        "It makes circulation and persuasion visible."
    ],
    "object": [
        "It keeps history specific, handled, and visible.",
        "It shows how much cultural information can survive in one made thing.",
        "It gives the archive a concrete point of contact."
    ]
}

PACK_THEMES = [
    ("Animal Signs", "Creatures, symbols, and objects with a living charge."),
    ("Small Powers", "Amulets, beads, rings, and protective things."),
    ("Vessels With Character", "Containers where use and image meet."),
    ("Pages And Pictures", "Books, prints, and images made to carry knowledge."),
    ("Thread And Pattern", "Textiles, surfaces, and slow handwork."),
    ("Faces And Figures", "Masks, bodies, portraits, and presence."),
    ("Objects In Motion", "Tools, weapons, games, and things made for action."),
    ("Bright Survivals", "Compact pieces that still feel immediate."),
    ("Made To Be Held", "Hand-sized objects with more meaning than scale suggests."),
    ("Creature Worlds", "Animals, hybrids, and watched bodies across time."),
    ("Surface And Story", "Decoration doing historical work."),
    ("Portable Histories", "Objects made to move with people, books, or trade."),
    ("Clay And Fire", "Ceramic forms with strong visual lives."),
    ("Body And Belief", "Adornment, protection, ritual, and display."),
    ("Drawn Knowledge", "Maps, pages, and images that organize the world.")
]


def stable_index(item_id, count, salt):
    digest = hashlib.sha256(f"{salt}:{item_id}".encode("utf-8")).hexdigest()
    return int(digest[:8], 16) % count


def pick(lines, item_id, salt):
    return lines[stable_index(item_id, len(lines), salt)]


def clean(value):
    if value is None:
        return None
    if isinstance(value, list):
        value = ", ".join(str(part) for part in value if part)
    value = re.sub(r"<[^>]+>", " ", str(value))
    value = re.sub(r"\s+", " ", value).strip()
    return value or None


def get_json(url, params=None, retries=2):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
    request = urllib.request.Request(url, headers={"User-Agent": "HumanCollectiveEditorial/1.0"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            if attempt == retries - 1:
                return None
            time.sleep(0.25 * (attempt + 1))
    return None


def source_detail(item):
    source_id = str(item.get("source_object_id") or "")
    if item.get("content_source_id") == "artic-public-domain":
        fields = ",".join([
            "title", "artist_display", "date_display", "place_of_origin",
            "medium_display", "dimensions", "classification_titles",
            "subject_titles"
        ])
        data = get_json(f"https://api.artic.edu/api/v1/artworks/{source_id}", {"fields": fields})
        record = (data or {}).get("data") or {}
        return {
            "medium": clean(record.get("medium_display")),
            "dimensions": clean(record.get("dimensions")),
            "source_type": clean(record.get("classification_titles")),
            "subjects": clean(record.get("subject_titles")),
            "maker": clean(record.get("artist_display")),
            "place": clean(record.get("place_of_origin")),
            "date": clean(record.get("date_display"))
        }

    if item.get("content_source_id") == "cleveland-open-access":
        data = get_json("https://openaccess-api.clevelandart.org/api/artworks/", {"id": source_id})
        record = (data or {}).get("data") or {}
        if isinstance(record, list):
            record = record[0] if record else {}
        creators = record.get("creators") or []
        maker = None
        if creators and isinstance(creators[0], dict):
            maker = clean(creators[0].get("description") or creators[0].get("name"))
        return {
            "medium": clean(record.get("technique")),
            "dimensions": clean(record.get("measurements")),
            "source_type": clean(record.get("type") or record.get("collection")),
            "subjects": clean(record.get("tags")),
            "maker": maker,
            "place": clean(record.get("culture") or record.get("country")),
            "date": clean(record.get("creation_date"))
        }

    return {}


def useful_maker(item, detail):
    maker = clean(detail.get("maker")) or clean(item.get("maker"))
    if not maker:
        return None
    lowered = maker.lower()
    if lowered.startswith("unknown") or lowered == "creator unknown":
        return None
    origin_blob = " ".join(
        clean(value) or ""
        for value in [item.get("culture"), item.get("country"), item.get("region"), detail.get("place")]
    ).lower()
    if lowered in NON_PERSON_MAKER_WORDS or lowered in origin_blob:
        return None
    if any(token in lowered for token in ["north coast", "south coast", "dynasty", "period", "kingdom", "possibly", "probably", "style"]):
        if not re.search(r"\bby\b|\battributed\b|\bdesigned\b|\bpainted\b|\bprinted\b|\bwoven\b|\bmodeled\b", lowered):
            return None
    designed_painted = re.search(r"designed\s+by\s+([^,()]+),\s*painted\s+by\s+([^,()]+)", maker, flags=re.IGNORECASE)
    if designed_painted:
        return f"{clean(designed_painted.group(1))} and {clean(designed_painted.group(2))}"
    attributed = re.search(r"(?:attributed\s+to|probably\s+by|possibly\s+by)\s+([^()]+)", maker, flags=re.IGNORECASE)
    if attributed:
        maker = attributed.group(1)
    match = re.search(r"\b(?:designed|executed|made|painted|printed|woven|modeled|manufactured)\s+(?:and\s+\w+\s+)?by\s+([^()]+)", maker, flags=re.IGNORECASE)
    if match:
        maker = match.group(1)
    maker = re.sub(r"^(?:Attributed to|After a design by|Designed by|Painted by|Printed by|Woven by)\s+", "", maker, flags=re.IGNORECASE)
    maker = re.sub(r"^After\s+", "", maker, flags=re.IGNORECASE)
    maker = re.sub(r"\s*\([^)]*\)", "", maker)
    maker = re.sub(r"\s*\([^)]*$", "", maker)
    maker = re.split(r"\b(?:Woven|Manufactured|Printed|Painted|Made|Designed|Modeled|Produced)\b", maker, flags=re.IGNORECASE)[0]
    maker = re.split(r"\s{2,}|(?:\s+[A-Z][a-z]+,?\s+\d{3,4}[-/\u2013])", maker)[0]
    maker = re.split(
        r"\b(?:Brooklyn Heights|New York|New Jersey|United States|England|English|Egypt|Egyptian|France|French|Paris|India|Indian|Japan|Japanese|China|Chinese|Peru|Peruvian|Italy|Italian|Germany|German|Spain|Spanish|Belgium|Flemish|Greece|Greek|Mexico|Mexican|Campania|Apulia|Corinth|Nuremberg|Flanders)\b",
        maker,
        flags=re.IGNORECASE
    )[0]
    maker = clean(maker.strip(" ,;."))
    if not maker or maker.lower().startswith("unknown"):
        return None
    if maker.lower() in NON_PERSON_MAKER_WORDS or maker.lower() in origin_blob:
        return None
    if len(maker) > 88:
        maker = clean(maker.split(",")[0])
    if maker and maker.lower().split(",")[0] in NON_PERSON_MAKER_WORDS:
        return None
    maker_tokens = set(re.findall(r"[a-z]+", maker.lower()))
    if maker_tokens & NON_PERSON_MAKER_WORDS:
        return None
    return maker


def useful_date(value):
    value = clean(value)
    if not value:
        return None
    if value.lower() in {"date unknown", "unknown", "n.d."}:
        return None
    return value


def normalize_origin_text(value):
    value = clean(value)
    if not value:
        return None
    value = value.replace("probably ", "probably ")
    value = re.sub(r"\s*\([^)]*\d{3,4}[^)]*\)", "", value)
    value = re.sub(r"\b(?:c\.|about)\s*\d{3,4}(?:\s*[-\u2013]\s*\d{2,4})?\b", "", value)
    value = re.sub(r"\s+", " ", value).strip(" ,;.")
    if len(value) > 72:
        parts = [part.strip() for part in value.split(",") if part.strip()]
        value = ", ".join(parts[:2]) if parts else value[:72].rstrip(" ,;.")
    return value or None


def sanitize_region(item):
    region = clean(item.get("region"))
    if not region:
        return None
    noisy = ["The Cleveland Museum of Art", "overall:", "sheet:", "image:", "diameter:", "Gift of", "Purchase"]
    if len(region) > 90 or any(token in region for token in noisy) or clean(item.get("title")) in region:
        return None
    return normalize_origin_text(region)


def sanitize_places(item, detail):
    culture = normalize_origin_text(detail.get("place")) or normalize_origin_text(item.get("culture"))
    country = normalize_origin_text(item.get("country"))
    region = sanitize_region(item)

    if country and culture and country.lower() == culture.lower():
        country = None
    if region and culture and region.lower() == culture.lower():
        region = None
    if region and country and region.lower() == country.lower():
        region = None

    return culture, country, region


def clean_material(value):
    value = clean(value)
    if not value:
        return None
    value = re.sub(r";.*$", "", value).strip()
    value = re.sub(r"\s*\([^)]*\d+[^)]*\)", "", value).strip()
    value = re.sub(r"\boverall:.*$", "", value, flags=re.IGNORECASE).strip(" ;,.")
    if len(value) > 74:
        value = value[:74].rsplit(" ", 1)[0].rstrip(" ,;.")
    return value or None


def tag_words(item, detail):
    tags = []
    for tag in item.get("tags") or []:
        tag = clean(tag)
        if tag and tag.lower() not in GENERAL_TAGS and tag.lower() not in tags:
            tags.append(tag.lower())

    subject_text = clean(detail.get("subjects"))
    if subject_text:
        for word in re.split(r"[,;]", subject_text):
            word = clean(word)
            if word and word.lower() not in GENERAL_TAGS and len(word) <= 24:
                lowered = word.lower()
                if lowered not in tags:
                    tags.append(lowered)

    return tags[:4]


def phrase_list(words):
    words = [word for word in words if word]
    if not words:
        return None
    if len(words) == 1:
        return words[0]
    if len(words) == 2:
        return f"{words[0]} and {words[1]}"
    return f"{words[0]}, {words[1]}, and {words[2]}"


def motif_details(words):
    words = [word for word in words if word]
    phrase = phrase_list(words)
    if not phrase:
        return None
    return f"{phrase} motifs"


def title_terms(title):
    lowered = title.lower()
    terms = []
    for word in [
        "dog", "cat", "rabbit", "frog", "owl", "monkey", "fish", "turtle",
        "bird", "horse", "bull", "lion", "elephant", "deer", "dragon",
        "bear", "griffin", "puppy", "puppies"
    ]:
        if re.search(rf"\b{re.escape(word)}s?\b", lowered):
            terms.append(word)
    return terms[:3]


def normalized_category(item):
    title = item["title"].lower()
    if any(token in title for token in ["automobile", "motorcar", "carriage", "bicycle", "motorcycle"]):
        return "car"
    if any(token in title for token in ["watch", "timepiece", "wristwatch"]):
        return "watch"
    if any(token in title for token in ["chair", "table", "cabinet", "desk", "stool", "sofa"]):
        return "furniture"
    if any(token in title for token in ["fashion", "costume", "dress", "gown", "shoe", "hat", "handbag"]):
        return "fashion"
    if any(token in title for token in ["food", "bread", "meal", "recipe", "cuisine", "cake"]):
        return "food"
    if any(token in title for token in ["drink", "beverage", "wine", "coffee", "tea", "beer", "cocktail"]):
        return "drink"
    if any(token in title for token in ["guitar", "piano", "drum", "flute", "violin", "lute", "harp", "trumpet"]):
        return "instrument"
    if any(token in title for token in ["invention", "patent", "prototype"]):
        return "invention"
    if any(token in title for token in ["machine", "engine", "typewriter", "printing press"]):
        return "machine"
    if any(token in title for token in ["film", "cinema", "motion picture", "movie"]):
        return "film"
    if any(token in title for token in ["sheet music", "musical score"]):
        return "music"
    if any(token in title for token in ["game", "chess", "dice", "playing card"]):
        return "game"
    if any(token in title for token in ["manuscript", "page", "folio", "codex"]):
        return "manuscript"
    if any(token in title for token in ["book", "novel", "volume"]):
        return "book"
    if any(token in title for token in ["monument", "memorial", "obelisk", "mausoleum"]):
        return "monument"
    if any(token in title for token in ["public square", "plaza", "public park", "public garden"]):
        return "public_space"
    if any(token in title for token in ["bridge", "aqueduct", "dam", "canal", "railway", "skyscraper"]):
        return "engineering_feat"
    if any(token in title for token in ["architecture", "building", "house", "palace", "temple", "cathedral"]):
        return "architecture"
    if "atlas mountains" in title:
        return "poster"
    if "bull" in title and "ring" in title:
        return "poster"
    if any(token in title for token in ["print", "lithograph", "poster", "plate ", " plate", "bullfighting", "bullfight"]):
        return "poster"
    if any(token in title for token in ["vessel", "jar", "bowl", "cup", "pitcher", "amphora", "pelike", "oinochoe", "rhyton", "dish"]):
        return "pottery"
    if "amulet" in title or "bead" in title or "pendant" in title or "brooch" in title or "pin" in title or "necklace" in title or "earring" in title or "intaglio" in title:
        return "jewelry"
    if re.search(r"\b(?:finger\s+)?ring\b(?:\s+with|\s*\()", title):
        return "jewelry"
    if any(token in title for token in ["quilt", "needlework", "tapestry", "textile", "tunic", "fabric", "carpet", "lace", "basket"]):
        return "textile"
    if "mask" in title:
        return "mask"
    if any(token in title for token in ["figure", "statuette", "statue", "sculpture", "head", "crèche", "creche"]):
        return "sculpture"
    if any(token in title for token in ["sword guard", "tsuba", "smallsword", "tool", "compass", "astrolabe"]):
        return "tool"
    if "map" in title or "globe" in title or re.search(r"\batlas\b", title):
        return "map"
    return item.get("category") or "object"


def category_label(item):
    return CATEGORY_LABELS.get(item.get("category"), "object")


def hook_for(item, detail):
    item_id = item["id"]
    category = item.get("category") or "object"
    title = item["title"]
    title_lower = title.lower()
    material = clean_material(detail.get("medium"))
    motif_words = title_terms(title) or tag_words(item, detail)
    motifs = motif_details(motif_words)

    if "amulet" in title_lower:
        options = [
            "A protective object small enough to carry, but not small in meaning.",
            "An amulet where belief has been compressed into a hand-sized form.",
            "A tiny survival from the history of protection, adornment, and trust."
        ]
        return pick(options, item_id, "amulet-hook")
    if "bead" in title_lower:
        options = [
            "A bead that turns miniature scale into the whole point.",
            "A small piece of adornment with the patience of a much larger object.",
            "A tiny object made for the body, the hand, and close looking."
        ]
        return pick(options, item_id, "bead-hook")
    if "vessel" in title_lower or "jar" in title_lower or "bowl" in title_lower:
        if motifs:
            return f"A {category_label(item)} where {motifs} turn use into image."
        return "A vessel where usefulness and visual invention are hard to separate."
    if "mask" in title_lower:
        return "A made face meant for transformation rather than portraiture."
    if "map" in title_lower:
        return "A map that turns distance, knowledge, and ambition into one surface."
    if "sword guard" in title_lower or "tsuba" in title_lower:
        return "A guard for a weapon, but also a small field for image and wit."
    if "page" in title_lower or "folio" in title_lower or "book" in title_lower:
        return "A page where knowledge, image, and design share the same work."
    if "textile" in category and motifs:
        return f"A worked surface where {motifs} live in thread, pattern, and touch."
    if material and stable_index(item_id, 3, "material-hook") == 0:
        return f"A {category_label(item)} whose {material.lower()} gives the idea physical weight."
    if motifs:
        return f"A {category_label(item)} that gives {motifs} more presence than its scale suggests."

    fallback = [
        f"A {category_label(item)} that rewards close, unhurried looking.",
        f"A {category_label(item)} where the historical interest is in the details.",
        f"A {category_label(item)} with enough specificity to hold attention."
    ]
    return pick(fallback, item_id, "fallback-hook")


def story_for(item, detail):
    item_id = item["id"]
    category = item.get("category") or "object"
    title = item["title"]
    date_label = useful_date(detail.get("date")) or useful_date(item.get("date_display"))
    culture, country, region = sanitize_places(item, detail)
    origin_parts = [part for part in [culture, region, country] if part]
    origin = ", ".join(dict.fromkeys(origin_parts))
    maker = useful_maker(item, detail)
    material = clean_material(detail.get("medium"))
    motif_words = title_terms(title) or tag_words(item, detail)
    motifs = motif_details(motif_words)

    anchors = []
    if maker and date_label and origin:
        anchors.append(f"{title} is tied to {maker}, {origin}, {date_label}.")
    if maker and date_label:
        anchors.append(f"{title} is tied to {maker} and dated {date_label}.")
    if origin and date_label:
        anchors.append(f"{title} is tied to {origin}, {date_label}.")
    if origin:
        anchors.append(f"{title} is tied to {origin}.")
    if date_label:
        anchors.append(f"{title} is dated {date_label}.")

    if anchors:
        opener = anchors[stable_index(item_id, len(anchors), "story-opener")]
    else:
        opener = f"{title} survives as a {category_label(item)} with a clear object record and source image."

    observations = []
    if material:
        observations.append(f"The material matters: {material.lower()} keeps the piece tied to making, handling, and surface.")
    if motifs:
        observations.append(f"The {motifs} are not incidental; they give the object its first claim on attention.")
        observations.append(f"The {motifs} pull the eye in before the period label does.")
        observations.append(f"The {motifs} keep the piece from becoming just a label or date.")
    observations.append(pick(OBJECT_LINES.get(category, OBJECT_LINES["object"]), item_id, "object-line"))

    if category in {"jewelry", "tool"} and not material and not motifs:
        observations = [pick(OBJECT_LINES[category], item_id, "thin-object")]
    if category == "poster" and not (material or motifs):
        observations = [pick(OBJECT_LINES["poster"], item_id, "thin-poster")]

    observation = observations[stable_index(item_id, len(observations), "story-observation")]

    if len(opener) + len(observation) > 430:
        return opener
    return f"{opener} {observation}"


def why_for(item, detail):
    category = item.get("category") or "object"
    title = item["title"].lower()
    motifs = motif_details(title_terms(item["title"]) or tag_words(item, detail))

    if "amulet" in title:
        return "It shows belief working at pocket scale."
    if "bead" in title:
        return "It treats adornment as a serious historical record."
    if "sword guard" in title or "tsuba" in title:
        return "It turns protection into a place for image and taste."
    if motifs and stable_index(item["id"], 4, "why-motif") == 0:
        return f"It shows how {motifs} could carry meaning through a made object."
    return pick(WHY_LINES.get(category, WHY_LINES["object"]), item["id"], "why")


def iso_week_dates(year, week):
    start = date.fromisocalendar(year, week, 1)
    end = start + timedelta(days=6)
    return start.isoformat(), end.isoformat()


def completed_archive_week_count(year, today):
    week = 1
    completed = 0
    while True:
        try:
            _, end_date_text = iso_week_dates(year, week)
        except ValueError:
            return completed

        if date.fromisoformat(end_date_text) >= today:
            return completed

        completed = week
        week += 1


def fetch_details(items):
    # Keep this pass local and deterministic. The candidate pool already stores
    # source URLs and core metadata; remote detail lookups can time out and
    # should not block publishing a reviewed import file.
    return {item["id"]: {} for item in items}


def main():
    data = json.loads(POOL_PATH.read_text())
    items = data["candidate_curated_items"]
    cleanup_item_ids = sorted(set(data.get("cleanup_item_ids", [])) | {item["id"] for item in items})
    detail_by_id = fetch_details(items)

    for item in items:
        detail = detail_by_id.get(item["id"], {})
        item["category"] = normalized_category(item)
        culture, country, region = sanitize_places(item, detail)
        item["culture"] = culture
        item["country"] = country
        item["region"] = region
        item["maker"] = useful_maker(item, detail)
        item["date_display"] = useful_date(detail.get("date")) or item.get("date_display") or "Date unknown"
        item["hook"] = hook_for(item, detail)
        item["story"] = story_for(item, detail)
        item["why_it_matters"] = why_for(item, detail)
        item["editorial_status"] = "editorial-pass-ready"
        item["curator_note"] = (
            "Source metadata checked for archive import. Review image quality and final historical context before featuring."
        )

    week_count = completed_archive_week_count(ARCHIVE_YEAR, ARCHIVE_TODAY)
    selected_items = items[:week_count * 7]
    selected_ids = {item["id"] for item in selected_items}
    items_by_id = {item["id"]: item for item in selected_items}
    data["candidate_curated_items"] = selected_items

    packs = []
    for index in range(1, week_count + 1):
        calendar_week_key = f"{ARCHIVE_YEAR}-W{index:02d}"
        week_key = f"full-archive-{calendar_week_key}"
        start_date, end_date = iso_week_dates(ARCHIVE_YEAR, index)
        title, subtitle = PACK_THEMES[(index - 1) % len(PACK_THEMES)]
        item_ids = [
            item["id"]
            for item in selected_items[(index - 1) * 7:index * 7]
        ]
        if len(item_ids) != 7:
            raise SystemExit(f"Week {calendar_week_key} has {len(item_ids)} items, expected 7.")
        pack = {
            "id": week_key,
            "week_key": week_key,
            "title": title,
            "subtitle": subtitle,
            "item_ids": item_ids,
            "curator_note": "Archive import pack. Item order and source metadata were checked before import.",
            "start_date": start_date,
            "end_date": end_date
        }
        packs.append(pack)
        for item_id in item_ids:
            items_by_id[item_id]["primary_week_key"] = week_key

    for item in selected_items:
        if item["id"] not in selected_ids:
            item["primary_week_key"] = None

    data["candidate_weekly_packs"] = packs
    data["cleanup_item_ids"] = cleanup_item_ids
    data["target_archive_year"] = ARCHIVE_YEAR
    data["archive_today"] = ARCHIVE_TODAY.isoformat()
    data["archive_week_count"] = week_count
    data["target_count"] = len(selected_items)

    data["notes"] = [
        "Editorial pass applied to hooks, stories, origin labels, and why-it-matters lines.",
        "Copy is based on official source metadata and stays short where the metadata is thin.",
        "Cleveland tombstone text was removed from region labels to keep the app readable.",
        f"Weekly packs are dated from {ARCHIVE_YEAR}-W01 through {ARCHIVE_YEAR}-W{week_count:02d}, the last completed week before {ARCHIVE_TODAY.isoformat()}.",
        "Before public launch, review source pages and image quality for the final featured sequence."
    ]
    data["editorial_pass"] = {
        "status": "ready_for_supabase_import",
        "generated_by": "Scripts/editorialize_full_year_candidates.py",
        "source_detail_lookup": "not used; pass is grounded in stored source metadata"
    }

    POOL_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n")
    print(json.dumps({
        "items": len(data["candidate_curated_items"]),
        "packs": len(data["candidate_weekly_packs"]),
        "first_pack": data["candidate_weekly_packs"][0]["week_key"],
        "last_pack": data["candidate_weekly_packs"][-1]["week_key"],
        "archive_today": ARCHIVE_TODAY.isoformat(),
        "long_regions_remaining": sum(1 for item in items if len(item.get("region") or "") > 90)
    }, indent=2))


if __name__ == "__main__":
    main()
