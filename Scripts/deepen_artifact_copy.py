#!/usr/bin/env python3
import concurrent.futures
import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POOL_PATH = ROOT / "Content" / "full_year_candidate_pool.json"
IMPORT_SQL_PATH = ROOT / "Content" / "full_year_import.sql"
ADMIN_SEED_PATH = ROOT / "Content" / "admin_seed_sample.json"
UPDATE_SQL_PATH = ROOT / "Content" / "deep_dive_content_update.sql"

USER_AGENT = "HumanCollectiveDeepDiveCopy/1.0"

BAD_COPY_PATTERNS = [
    "Official metadata identifies",
    "human decision to make something worth keeping",
    "vivid piece of material culture",
    "rewards attention without announcing",
    "Nothing about",
    "feels accidental",
    "human point of entry",
    "still feels fresh",
    "in enough context to show what it is",
    "keeps a specific human purpose visible instead of",
]

GENERIC_TITLES = {
    "basket",
    "bird",
    "bull",
    "cat",
    "clock",
    "fish",
    "jar",
    "lion",
    "panel",
    "scroll",
    "teapot",
    "winepot",
}

CATEGORY_LABELS = {
    "architecture": "work of architecture",
    "artifact": "artifact",
    "book": "book",
    "car": "vehicle",
    "drink": "vessel",
    "fashion": "wearable object",
    "film": "film work",
    "food": "food creation",
    "furniture": "domestic object",
    "game": "game object",
    "instrument": "musical object",
    "invention": "inventive object",
    "jewelry": "piece of jewelry",
    "machine": "machine",
    "manuscript": "manuscript page",
    "map": "map",
    "mask": "mask",
    "monument": "monument",
    "music": "music object",
    "object": "object",
    "painting": "painting",
    "poster": "print",
    "pottery": "ceramic vessel",
    "public_space": "public space",
    "sculpture": "sculpture",
    "textile": "textile",
    "tool": "tool",
    "watch": "timepiece",
}

GENERATED_COPY_FRAGMENTS = [
    "That specificity matters because",
    " are not decoration alone; they point to what the maker wanted",
    " turn purpose into image.",
    "It also keeps the object's original purpose legible, not just its age or title.",
    "That is the deeper value here:",
]

TYPE_LABEL_RULES = [
    (("mask",), "mask"),
    (("map", "cartograph"), "map"),
    (("manuscript", "folio", "illuminated", "book"), "manuscript page"),
    (("drawing",), "drawing"),
    (("print",), "print"),
    (("photograph", "photography"), "photograph"),
    (("sculpture", "statuette", "statue", "relief", "figurine"), "sculpture"),
    (("jewelry", "jewellery", "amulet", "scarab", "ring", "bead", "pendant"), "piece of jewelry"),
    (("vessel", "ceramic", "pottery", "porcelain", "earthenware", "stoneware"), "ceramic vessel"),
    (("textile", "tapestry", "fabric", "costume", "garment"), "textile"),
    (("painting",), "painting"),
    (("weapon", "sword", "tool", "implement"), "tool"),
    (("furniture", "cabinet", "chair", "table", "coffer"), "domestic object"),
]

ARCHIVE_PACK_COPY = {
    "full-archive-2026-W01": ("Threads, Beasts, and Belief", "Animals, sacred scenes, and protective forms worked across cloth, metal, and sculpture."),
    "full-archive-2026-W02": ("Paradise and Protection", "Painted gardens, animal books, vessels, amulets, and a page of royal history."),
    "full-archive-2026-W03": ("Vessels and Woven Scenes", "Ceramic containers meet mirrors, needlework, and images of the seasons and creation."),
    "full-archive-2026-W04": ("Creatures on Paper and Clay", "A lion print, animal jewelry, a bird jar, a feathered tunic, and protective cat forms."),
    "full-archive-2026-W05": ("Amulets, Amphorae, and Pattern", "Protective figures, Greek vessels, a painted myth, and patterns drawn from fish and textiles."),
    "full-archive-2026-W06": ("Processions and Story Pages", "A royal procession, decorated objects, and manuscript scenes filled with people and animals."),
    "full-archive-2026-W07": ("Bulls, Beasts, and Vessels", "A bullfighting print, a frog weight, and ceramic creatures made for holding and pouring."),
    "full-archive-2026-W08": ("Market Life and Small Amulets", "A painted market, a serpent vessel, and tiny scaraboids shaped as familiar animals."),
    "full-archive-2026-W09": ("Objects Made to Be Held", "Cat and frog amulets, painted jars, paired vases, and a bright parrot-shaped vessel."),
    "full-archive-2026-W10": ("Frogs, Fish, and Printed Animals", "A textile panel, ceramic creatures, a satirical book, and studies of fish on paper."),
    "full-archive-2026-W11": ("Creatures Across Materials", "A theatrical mask, bird jewelry, decorated jars, painted bowls, and a dog-topped vessel."),
    "full-archive-2026-W12": ("Fish, Birds, and Portable Detail", "Bowls, textile fragments, a printed book, and a pearl cat designed for close looking."),
    "full-archive-2026-W13": ("Clay Vessels and Protective Forms", "Oil containers, storage jars, and small animal amulets made to be carried or kept close."),
    "full-archive-2026-W14": ("Bodies, Belief, and Bullfighting", "Sculpture, ritual vessels, rosary carving, amulets, and a print of the ring."),
    "full-archive-2026-W15": ("Small Symbols and Sacred Pages", "Animal pendants, miniature tools, protective frogs, and an illuminated Bible leaf."),
    "full-archive-2026-W16": ("Bulls, Rabbits, and Moving Images", "Printed bullfights, animal amulets, a ruler vessel, painted rabbits, and modern motion."),
    "full-archive-2026-W17": ("Power, Performance, and Pattern", "Bullfighting, battle, hunting, incense, ceramics, textiles, and painted social scenes."),
    "full-archive-2026-W18": ("Monkeys, Vessels, and Travel", "Ceramic monkeys, a bird vessel, a popular print, and a textile view of mounted travelers."),
    "full-archive-2026-W19": ("Prints, Paintings, and Ancient Text", "Bullfighting sheets, painted animals and tea, a ceramic bowl, and a carved hieroglyphic study."),
    "full-archive-2026-W20": ("Lions, Cats, and Fabric Stories", "Prints, paintings, sculpture, and textiles shaped by animals, hunting, and legend."),
    "full-archive-2026-W21": ("Animals in Drawings and Manuscripts", "Lions, cats, bulls, birds, flowers, and horses moving between paper and carved form."),
    "full-archive-2026-W22": ("Weapons, Games, and Animal Tales", "A sword, decorated guards, painted stories, fish prints, and a compact animal sculpture."),
}

OBSOLETE_OVERLAPPING_PACK_IDS = {
    f"full-archive-2026-W{week:02d}" for week in range(23, 28)
}

MOTIF_WORDS = [
    "animal",
    "angel",
    "basket",
    "bird",
    "boat",
    "bull",
    "butterfly",
    "cat",
    "cherub",
    "clock",
    "crane",
    "deer",
    "dog",
    "dragon",
    "elephant",
    "fish",
    "flower",
    "frog",
    "griffin",
    "hare",
    "horse",
    "ibis",
    "lion",
    "monkey",
    "owl",
    "parrot",
    "peacock",
    "rabbit",
    "snake",
    "snail",
    "turtle",
    "vulture",
    "whale",
]

SPECIAL_CONTEXT = {
    "noh-hannya-mask": (
        "In Noh theater the hannya face represents a woman transformed by jealousy, grief, or anger, "
        "and the mask was made for performance rather than static display; a small change in tilt can "
        "make the same carved face read as fury, sorrow, or restraint."
    ),
    "nasca-paracas-mantle": (
        "Mantles like this were made to wrap, display, and sometimes accompany the dead, so cloth could "
        "carry identity, status, and sacred imagery with the body."
    ),
    "waldseemuller-world-map": (
        "The 1507 map was made to reconcile classical geography with new Atlantic reports, and it is "
        "famous for helping place the name America on a printed world picture."
    ),
    "rosetta-stone": (
        "The stone was made as a public decree in three scripts: hieroglyphic, Demotic, and Greek. "
        "That practical act of royal communication later became the key to reading ancient Egyptian writing."
    ),
    "mask-of-agamemnon": (
        "The mask was made for burial, placed over the face of an elite Mycenaean dead person so gold "
        "could preserve presence, status, and memory at the threshold between body and tomb."
    ),
    "terracotta-warriors": (
        "The figures were made for the tomb of Qin Shi Huang, where ranks of modeled soldiers, horses, "
        "and officials created an underground guard for imperial power after death."
    ),
    "moche-portrait-vessel": (
        "Moche portrait vessels were made as ceramic containers and images of human presence, often tied "
        "to elite, ritual, or funerary settings on Peru's north coast."
    ),
    "sutton-hoo-helmet": (
        "The helmet was made for an elite Anglo-Saxon warrior burial, combining protection, display, "
        "and symbolic imagery in a grave meant to project status beyond death."
    ),
    "code-of-hammurabi-stele": (
        "The stele was made to display royal law and authority in durable stone, pairing written rules "
        "with an image of Hammurabi receiving legitimacy from the sun god Shamash."
    ),
    "lewis-chessmen": (
        "The chessmen were made for play, but their expressive kings, queens, bishops, knights, and warders "
        "also turn a strategy game into a miniature social world."
    ),
    "persian-astrolabe": (
        "Astrolabes were made to calculate time, position, and celestial relationships, joining astronomy, "
        "religious practice, navigation, and mathematical craft in a handheld instrument."
    ),
    "bayeux-tapestry-oath-scene": (
        "The scene belongs to a long embroidered narrative made to explain conquest, oath, and political "
        "legitimacy through images that could be read in sequence."
    ),
    "colima-seated-dog": (
        "Colima dog figures were made in western Mexico as ceramic companions, often associated with tombs, "
        "where the warm animal form could carry ideas of care, food, protection, or passage."
    ),
    "haniwa-horse-head": (
        "Haniwa figures were made for Japanese tomb mounds, where hollow clay animals, houses, and people "
        "marked the edge between the living world and the buried dead."
    ),
    "moche-head-vessel": (
        "Moche head vessels were made as containers and portraits, using clay to hold both liquid and a "
        "carefully modeled idea of personhood."
    ),
}

SPECIAL_WHY = {
    "noh-hannya-mask": "It matters because it shows how a fixed carved face can become emotionally alive through performance, light, and a moving body.",
    "waldseemuller-world-map": "It matters because it catches the world being redrawn in print, with geography, exploration, naming, and speculation all on one surface.",
    "rosetta-stone": "It matters because it began as political messaging but became one of the clearest bridges back into ancient Egyptian language.",
    "mask-of-agamemnon": "It matters because it turns burial into an image of presence, using gold to hold identity, power, and memory after death.",
    "terracotta-warriors": "It matters because it shows an empire imagining the afterlife at state scale, with craft organized into thousands of individual guardians.",
    "moche-portrait-vessel": "It matters because it lets a vessel work as both container and portrait, turning use into a record of social presence.",
    "persian-astrolabe": "It matters because it makes calculation physical, showing science, faith, navigation, and craftsmanship in one usable object.",
    "colima-seated-dog": "It matters because it gives companionship a durable form, making an animal figure feel protective, domestic, and ceremonial at once.",
    "book-of-kells-chi-rho": "It matters because it shows a book page made as devotion, where reading, looking, pigment, and disciplined labor become one experience.",
    "great-wave-kanagawa": "It matters because it shows how a printed image made for circulation can turn weather, travel, and Mount Fuji into a global visual language.",
    "haniwa-horse-head": "It matters because it shows tomb sculpture as a boundary marker between daily life, status, and the world of the dead.",
}


def clean(value):
    if value is None:
        return None
    if isinstance(value, dict):
        parts = []
        for key in ("title", "name", "term", "description", "alt_text", "url"):
            if key in value:
                parts.append(value.get(key))
        value = parts
    if isinstance(value, list):
        value = ", ".join(str(part) for part in value if part)
    value = re.sub(r"<[^>]+>", " ", str(value))
    value = value.replace("\u2018", "'").replace("\u2019", "'")
    value = value.replace("\u201c", '"').replace("\u201d", '"')
    value = value.replace("\u2013", "-").replace("\u2014", "-")
    value = re.sub(r"\s+", " ", value).strip()
    return value or None


def compact(value, max_length=110):
    value = clean(value)
    if not value:
        return None
    value = re.sub(r"\s*\([^)]*\)", "", value)
    value = re.split(r"\n|;", value)[0]
    value = re.sub(r"\s{2,}", " ", value).strip(" ,.")
    if len(value) > max_length:
        value = value[:max_length].rsplit(" ", 1)[0].strip(" ,.")
    return value or None


def article(label):
    return "an" if label[:1].lower() in {"a", "e", "i", "o", "u"} else "a"


def phrase_list(words):
    words = [word for word in words if word]
    if not words:
        return None
    if len(words) == 1:
        return words[0]
    if len(words) == 2:
        return f"{words[0]} and {words[1]}"
    return f"{words[0]}, {words[1]}, and {words[2]}"


def strip_generated_copy(text):
    text = clean(text)
    if not text:
        return None
    sentences = re.split(r"(?<=[.!?])\s+", text)
    kept = [
        sentence
        for sentence in sentences
        if not any(fragment in sentence for fragment in GENERATED_COPY_FRAGMENTS)
    ]
    return clean(" ".join(kept))


def fetch_json(url, params=None, retries=2):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=18) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception:
            if attempt >= retries:
                return None
            time.sleep(0.25 * (attempt + 1))
    return None


def source_key(item):
    return (
        item.get("content_source_id") or "",
        item.get("source_name") or "",
        item.get("source_object_id") or "",
        item.get("source_url") or "",
    )


def source_object_id_from_url(item):
    source_id = clean(item.get("source_object_id"))
    if source_id:
        return source_id
    source_url = clean(item.get("source_url")) or ""
    match = re.search(r"/(?:search|artworks|art|objects)/([^/?#]+)", source_url)
    if match:
        return match.group(1)
    return None


def detail_from_artic(item):
    object_id = source_object_id_from_url(item)
    if not object_id:
        return {}
    fields = ",".join([
        "title",
        "artist_display",
        "artist_title",
        "date_display",
        "place_of_origin",
        "medium_display",
        "classification_titles",
        "subject_titles",
        "description",
        "short_description",
        "thumbnail",
        "department_title",
    ])
    data = fetch_json(f"https://api.artic.edu/api/v1/artworks/{object_id}", {"fields": fields})
    record = (data or {}).get("data") or {}
    thumbnail = record.get("thumbnail") if isinstance(record.get("thumbnail"), dict) else {}
    return {
        "source": "artic",
        "title": clean(record.get("title")),
        "maker": clean(record.get("artist_title") or record.get("artist_display")),
        "date": clean(record.get("date_display")),
        "origin": clean(record.get("place_of_origin")),
        "medium": clean(record.get("medium_display")),
        "type": clean(record.get("classification_titles") or record.get("department_title")),
        "subjects": clean(record.get("subject_titles")),
        "description": clean(record.get("description") or record.get("short_description")),
        "alt_text": clean(thumbnail.get("alt_text")),
    }


def detail_from_cleveland(item):
    object_id = source_object_id_from_url(item)
    if not object_id:
        return {}
    data = fetch_json(f"https://openaccess-api.clevelandart.org/api/artworks/{object_id}")
    record = (data or {}).get("data") or {}
    creators = record.get("creators") or []
    maker = None
    if creators and isinstance(creators[0], dict):
        maker = clean(creators[0].get("description") or creators[0].get("name"))
    images = record.get("images") if isinstance(record.get("images"), dict) else {}
    web_image = images.get("web") if isinstance(images.get("web"), dict) else {}
    return {
        "source": "cleveland",
        "title": clean(record.get("title")),
        "maker": maker,
        "date": clean(record.get("creation_date")),
        "origin": clean(record.get("culture") or record.get("country")),
        "medium": clean(record.get("technique") or record.get("support_materials")),
        "type": clean(record.get("type") or record.get("collection")),
        "subjects": clean(record.get("tags")),
        "description": clean(record.get("description") or record.get("wall_description") or record.get("did_you_know")),
        "alt_text": clean(web_image.get("filename")),
    }


def detail_from_met(item):
    object_id = source_object_id_from_url(item)
    if not object_id:
        return {}
    data = fetch_json(f"https://collectionapi.metmuseum.org/public/collection/v1/objects/{object_id}")
    if not data:
        return {}
    tags = []
    for tag in data.get("tags") or []:
        if isinstance(tag, dict):
            tags.append(tag.get("term"))
    return {
        "source": "met",
        "title": clean(data.get("title")),
        "maker": clean(data.get("artistDisplayName")),
        "date": clean(data.get("objectDate")),
        "origin": clean(data.get("culture") or data.get("period") or data.get("country")),
        "medium": clean(data.get("medium")),
        "type": clean(data.get("objectName") or data.get("classification") or data.get("department")),
        "subjects": clean(tags),
        "description": None,
        "alt_text": None,
        "wikidata": clean(data.get("objectWikidata_URL") or data.get("artistWikidata_URL")),
    }


def wikidata_title(wikidata_url):
    if not wikidata_url:
        return None
    qid = wikidata_url.rstrip("/").rsplit("/", 1)[-1]
    data = fetch_json(
        "https://www.wikidata.org/w/api.php",
        {
            "action": "wbgetentities",
            "ids": qid,
            "props": "sitelinks",
            "sitefilter": "enwiki",
            "format": "json",
        },
    )
    entity = ((data or {}).get("entities") or {}).get(qid) or {}
    sitelinks = entity.get("sitelinks") or {}
    enwiki = sitelinks.get("enwiki") or {}
    return clean(enwiki.get("title"))


def wikipedia_summary(title):
    title = clean(title)
    if not title:
        return None
    encoded = urllib.parse.quote(title.replace(" ", "_"))
    data = fetch_json(f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}", retries=1)
    if not data or data.get("type") == "disambiguation":
        return None
    return {
        "title": clean(data.get("title")),
        "description": clean(data.get("description")),
        "extract": clean(data.get("extract")),
    }


def detail_from_wikipedia(item, detail):
    title = wikidata_title(detail.get("wikidata")) if detail.get("wikidata") else None
    if not title:
        candidate = clean(item.get("title"))
        if candidate and candidate.lower() not in GENERIC_TITLES:
            title = candidate
    summary = wikipedia_summary(title)
    if not summary:
        return {}
    item_title = clean(item.get("title")) or ""
    page_title = summary.get("title") or ""
    page_desc = summary.get("description") or ""
    title_match = (
        item_title.lower() == page_title.lower()
        or item_title.lower() in page_title.lower()
        or page_title.lower() in item_title.lower()
    )
    maker = clean(item.get("maker") or detail.get("maker")) or ""
    maker_surname = maker.split()[-1].strip(",.") if maker else ""
    maker_match = maker_surname and maker_surname.lower() in (page_desc + " " + (summary.get("extract") or "")).lower()
    if not title_match and not maker_match:
        return {}
    return {
        "wiki_title": summary.get("title"),
        "wiki_description": summary.get("description"),
    }


def source_detail(item):
    source_id = item.get("content_source_id") or ""
    source_name = (item.get("source_name") or "").lower()
    if source_id == "artic-public-domain" or "art institute of chicago" in source_name:
        detail = detail_from_artic(item)
    elif source_id == "cleveland-open-access" or "cleveland museum" in source_name:
        detail = detail_from_cleveland(item)
    elif source_id == "met-open-access" or "metropolitan museum" in source_name:
        detail = detail_from_met(item)
    else:
        detail = {}
    wiki = detail_from_wikipedia(item, detail)
    detail.update(wiki)
    return detail


def fetch_details(items):
    unique = {}
    for item in items:
        unique.setdefault(source_key(item), item)
    details = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=14) as executor:
        future_by_key = {
            executor.submit(source_detail, item): key
            for key, item in unique.items()
        }
        for future in concurrent.futures.as_completed(future_by_key):
            key = future_by_key[future]
            try:
                details[key] = future.result()
            except Exception:
                details[key] = {}
    return {item["id"]: details.get(source_key(item), {}) for item in items}


def readable_maker(item, detail):
    maker = clean(detail.get("maker") or item.get("maker"))
    if not maker:
        return None
    lowered = maker.lower()
    non_person = {
        "american", "ancient", "austrian", "belgian", "british", "chinese", "egyptian",
        "england", "english", "flemish", "france", "french", "german",
        "greek", "india", "indian", "italian", "japan", "japanese",
        "korean", "mexican", "peru", "peruvian", "roman", "russian",
        "spain", "spanish", "united states",
    }
    if lowered.startswith(("unknown", "probably ")) or lowered.strip(" ,;.") in non_person:
        return None
    maker = re.sub(r"^(Designed and executed by|Made by|Designed by|Painted by|Printed by|Woven by|After)\s+", "", maker, flags=re.I)
    maker = re.sub(r"\s*\([^)]*\)", "", maker)
    maker = re.split(
        r"\b(?:American|Austrian|Belgian|British|Brooklyn Heights|Chinese|Dutch|Egyptian|England|English|Flemish|France|French|German|Greek|India|Indian|Italian|Japan|Japanese|Korean|Mexican|Naples|New Jersey|New York|Peru|Peruvian|Roman|Russian|Spain|Spanish|United States)\b",
        maker,
        flags=re.I,
    )[0]
    maker = compact(maker, 80)
    if maker and maker.lower().strip(" ,;.") in non_person:
        return None
    return maker


def readable_origin(item, detail):
    origin = compact(detail.get("origin") or item.get("culture") or item.get("country"), 74)
    if not origin:
        return None
    noisy = ["The Cleveland Museum of Art", "overall:", "Gift of", "Purchase"]
    if any(token in origin for token in noisy):
        return compact(item.get("culture") or item.get("country"), 74)
    return origin


def origin_fact(origin):
    origin = clean(origin)
    if not origin:
        return None
    replacements = {
        "Chinese": "Chinese culture",
        "German Renaissance": "the German Renaissance",
        "Japanese": "Japanese culture",
        "Moche": "Moche culture",
        "Mycenaean": "Mycenaean Greece",
        "Nasca-Paracas": "Nasca-Paracas culture",
        "Persian": "Persian scientific culture",
        "Ptolemaic Egyptian": "Ptolemaic Egypt",
    }
    return f"from {replacements.get(origin, origin)}"


def readable_medium(detail):
    medium = compact(detail.get("medium"), 110)
    if not medium:
        return None
    medium = re.sub(r"\boverall:.*$", "", medium, flags=re.I).strip(" ,;.")
    medium = re.sub(r"\bframed:.*$", "", medium, flags=re.I).strip(" ,;.")
    medium = re.sub(r"\bsheet:.*$", "", medium, flags=re.I).strip(" ,;.")
    return compact(medium, 96)


def title_terms(item, detail):
    text = " ".join([
        clean(item.get("title")) or "",
        clean(item.get("tags")) or "",
        clean(detail.get("subjects")) or "",
        clean(detail.get("alt_text")) or "",
    ]).lower()
    terms = []
    for word in MOTIF_WORDS:
        if re.search(rf"\b{re.escape(word)}s?\b", text):
            terms.append(word)
    return terms[:3]


def label_for(item, detail):
    title = (item.get("title") or "").lower()
    jewelry_title = (
        "amulet" in title
        or any(word in title for word in ["scarab", "pendant", "necklace", "ear ornament", "brooch", "rosary bead", "baroque pearl"])
        or title.startswith(("ring", "finger ring"))
        or "ring stone" in title
    )
    if jewelry_title:
        return "piece of jewelry"
    if any(word in title for word in ["vessel", "jar", "bowl", "amphora", "pitcher", "oinochoe", "rhyton", "teapot", "winepot"]):
        return "ceramic vessel"
    if "mask" in title:
        return "mask"
    if any(word in title for word in ["page", "folio", "leaf", "book of hours", "qur'an", "bible"]):
        return "manuscript page"
    if any(word in title for word in ["quilt", "fabric", "tunic", "poncho", "kesa", "textile"]):
        return "textile"
    if "clock" in title or "timepiece" in title:
        return "timepiece"
    detail_type = compact(detail.get("type"), 48)
    if detail_type:
        normalized_type = detail_type.lower()
        if any(term in normalized_type for term in ("etching", "engraving", "lithograph", "woodcut", "aquatint")):
            return "print"
        for terms, label in TYPE_LABEL_RULES:
            if any(term in normalized_type for term in terms):
                return label
    if "mask" in title:
        return "mask"
    if any(word in title for word in ["print", "plate", "lithograph", "bullfight"]):
        return "print"
    if any(word in title for word in ["statue", "statuette", "sculpture", "relief", "figurine"]):
        return "sculpture"
    if "crèche" in title or "creche" in title:
        return "sculpture"
    if any(word in title for word in ["vessel", "jar", "bowl", "dish", "amphora", "pitcher", "oinochoe", "rhyton"]):
        return "ceramic vessel"
    if any(word in title for word in ["page", "folio", "leaf", "book of hours", "qur'an", "bible"]):
        return "manuscript page"
    if any(word in title for word in ["amulet", "bead", "pendant", "necklace", "ring", "ear ornament"]):
        return "piece of jewelry"
    if any(word in title for word in ["quilt", "fabric", "tunic", "poncho", "kesa", "textile"]):
        return "textile"
    if "clock" in title or "timepiece" in title:
        return "timepiece"
    return CATEGORY_LABELS.get(item.get("category"), "object")


def category_for(item, label):
    title = (item.get("title") or "").lower()
    if "amulet" in title:
        return "amulet"
    label_kind = {
        "ceramic vessel": "vessel",
        "domestic object": "domestic",
        "drawing": "drawing",
        "manuscript page": "page",
        "map": "map",
        "mask": "mask",
        "painting": "painting",
        "photograph": "photograph",
        "piece of jewelry": "jewelry",
        "print": "print",
        "sculpture": "sculpture",
        "textile": "textile",
        "timepiece": "timepiece",
        "tool": "tool",
    }
    if label in label_kind:
        return label_kind[label]
    if any(word in title for word in ["vessel", "jar", "bowl", "dish", "amphora", "pitcher", "oinochoe", "rhyton", "teapot", "winepot"]):
        return "vessel"
    if any(word in title for word in ["page", "folio", "leaf", "book", "qur'an", "bible", "manuscript"]):
        return "page"
    if any(word in title for word in ["print", "poster", "plate", "lithograph", "bullfight"]):
        return "print"
    if any(word in title for word in ["quilt", "textile", "fabric", "tunic", "poncho", "kesa", "headcloth"]):
        return "textile"
    if any(word in title for word in ["bead", "pendant", "necklace", "ear ornament", "brooch", "pin"]):
        return "jewelry"
    if any(word in title for word in ["clock", "timepiece", "watch"]):
        return "timepiece"
    if "mask" in title:
        return "mask"
    if any(word in title for word in ["sword", "guard", "tsuba", "astrolabe", "tool", "whistle", "inkstone"]):
        return "tool"
    if any(word in title for word in ["cabinet", "chair", "table", "coffer", "basket"]):
        return "domestic"
    if item.get("category") in {"painting", "sculpture", "map", "film", "instrument", "architecture"}:
        return item.get("category")
    return "object"


def normalized_category(item, label, kind):
    return {
        "architecture": "architecture",
        "amulet": "jewelry",
        "domestic": "object",
        "drawing": "art",
        "film": "film",
        "instrument": "instrument",
        "jewelry": "jewelry",
        "map": "map",
        "mask": "mask",
        "page": "manuscript",
        "painting": "painting",
        "photograph": "photography",
        "print": "poster",
        "sculpture": "sculpture",
        "textile": "textile",
        "timepiece": "watch",
        "tool": "tool",
        "vessel": "pottery",
    }.get(kind, {
        "ceramic vessel": "pottery",
        "domestic object": "object",
        "manuscript page": "manuscript",
        "piece of jewelry": "jewelry",
    }.get(label, item.get("category") or "object"))


def purpose_for(kind):
    return {
        "amulet": "It was made to be worn or carried as protection, devotion, or identity in a form small enough to stay close to the body.",
        "architecture": "It was made to picture a built place, using architecture as a way to talk about order, power, memory, or daily life.",
        "domestic": "It was made for use in a room or household, where function, display, and taste had to work together.",
        "drawing": "It was made through direct marks on a surface, using line, tone, and attention to make an idea visible.",
        "film": "It was made to move images through time, turning performance, editing, and public viewing into one shared experience.",
        "instrument": "It was made for sound, but its shape also records the craft and social setting around music.",
        "jewelry": "It was made to be worn, so its meaning depended on closeness to the body as much as visual display.",
        "map": "It was made to organize space, names, distance, and power into a surface someone could read and use.",
        "mask": "It was made to transform a wearer, giving performance, ritual, or role a face that could be activated by a body.",
        "page": "It was made to carry reading, memory, devotion, or teaching through a physical page.",
        "painting": "It was made for sustained looking, arranging a scene so viewers could read story, status, belief, or atmosphere.",
        "print": "It was made to circulate, letting one design travel through copies, viewers, and public attention.",
        "sculpture": "It was made to give a body, symbol, or story physical presence in space.",
        "textile": "It was made through slow handwork, where use, display, pattern, and memory could share the same surface.",
        "timepiece": "It was made to measure time while also turning precision, luxury, and craft into a visible object.",
        "tool": "It was made to solve a practical problem, but its finish shows that usefulness could still carry style and status.",
        "vessel": "It was made to hold, pour, serve, or present something, so its decoration had to live with use.",
        "object": "It was made to be used, seen, kept, or exchanged, which is why its material choices still matter.",
    }.get(kind, "It was made to be used, seen, kept, or exchanged, which is why its material choices still matter.")


def why_for(kind, label, motifs, medium):
    motif_phrase = phrase_list(motifs)
    if kind == "amulet":
        return "It matters because it shows belief becoming portable: protection, identity, and craft condensed into a small object."
    if kind == "vessel":
        if motif_phrase:
            return f"It matters because it lets everyday or ritual use carry imagery, with {motif_phrase} turning a container into a cultural record."
        return "It matters because it lets practical use and visual meaning occupy the same handled form."
    if kind == "textile":
        return "It matters because it treats thread, pattern, and domestic labor as serious cultural evidence."
    if kind == "page":
        return "It matters because it shows knowledge and belief as things people designed, touched, carried, and preserved."
    if kind == "print":
        return "It matters because it shows culture spreading through repeatable images made for circulation."
    if kind == "drawing":
        return "It matters because it preserves thought and observation in the direct evidence of marks made by hand."
    if kind == "jewelry":
        return "It matters because it shows meaning at bodily scale, where adornment, status, and protection can overlap."
    if kind == "timepiece":
        return "It matters because it turns timekeeping into a display of craft, materials, and social ambition."
    if kind == "tool":
        return "It matters because it preserves practical intelligence as design, not just as function."
    if kind == "mask":
        return "It matters because it lets identity become made, worn, and performed."
    if kind == "painting":
        return "It matters because it preserves a historical way of staging attention, story, and value for a viewer."
    if kind == "sculpture":
        return "It matters because it gives cultural meaning a body, weight, and physical presence."
    if kind == "map":
        return "It matters because it shows geography as an argument people made, not just a neutral record of place."
    if medium:
        return f"It matters because the choice of {medium.lower()} makes the {label} a record of decisions about use, surface, and survival."
    return f"It matters because this {label} keeps its intended work visible: how it was used, displayed, valued, or carried across time."


def depth_line_for(kind, label, motifs, medium):
    motif_phrase = phrase_list(motifs)
    if motif_phrase:
        return "Seen in its original material and scale, the subject also shows how closely image, surface, and making were connected."
    if kind == "map":
        return "The point was not only to show land and sea, but to make knowledge portable, persuasive, and newly shareable."
    if kind == "mask":
        return "Its meaning only becomes complete when the object meets a performer, a role, and an audience."
    if kind == "sculpture":
        return "The point of making the form in three dimensions was to let meaning occupy the same space as the viewer."
    if kind == "vessel":
        return "That makes the object more than a container: it is a record of how usefulness could be given social or ritual force."
    if kind == "textile":
        return "That makes the textile a record of time spent making, not just a patterned surface."
    if kind == "page":
        return "Its purpose depended on being read or seen in sequence, so layout and material were part of the message."
    if kind == "tool":
        return "The result is a reminder that precision and beauty were often built into the same working object."
    if medium:
        return f"The {medium.lower()} gives that purpose a physical character: weight, surface, durability, and a reason to look closely."
    return f"That is the deeper value here: the {label} still tells us what someone needed an object to do."


def hook_for(item, detail, label, kind, motifs, medium):
    title = clean(item.get("title")) or "Untitled"
    origin = readable_origin(item, detail)
    date = compact(detail.get("date") or item.get("date_display"), 40)
    if date and date.lower().strip(" .") in {"n.d", "unknown", "date unknown"}:
        date = None
    motif_phrase = phrase_list(motifs)
    when_where = ", ".join(part for part in [origin, date] if part)
    if motif_phrase:
        return f"{article(label).title()} {label} from {when_where}, with {motif_phrase} bringing its subject into focus.".replace(" from ,", ",")
    if medium:
        return f"{article(label).title()} {label} from {when_where} made vivid by {medium.lower()}.".replace(" from  made", " made")
    if kind in {"amulet", "jewelry", "timepiece", "tool", "vessel"}:
        return f"{article(label).title()} {label} from {when_where} where use and meaning meet.".replace(" from  where", " where")
    return f"{title} in enough context to show what it is, how it worked, and why someone made it."


def story_for(item, detail, label, kind, motifs, medium):
    title = clean(item.get("title")) or "Untitled"
    maker = readable_maker(item, detail)
    origin = readable_origin(item, detail)
    date = compact(detail.get("date") or item.get("date_display"), 54)
    facts = []
    if maker:
        facts.append(f"by {maker}")
    origin_text = origin_fact(origin)
    if origin_text:
        facts.append(origin_text)
    if date:
        if date.lower().strip(" .") not in {"n.d", "unknown", "date unknown"}:
            facts.append(f"dated {date}")
    if medium:
        facts.append(f"made with {medium.lower()}")

    if facts:
        opener = f"{title} is {article(label)} {label} " + ", ".join(facts) + "."
    else:
        opener = f"{title} is {article(label)} {label} preserved with an open source image and catalog record."

    purpose = purpose_for(kind)

    motif_phrase = phrase_list(motifs)
    special = SPECIAL_CONTEXT.get(item.get("id"))
    if special:
        close = special
    elif motif_phrase:
        close = f"The use of {motif_phrase} anchors the composition and gives the viewer a direct point of entry into its subject."
    elif medium:
        close = f"The {medium.lower()} is part of the meaning because material decides weight, shine, durability, and how close a viewer wants to look."
    else:
        close = "The important thing is not only that it survived, but that its form still makes a purpose visible."

    story = f"{opener} {purpose} {close}"
    story = re.sub(r"\s+", " ", story).strip()
    if len(story) < 330:
        story = f"{story} {depth_line_for(kind, label, motifs, medium)}"
    return story


def has_bad_copy(story, why):
    text = f"{story or ''} {why or ''}"
    return any(pattern in text for pattern in BAD_COPY_PATTERNS)


def merged_existing_copy(item, label, kind, motifs, medium):
    raw_hook = clean(item.get("hook")) or ""
    raw_story = clean(item.get("story")) or ""
    if " turn purpose into image" in raw_hook or " where use and meaning meet" in raw_hook:
        return None
    if raw_story.startswith(f"{clean(item.get('title'))} is ") and "made with" in raw_story:
        return None
    existing_story = strip_generated_copy(item.get("story"))
    existing_why = strip_generated_copy(item.get("why_it_matters"))
    existing_hook = clean(item.get("hook"))
    if not existing_story or has_bad_copy(existing_story, existing_why):
        return None

    story = existing_story
    additions = []
    special = SPECIAL_CONTEXT.get(item.get("id"))
    if special and special[:60] not in story:
        additions.append(special)
    elif "made" not in story.lower() or len(story) < 330:
        additions.append(purpose_for(kind))
    additions.append(depth_line_for(kind, label, motifs, medium))

    for addition in additions:
        if len(story) >= 330 and "made" in story.lower():
            break
        if addition and addition not in story:
            story = f"{story} {addition}"
    if len(story) < 330:
        story = (
            f"{story} That added purpose is what makes the piece useful for the archive: "
            "it explains why the object was made, not only what it is called."
        )

    why = existing_why or why_for(kind, label, motifs, medium)
    if len(why) < 90:
        why = SPECIAL_WHY.get(item.get("id")) or (
            f"{why} It also keeps the object's original purpose legible, not just its age or title."
        )

    hook = existing_hook
    if not hook or "in enough context to show" in hook:
        hook = hook_for(item, {}, label, kind, motifs, medium)

    return {
        "hook": hook,
        "story": re.sub(r"\s+", " ", story).strip(),
        "why_it_matters": re.sub(r"\s+", " ", why).strip(),
    }


def rewrite_item(item, detail):
    label = label_for(item, detail)
    kind = category_for(item, label)
    item["category"] = normalized_category(item, label, kind)
    if detail.get("source"):
        item["maker"] = readable_maker(item, detail)
    motifs = title_terms(item, detail)
    medium = readable_medium(detail)
    merged = merged_existing_copy(item, label, kind, motifs, medium)
    if merged:
        item.update(merged)
        if "editorial_status" in item:
            item["editorial_status"] = "deep-dive-ready"
        if "curator_note" in item:
            item["curator_note"] = (
                "Deep-dive copy refreshed while preserving stronger existing editorial writing."
            )
        return item

    item["hook"] = hook_for(item, detail, label, kind, motifs, medium)
    item["story"] = story_for(item, detail, label, kind, motifs, medium)
    item["why_it_matters"] = SPECIAL_WHY.get(item.get("id")) or why_for(kind, label, motifs, medium)
    if len(item["why_it_matters"]) < 90:
        item["why_it_matters"] = f"{item['why_it_matters']} It keeps the object's purpose legible instead of leaving only a label."
    if "editorial_status" in item:
        item["editorial_status"] = "deep-dive-ready"
    if "curator_note" in item:
        item["curator_note"] = (
            "Deep-dive copy refreshed from official source metadata with Wikipedia fallback context where useful."
        )
    return item


def collect_items():
    items = []
    pool = json.loads(POOL_PATH.read_text())
    items.extend(pool.get("candidate_curated_items", []))
    admin = json.loads(ADMIN_SEED_PATH.read_text())
    items.extend(admin.get("curated_items", []))
    sql = IMPORT_SQL_PATH.read_text()
    blocks = re.findall(r"\$_hc\$(.*?)\$_hc\$::jsonb", sql, flags=re.S)
    if len(blocks) >= 3:
        items.extend(json.loads(blocks[2]))
    unique = {}
    for item in items:
        if item.get("id"):
            unique[item["id"]] = item
    return list(unique.values())


def sql_json(value):
    payload = json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    return f"$_hc${payload}$_hc$::jsonb"


def update_import_sql(copy_by_id):
    sql = IMPORT_SQL_PATH.read_text()
    matches = list(re.finditer(r"\$_hc\$(.*?)\$_hc\$::jsonb", sql, flags=re.S))
    if len(matches) < 3:
        raise SystemExit("Could not find culture item JSON block in full_year_import.sql")
    item_match = matches[2]
    items = json.loads(item_match.group(1))
    for item in items:
        refreshed = copy_by_id.get(item.get("id"))
        if refreshed:
            item["category"] = refreshed["category"]
            item["maker"] = refreshed.get("maker")
            item["hook"] = refreshed["hook"]
            item["story"] = refreshed["story"]
            item["why_it_matters"] = refreshed["why_it_matters"]
    replacement = sql_json(items)
    sql = sql[: item_match.start()] + replacement + sql[item_match.end() :]

    matches = list(re.finditer(r"\$_hc\$(.*?)\$_hc\$::jsonb", sql, flags=re.S))
    packs = json.loads(matches[3].group(1))
    links = json.loads(matches[4].group(1))
    packs = [pack for pack in packs if pack["id"] not in OBSOLETE_OVERLAPPING_PACK_IDS]
    links = [link for link in links if link["pack_id"] not in OBSOLETE_OVERLAPPING_PACK_IDS]
    for pack in packs:
        if pack["id"] in ARCHIVE_PACK_COPY:
            pack["title"], pack["subtitle"] = ARCHIVE_PACK_COPY[pack["id"]]

    replacements = [
        (matches[4], sql_json(links)),
        (matches[3], sql_json(packs)),
    ]
    for match, value in replacements:
        sql = sql[: match.start()] + value + sql[match.end() :]
    return sql


def write_update_sql(items):
    rows = [
        {
            "id": item["id"],
            "category": item["category"],
            "maker": item.get("maker"),
            "hook": item["hook"],
            "story": item["story"],
            "why_it_matters": item["why_it_matters"],
        }
        for item in sorted(items, key=lambda value: value["id"])
    ]
    pack_rows = [
        {"id": pack_id, "title": copy[0], "subtitle": copy[1]}
        for pack_id, copy in sorted(ARCHIVE_PACK_COPY.items())
    ]
    obsolete_pack_ids = sorted(OBSOLETE_OVERLAPPING_PACK_IDS)
    obsolete_pack_ids_sql = "array[" + ",".join(
        "'" + pack_id.replace("'", "''") + "'" for pack_id in obsolete_pack_ids
    ) + "]"
    sql = f"""begin;

with payload as (
  select {sql_json(rows)} as doc
)
update public.culture_items as culture_items
set
  category = payload_rows.category,
  maker = payload_rows.maker,
  hook = payload_rows.hook,
  story = payload_rows.story,
  why_it_matters = payload_rows.why_it_matters
from jsonb_to_recordset((select doc from payload)) as payload_rows(
  id text,
  category text,
  maker text,
  hook text,
  story text,
  why_it_matters text
)
where culture_items.id = payload_rows.id;

with payload as (
  select {sql_json(pack_rows)} as doc
)
update public.culture_packs as culture_packs
set
  title = payload_rows.title,
  subtitle = payload_rows.subtitle
from jsonb_to_recordset((select doc from payload)) as payload_rows(
  id text,
  title text,
  subtitle text
)
where culture_packs.id = payload_rows.id;

delete from public.culture_pack_items
where pack_id = any({obsolete_pack_ids_sql}::text[]);

delete from public.culture_packs
where id = any({obsolete_pack_ids_sql}::text[]);

commit;
"""
    UPDATE_SQL_PATH.write_text(sql)


def audit(items):
    failures = []
    for item in items:
        story = item.get("story") or ""
        why = item.get("why_it_matters") or ""
        text = f"{story} {why}"
        if any(pattern in text for pattern in BAD_COPY_PATTERNS):
            failures.append((item["id"], "generic_phrase"))
        if len(story) < 300:
            failures.append((item["id"], f"story_too_short:{len(story)}"))
        if len(why) < 90:
            failures.append((item["id"], f"why_too_short:{len(why)}"))
        if "made" not in story.lower():
            failures.append((item["id"], "missing_made_language"))
    return failures


def main():
    all_items = collect_items()
    details_by_id = fetch_details(all_items)
    refreshed_by_id = {
        item["id"]: rewrite_item(dict(item), details_by_id.get(item["id"], {}))
        for item in all_items
    }

    pool = json.loads(POOL_PATH.read_text())
    for item in pool.get("candidate_curated_items", []):
        refreshed = refreshed_by_id.get(item.get("id"))
        if refreshed:
            item.update({
                "hook": refreshed["hook"],
                "story": refreshed["story"],
                "why_it_matters": refreshed["why_it_matters"],
                "editorial_status": refreshed.get("editorial_status", item.get("editorial_status")),
                "curator_note": refreshed.get("curator_note", item.get("curator_note")),
            })
    POOL_PATH.write_text(json.dumps(pool, indent=2, ensure_ascii=True) + "\n")

    admin = json.loads(ADMIN_SEED_PATH.read_text())
    for item in admin.get("curated_items", []):
        refreshed = refreshed_by_id.get(item.get("id"))
        if refreshed:
            item.update({
                "category": refreshed["category"],
                "maker": refreshed.get("maker"),
                "hook": refreshed["hook"],
                "story": refreshed["story"],
                "why_it_matters": refreshed["why_it_matters"],
            })
    ADMIN_SEED_PATH.write_text(json.dumps(admin, indent=2, ensure_ascii=True) + "\n")

    IMPORT_SQL_PATH.write_text(update_import_sql(refreshed_by_id))

    update_items = []
    seen = set()
    for source in [admin.get("curated_items", [])]:
        for item in source:
            if item["id"] not in seen:
                seen.add(item["id"])
                update_items.append(refreshed_by_id[item["id"]])
    sql = IMPORT_SQL_PATH.read_text()
    blocks = re.findall(r"\$_hc\$(.*?)\$_hc\$::jsonb", sql, flags=re.S)
    for item in json.loads(blocks[2]):
        if item["id"] not in seen:
            seen.add(item["id"])
            update_items.append(refreshed_by_id[item["id"]])
    write_update_sql(update_items)

    failures = audit(update_items)
    print(json.dumps({
        "source_items_seen": len(all_items),
        "unique_items_refreshed": len(refreshed_by_id),
        "live_update_rows": len(update_items),
        "candidate_pool_items": len(pool.get("candidate_curated_items", [])),
        "admin_seed_items": len(admin.get("curated_items", [])),
        "audit_failures": len(failures),
        "audit_failure_sample": failures[:10],
        "update_sql": str(UPDATE_SQL_PATH.relative_to(ROOT)),
    }, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
