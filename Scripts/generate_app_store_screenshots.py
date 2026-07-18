#!/usr/bin/env python3
"""Build the layered App Store screenshot cards from exact simulator captures."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "AppStore" / "Screenshots" / "raw" / "iphone-6.9"
OUTPUT = ROOT / "AppStore" / "Screenshots" / "final" / "iphone-6.5"
FULL_SET_OUTPUT = OUTPUT / "full-set"
PREVIEWS = ROOT / "AppStore" / "Screenshots" / "previews"
BACKGROUNDS = ROOT / "AppStore" / "Screenshots" / "backgrounds"
MARKETING = ROOT / "AppStore" / "Marketing"
ASSET_CATALOG = ROOT / "HumanCollective" / "Resources" / "Assets.xcassets"
LEGACY_RAW = Path(
    "/Users/samb/Desktop/Human Collective Files/App Store Assets/"
    "Human Collective App Store Screenshots/raw"
)
APP_ICON = (
    ROOT
    / "HumanCollective"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "AppIcon.png"
)

CANVAS_SIZE = (1242, 2688)
PANORAMA_SIZE = (CANVAS_SIZE[0] * 5, CANVAS_SIZE[1])
BACKGROUND = (247, 242, 232, 255)
INK = (20, 20, 18, 255)
FRAME = (253, 251, 246, 255)
FRAME_EDGE = (210, 199, 180, 255)
TITLE_FONT = "/System/Library/Fonts/NewYork.ttf"


@dataclass(frozen=True)
class NeighborCard:
    source: Path
    position: tuple[int, int]
    angle: float
    accent: tuple[int, int, int, int]
    width: int = 560


@dataclass(frozen=True)
class ScreenshotCard:
    source: Path
    title: str
    output: str
    main_position: tuple[int, int] = (112, 446)
    main_width: int = 1000
    neighbors: tuple[NeighborCard, ...] = ()


@dataclass(frozen=True)
class MarketingHero:
    source: str
    output: str
    main_width: int
    main_position: tuple[int, int]
    neighbor_width: int
    neighbor_position: tuple[int, int]
    neighbor_angle: float


CARDS = (
    ScreenshotCard(
        source=LEGACY_RAW / "iphone_01_today.png",
        title="Discover one object daily",
        output="01-today.png",
    ),
    ScreenshotCard(
        source=LEGACY_RAW / "iphone_03_full_archive.png",
        title="Explore the full archive",
        output="02-archive.png",
    ),
    ScreenshotCard(
        source=RAW / "02-collective.png",
        title="Explore what people create",
        output="03-collective.png",
    ),
    ScreenshotCard(
        source=LEGACY_RAW / "iphone_05_archive_browse.png",
        title="Browse themes and past weeks",
        output="04-browse.png",
    ),
    ScreenshotCard(
        source=RAW / "06-profile.png",
        title="Your saves and submissions",
        output="05-profile.png",
    ),
)

MARKETING_HEROES = (
    MarketingHero(
        source="HumanCollective-AppStore-Hero-iPhone-1242x2688.png",
        output="HumanCollective-AppStore-Hero-iPhone-v2-1242x2688.png",
        main_width=820,
        main_position=(108, 650),
        neighbor_width=610,
        neighbor_position=(835, 850),
        neighbor_angle=5.5,
    ),
    MarketingHero(
        source="HumanCollective-AppStore-Hero-iPad-2064x2752.png",
        output="HumanCollective-AppStore-Hero-iPad-v2-2064x2752.png",
        main_width=1050,
        main_position=(330, 620),
        neighbor_width=820,
        neighbor_position=(1280, 815),
        neighbor_angle=5.0,
    ),
    MarketingHero(
        source="HumanCollective-AppStore-Hero-v2.png",
        output="HumanCollective-AppStore-Hero-v3.png",
        main_width=600,
        main_position=(78, 470),
        neighbor_width=440,
        neighbor_position=(610, 640),
        neighbor_angle=5.5,
    ),
)


ARTIFACT_BACKGROUNDS = (
    "ArchiveFallbackURL_286b87b3c21689dd",
    "ArchiveFallbackURL_57482de970d3b9f3",
    "ArchiveFallbackURL_6fb640c6d3ee2139",
    "ArchiveFallbackURL_cbc6de254b88ee33",
    "ArchiveFallbackURL_d74904a883e9e585",
    "ArchiveFallbackURL_e26a2e1e5cbc09bb",
    "ArchiveFallback_15da2bf5-9976-06d3-a7e7-0a56446299d2",
    "ArchiveFallback_184f6f8d-60db-443b-447d-7e06f20653b9",
    "ArchiveFallback_2bfae1e6-8acc-693e-25c7-1d4d681f9ce7",
    "ArchiveFallback_5bf7744a-20b7-018c-0306-2e09ca626943",
    "ArchiveFallback_7764ac10-d914-b656-aff5-764889d04096",
    "ArchiveFallback_8c7ef82e-1cb1-9dc5-ff8a-dab29259049b",
    "ArchiveFallback_a1293f47-a0ee-1aad-453e-e8aefb0513fd",
    "ArchiveFallback_be169735-ea1c-7440-c438-bafd24021119",
    "ArchiveFallback_d790fdf8-7b1f-c24a-ce2b-ca0f3d5ed2f3",
    "ArchiveFallback_daa1fc28-5be3-f24d-a423-759f50063207",
    "ArchiveFallback_fb1f6add-bfa9-65af-5876-edade04d6b49",
    "ArchiveFallback_fe394433-14ae-89e0-136f-31cbdb390771",
)

PANORAMA_ROW_WIDTHS = (
    (980, 1120, 940, 1080, 1010, 1080),
    (1100, 900, 1060, 960, 1150, 1040),
    (900, 1050, 1120, 930, 1030, 1180),
)


def artifact_asset(name: str) -> Path:
    return ASSET_CATALOG / f"{name}.imageset" / f"{name}.jpg"


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1),
        radius=radius,
        fill=255,
    )
    return mask


def resize_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_width, target_height = size
    source_ratio = image.width / image.height
    target_ratio = target_width / target_height
    if source_ratio > target_ratio:
        height = target_height
        width = round(height * source_ratio)
    else:
        width = target_width
        height = round(width / source_ratio)
    resized = image.resize((width, height), Image.Resampling.LANCZOS)
    left = (width - target_width) // 2
    top = (height - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def make_artifact_panorama() -> tuple[Path, list[Path]]:
    panorama = Image.new("RGBA", PANORAMA_SIZE, (25, 22, 18, 255))
    row_height = PANORAMA_SIZE[1] // len(PANORAMA_ROW_WIDTHS)
    artifact_index = 0

    for row_index, widths in enumerate(PANORAMA_ROW_WIDTHS):
        cursor = 0
        row_top = row_index * row_height
        for column_index, width in enumerate(widths):
            overlap = 72
            left = max(0, cursor - overlap)
            right = min(PANORAMA_SIZE[0], cursor + width + overlap)
            top = max(0, row_top - 42)
            bottom = min(PANORAMA_SIZE[1], row_top + row_height + 42)
            tile_size = (right - left, bottom - top)

            source = Image.open(
                artifact_asset(ARTIFACT_BACKGROUNDS[artifact_index])
            ).convert("RGB")
            source = resize_cover(source, tile_size)
            source = ImageEnhance.Color(source).enhance(0.92)
            source = ImageEnhance.Contrast(source).enhance(1.08)
            tile = source.convert("RGBA")

            slant = 74 if (row_index + column_index) % 2 == 0 else -74
            mask = Image.new("L", tile_size, 0)
            mask_draw = ImageDraw.Draw(mask)
            if slant > 0:
                corners = (
                    (slant, 0),
                    (tile_size[0], 0),
                    (tile_size[0] - slant, tile_size[1]),
                    (0, tile_size[1]),
                )
            else:
                offset = abs(slant)
                corners = (
                    (0, 0),
                    (tile_size[0] - offset, 0),
                    (tile_size[0], tile_size[1]),
                    (offset, tile_size[1]),
                )
            mask_draw.polygon(corners, fill=255)
            tile.putalpha(mask)
            panorama.alpha_composite(tile, (left, top))

            cursor += width
            artifact_index += 1

    # A unified grade makes the individual museum images read as one panorama.
    panorama.alpha_composite(Image.new("RGBA", PANORAMA_SIZE, (28, 19, 12, 72)))
    warm = Image.new("RGBA", PANORAMA_SIZE, (118, 70, 36, 0))
    warm_alpha = warm.getchannel("A")
    warm_alpha.paste(28, (0, 0, PANORAMA_SIZE[0], PANORAMA_SIZE[1]))
    warm.putalpha(warm_alpha)
    panorama.alpha_composite(warm)

    BACKGROUNDS.mkdir(parents=True, exist_ok=True)
    panorama_path = BACKGROUNDS / "artifact-panorama.png"
    panorama.convert("RGB").save(panorama_path, format="PNG", optimize=True)

    slices: list[Path] = []
    for index in range(5):
        left = index * CANVAS_SIZE[0]
        card_slice = panorama.crop(
            (left, 0, left + CANVAS_SIZE[0], CANVAS_SIZE[1])
        )
        slice_path = BACKGROUNDS / f"artifact-panorama-{index + 1:02}.png"
        card_slice.convert("RGB").save(slice_path, format="PNG", optimize=True)
        slices.append(slice_path)

    return panorama_path, slices


def add_card_background_veil(canvas: Image.Image) -> None:
    canvas.alpha_composite(Image.new("RGBA", CANVAS_SIZE, (12, 10, 8, 52)))

    gradient_height = 520
    gradient = Image.new("RGBA", (CANVAS_SIZE[0], gradient_height))
    pixels = gradient.load()
    for y in range(gradient_height):
        progress = y / max(1, gradient_height - 1)
        alpha = round(136 * (1 - progress) ** 1.65)
        for x in range(CANVAS_SIZE[0]):
            pixels[x, y] = (9, 8, 7, alpha)
    canvas.alpha_composite(gradient, (0, 0))


def screen_panel(
    source: Path,
    screen_size: tuple[int, int],
    radius: int,
    edge: tuple[int, int, int, int],
    border: int,
) -> Image.Image:
    screenshot = Image.open(source).convert("RGBA")
    screenshot = resize_cover(screenshot, screen_size)
    panel = Image.new("RGBA", (screen_size[0] + border * 2, screen_size[1] + border * 2))
    draw = ImageDraw.Draw(panel)
    draw.rounded_rectangle(
        (0, 0, panel.width - 1, panel.height - 1),
        radius=radius + border,
        fill=FRAME,
        outline=edge,
        width=max(3, border // 2),
    )
    panel.alpha_composite(
        Image.composite(
            screenshot,
            Image.new("RGBA", screen_size),
            rounded_mask(screen_size, radius),
        ),
        (border, border),
    )
    return panel


def add_shadowed_panel(
    canvas: Image.Image,
    panel: Image.Image,
    position: tuple[int, int],
    angle: float = 0,
    blur: int = 25,
    opacity: int = 68,
) -> None:
    if angle:
        panel = panel.rotate(
            angle,
            resample=Image.Resampling.BICUBIC,
            expand=True,
        )
    shadow = Image.new("RGBA", panel.size)
    alpha = panel.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    shadow.putalpha(alpha.point(lambda value: value * opacity // 255))
    canvas.alpha_composite(shadow, (position[0] + 6, position[1] + 18))
    canvas.alpha_composite(panel, position)


def add_logo(canvas: Image.Image) -> None:
    tile_size = 164
    tile_position = ((CANVAS_SIZE[0] - tile_size) // 2, 72)
    shadow = Image.new("RGBA", CANVAS_SIZE)
    shadow_draw = ImageDraw.Draw(shadow)
    x, y = tile_position
    shadow_draw.rounded_rectangle(
        (x, y, x + tile_size, y + tile_size),
        radius=36,
        fill=(65, 51, 33, 76),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))

    tile = Image.new("RGBA", (tile_size, tile_size))
    ImageDraw.Draw(tile).rounded_rectangle(
        (0, 0, tile_size - 1, tile_size - 1),
        radius=35,
        fill=(255, 254, 251, 255),
        outline=FRAME_EDGE,
        width=3,
    )
    icon_size = 136
    icon = Image.open(APP_ICON).convert("RGBA").resize(
        (icon_size, icon_size),
        Image.Resampling.LANCZOS,
    )
    tile.alpha_composite(
        Image.composite(
            icon,
            Image.new("RGBA", (icon_size, icon_size)),
            rounded_mask((icon_size, icon_size), 28),
        ),
        ((tile_size - icon_size) // 2, (tile_size - icon_size) // 2),
    )
    canvas.alpha_composite(tile, tile_position)


def add_title(canvas: Image.Image, title: str) -> None:
    draw = ImageDraw.Draw(canvas)
    font_size = 88
    font = ImageFont.truetype(TITLE_FONT, font_size)
    maximum_width = CANVAS_SIZE[0] - 128
    while draw.textlength(title, font=font) > maximum_width:
        font_size -= 1
        font = ImageFont.truetype(TITLE_FONT, font_size)
    width = draw.textlength(title, font=font)
    position = ((CANVAS_SIZE[0] - width) / 2, 270)
    draw.text(
        (position[0] + 3, position[1] + 5),
        title,
        font=font,
        fill=(0, 0, 0, 155),
    )
    draw.text(position, title, font=font, fill=(255, 252, 245, 255))


def add_marketing_header(canvas: Image.Image) -> None:
    width, height = canvas.size
    gradient_height = min(round(height * 0.29), 760)
    gradient = Image.new("RGBA", (width, gradient_height))
    gradient_pixels = gradient.load()
    for y in range(gradient_height):
        progress = y / max(1, gradient_height - 1)
        alpha = round(158 * (1 - progress) ** 1.7)
        for x in range(width):
            gradient_pixels[x, y] = (12, 11, 10, alpha)
    canvas.alpha_composite(gradient, (0, 0))

    tile_size = max(118, min(190, round(width * 0.132)))
    tile_position = ((width - tile_size) // 2, round(height * 0.026))
    tile_shadow = Image.new("RGBA", canvas.size)
    x, y = tile_position
    ImageDraw.Draw(tile_shadow).rounded_rectangle(
        (x, y, x + tile_size, y + tile_size),
        radius=round(tile_size * 0.22),
        fill=(0, 0, 0, 96),
    )
    canvas.alpha_composite(
        tile_shadow.filter(ImageFilter.GaussianBlur(max(14, tile_size // 10)))
    )

    icon = Image.open(APP_ICON).convert("RGBA").resize(
        (tile_size, tile_size),
        Image.Resampling.LANCZOS,
    )
    canvas.alpha_composite(
        Image.composite(
            icon,
            Image.new("RGBA", (tile_size, tile_size)),
            rounded_mask((tile_size, tile_size), round(tile_size * 0.22)),
        ),
        tile_position,
    )

    draw = ImageDraw.Draw(canvas)
    font_size = max(72, round(width * 0.096))
    font = ImageFont.truetype(TITLE_FONT, font_size)
    title = "Human Collective"
    maximum_width = width - round(width * 0.12)
    while draw.textlength(title, font=font) > maximum_width:
        font_size -= 1
        font = ImageFont.truetype(TITLE_FONT, font_size)
    text_width = draw.textlength(title, font=font)
    text_y = tile_position[1] + tile_size + round(height * 0.018)
    text_position = ((width - text_width) / 2, text_y)
    draw.text(
        (text_position[0] + 3, text_position[1] + 5),
        title,
        font=font,
        fill=(0, 0, 0, 130),
    )
    draw.text(text_position, title, font=font, fill=(255, 252, 245, 255))


def make_card(card: ScreenshotCard, background: Path) -> Path:
    canvas = Image.open(background).convert("RGBA")
    add_card_background_veil(canvas)
    add_logo(canvas)
    add_title(canvas, card.title)

    for neighbor_card in card.neighbors:
        neighbor_height = round(neighbor_card.width * 2868 / 1320)
        neighbor = screen_panel(
            neighbor_card.source,
            (neighbor_card.width, neighbor_height),
            radius=max(38, round(neighbor_card.width * 0.075)),
            edge=neighbor_card.accent,
            border=13,
        )
        add_shadowed_panel(
            canvas,
            neighbor,
            neighbor_card.position,
            angle=neighbor_card.angle,
            blur=22,
            opacity=58,
        )

    main_height = round(card.main_width * 2868 / 1320)
    main = screen_panel(
        card.source,
        (card.main_width, main_height),
        radius=59,
        edge=FRAME_EDGE,
        border=9,
    )
    add_shadowed_panel(
        canvas,
        main,
        card.main_position,
        blur=28,
        opacity=72,
    )

    FULL_SET_OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = FULL_SET_OUTPUT / card.output
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)
    return destination


def make_contact_sheet(paths: list[Path]) -> Path:
    thumbnail_width = 330
    thumbnail_height = round(thumbnail_width * CANVAS_SIZE[1] / CANVAS_SIZE[0])
    gap = 22
    margin = 28
    sheet = Image.new(
        "RGB",
        (
            margin * 2 + thumbnail_width * len(paths) + gap * (len(paths) - 1),
            margin * 2 + thumbnail_height,
        ),
        (242, 242, 239),
    )
    for index, path in enumerate(paths):
        thumbnail = Image.open(path).convert("RGB").resize(
            (thumbnail_width, thumbnail_height),
            Image.Resampling.LANCZOS,
        )
        sheet.paste(thumbnail, (margin + index * (thumbnail_width + gap), margin))
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    destination = PREVIEWS / "iphone-6.5-full-set.png"
    sheet.save(destination, format="PNG", optimize=True)
    return destination


def make_marketing_hero(hero: MarketingHero) -> Path:
    canvas = Image.open(MARKETING / hero.source).convert("RGBA")
    add_marketing_header(canvas)

    neighbor_height = round(hero.neighbor_width * 2868 / 1320)
    neighbor_border = max(9, round(hero.neighbor_width * 0.016))
    neighbor = screen_panel(
        RAW / "06-profile.png",
        (hero.neighbor_width, neighbor_height),
        radius=max(34, round(hero.neighbor_width * 0.06)),
        edge=(186, 119, 57, 255),
        border=neighbor_border,
    )
    add_shadowed_panel(
        canvas,
        neighbor,
        hero.neighbor_position,
        angle=hero.neighbor_angle,
        blur=max(20, round(hero.neighbor_width * 0.035)),
        opacity=86,
    )

    main_height = round(hero.main_width * 2868 / 1320)
    main_border = max(10, round(hero.main_width * 0.014))
    main = screen_panel(
        RAW / "02-collective.png",
        (hero.main_width, main_height),
        radius=max(38, round(hero.main_width * 0.058)),
        edge=(75, 101, 119, 255),
        border=main_border,
    )
    add_shadowed_panel(
        canvas,
        main,
        hero.main_position,
        blur=max(22, round(hero.main_width * 0.035)),
        opacity=96,
    )

    destination = MARKETING / hero.output
    canvas.convert("RGB").save(destination, format="PNG", optimize=True)
    return destination


def main() -> int:
    panorama_path, background_slices = make_artifact_panorama()
    print(panorama_path)
    card_paths: list[Path] = []
    for card, background in zip(CARDS, background_slices):
        destination = make_card(card, background)
        card_paths.append(destination)
        print(destination)
    print(make_contact_sheet(card_paths))
    for hero in MARKETING_HEROES:
        destination = make_marketing_hero(hero)
        print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
