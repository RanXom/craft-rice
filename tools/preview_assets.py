#!/usr/bin/env python3
"""Render previews of the bundled Monocraft font and JuxCursor cursor theme.

Nothing is installed: files are read straight out of assets/ and PNGs are
written to an output directory. Requires Pillow (PIL) for image rendering.

Usage:
    python3 tools/preview_assets.py [all|font|cursor] [--out DIR] [--individual]
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
import tarfile
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - exercised only on machines without Pillow
    sys.stderr.write(
        "craft-rice preview: Pillow is required for image previews.\n"
        "  Arch:    sudo pacman -S python-pillow\n"
        "  Fedora:  sudo dnf install python3-pillow\n"
        "  Debian:  sudo apt install python3-pil\n"
        "  openSUSE: sudo zypper install python3-Pillow\n"
        "  Or use any distro's python-pillow package.\n"
    )
    raise SystemExit(1)

REPO = Path(__file__).resolve().parent.parent
DATA_HOME = Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share"))

# Prefer the repository assets. Fall back to what `craft-rice install` placed
# in ~/.local/share, so `craft-rice preview` also works after the clone is gone.
_FONT_CANDIDATES = [
    REPO / "assets" / "fonts" / "Monocraft-nerd-fonts-patched.ttc",
    DATA_HOME / "fonts" / "Monocraft.ttc",
]
FONT_FILE = next((path for path in _FONT_CANDIDATES if path.is_file()), _FONT_CANDIDATES[0])

_CURSOR_ARCHIVE = REPO / "assets" / "cursors" / "JuxCursor.tar.gz"
CURSOR_ARCHIVE = _CURSOR_ARCHIVE if _CURSOR_ARCHIVE.is_file() else None
INSTALLED_CURSORS = DATA_HOME / "icons" / "JuxCursor" / "cursors"

BG = (16, 17, 23)
PANEL = (24, 26, 34)
BORDER = (43, 46, 58)
TEXT = (232, 233, 242)
MUTED = (140, 143, 160)
DIM = (96, 99, 116)
ACCENT = (126, 207, 166)
ACCENT2 = (238, 179, 123)
STRING = (166, 218, 154)
COMMENT = (110, 113, 130)

# Cursors worth showing on the contact sheet, in reading order.
SHEET_CURSORS = [
    "left_ptr",
    "hand2",
    "ibeam",
    "crosshair",
    "fleur",
    "grab",
    "grabbing",
    "h_double_arrow",
    "v_double_arrow",
    "nesw-resize",
    "nwse-resize",
    "not-allowed",
    "left_ptr_watch",
    "wait",
    "progress",
    "move",
    "text",
    "pointer",
    "col-resize",
    "all-scroll",
]


# ---------------------------------------------------------------------------
# Font preview
# ---------------------------------------------------------------------------


def face(path: Path, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size, index=index)


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str) -> None:
    draw.text(xy, text, font=face(FONT_FILE, 14, 5), fill=DIM)


def make_font_preview(out: Path) -> Path:
    if not FONT_FILE.is_file():
        raise SystemExit(f"font not found: {FONT_FILE}")

    width, height = 1600, 1270
    image = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(image)
    margin = 64

    # Header.
    draw.text((margin, 38), "Monocraft", font=face(FONT_FILE, 72, 2), fill=TEXT)
    draw.text(
        (margin, 132),
        "Nerd Fonts patched  ·  bundled with craft-rice  ·  preview only",
        font=face(FONT_FILE, 20, 0),
        fill=MUTED,
    )
    draw.text(
        (width - margin, 54),
        "craft-rice",
        font=face(FONT_FILE, 22, 0),
        fill=ACCENT,
        anchor="ra",
    )
    draw.text(
        (width - margin, 88),
        "no Nix · no install needed",
        font=face(FONT_FILE, 16, 0),
        fill=DIM,
        anchor="ra",
    )
    draw.line((margin, 178, width - margin, 178), fill=BORDER, width=1)

    # Alphabet.
    y = 206
    label(draw, (margin, y), "ALPHABET")
    alpha_font = face(FONT_FILE, 24, 0)
    draw.text(
        (margin, y + 24),
        "abcdefghijklmnopqrstuvwxyz  ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        font=alpha_font,
        fill=TEXT,
    )
    draw.text(
        (margin, y + 58),
        "0123456789  !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
        font=alpha_font,
        fill=TEXT,
    )

    # Ligatures.
    y = 330
    label(draw, (margin, y), "LIGATURES")
    draw.text(
        (margin, y + 24),
        "!=  ==  ===  !==  <=  >=  ->  =>  <-  <|  |>  ::  ++  --  //  /* */",
        font=face(FONT_FILE, 30, 0),
        fill=ACCENT,
    )

    # Code sample.
    y = 414
    label(draw, (margin, y), "IN A TERMINAL")
    box = (margin, y + 24, width - margin, y + 264)
    draw.rounded_rectangle(box, radius=12, fill=(11, 12, 16), outline=BORDER, width=1)
    draw.ellipse((margin + 18, y + 42, margin + 30, y + 54), fill=(224, 108, 108))
    draw.ellipse((margin + 38, y + 42, margin + 50, y + 54), fill=(224, 186, 108))
    draw.ellipse((margin + 58, y + 42, margin + 70, y + 54), fill=(126, 196, 126))
    draw.text(
        (margin + 84, y + 38),
        "~/src/craft-rice",
        font=face(FONT_FILE, 14, 0),
        fill=DIM,
    )

    code = face(FONT_FILE, 21, 0)
    x = margin + 26
    line_y = y + 84
    draw.text((x, line_y), "$ ./install.sh --dry-run", font=code, fill=TEXT)
    draw.text((x, line_y + 32), "$ craft-rice preview", font=code, fill=TEXT)
    draw.text((x, line_y + 64), "# Monocraft is now in your fontconfig", font=code, fill=COMMENT)
    draw.text((x, line_y + 96), "# ...but nothing was installed.", font=code, fill=COMMENT)
    draw.text((x, line_y + 128), "if preview then install else undo", font=code, fill=ACCENT2)

    # Styles.
    y = 726
    label(draw, (margin, y), "STYLES")
    styles = [(0, "Regular"), (1, "Italic"), (4, "Bold"), (2, "Black")]
    style_x = margin
    for index, name in styles:
        f = face(FONT_FILE, 28, index)
        sample = "Sphinx 0123"
        draw.text((style_x, y + 26), sample, font=f, fill=TEXT)
        draw.text((style_x, y + 66), name, font=face(FONT_FILE, 13, 0), fill=DIM)
        style_x += 360

    # Glyphs.
    y = 830
    label(draw, (margin, y), "GLYPHS")
    glyph_font = face(FONT_FILE, 30, 0)
    rows = [
        ("░▒▓█  ▁▂▃▄▅▆▇  ████████", TEXT),
        ("→ ← ↑ ↓  ● ○ ◆ ◇ ★ ☆  ⚡ ♥ ⚑", TEXT),
        ("\uf015 \uf07b \uf001 \uf09b \uf120 \uf17c \uf303 \uf002 \uf011 \uf1eb \uf240 \uf017 \uf121 \ue73c \uf313", ACCENT),
        ("\ue0b0 \ue0b0 \ue0b0  \ue0b2 \ue0b2 \ue0b2  \ue725 \ue702 \uf2d0", ACCENT),
    ]
    line_y = y + 24
    for text, colour in rows:
        draw.text((margin, line_y), text, font=glyph_font, fill=colour)
        line_y += 42

    # Size ramp.
    y = 1042
    label(draw, (margin, y), "SIZES")
    sizes = [14, 18, 22, 28, 36, 48]
    size_x = margin
    for size in sizes:
        f = face(FONT_FILE, size, 0)
        draw.text((size_x, y + 26), "Ag", font=f, fill=TEXT)
        draw.text((size_x, y + 26 + size + 6), f"{size}px", font=face(FONT_FILE, 12, 0), fill=DIM)
        size_x += 250

    draw.line((margin, height - 52, width - margin, height - 52), fill=BORDER, width=1)
    draw.text(
        (margin, height - 38),
        "assets/fonts/Monocraft-nerd-fonts-patched.ttc",
        font=face(FONT_FILE, 13, 0),
        fill=DIM,
    )
    draw.text(
        (width - margin, height - 38),
        "preview only — nothing was installed",
        font=face(FONT_FILE, 13, 0),
        fill=ACCENT,
        anchor="ra",
    )

    path = out / "font-monocraft.png"
    image.save(path)
    return path


# ---------------------------------------------------------------------------
# Xcursor parser (stdlib only, but rendering uses Pillow)
# ---------------------------------------------------------------------------

IMAGE_TYPE = 0xFFFD0002


def parse_xcursor(path: Path) -> list[dict]:
    """Return every image inside an Xcursor file."""
    data = path.read_bytes()
    if len(data) < 16 or data[:4] != b"Xcur":
        raise ValueError(f"not an Xcursor file: {path}")
    header, _version, ntoc = struct.unpack_from("<III", data, 4)
    images = []
    for i in range(ntoc):
        toc_type, subtype, position = struct.unpack_from("<III", data, header + i * 12)
        if toc_type != IMAGE_TYPE:
            continue
        (
            _chunk_header,
            _chunk_type,
            _chunk_subtype,
            _chunk_version,
            width,
            height,
            xhot,
            yhot,
            delay,
        ) = struct.unpack_from("<IIIIIIIII", data, position)
        pixel_count = width * height
        pixels = struct.unpack_from(f"<{pixel_count}I", data, position + 36)
        rgba = bytearray(pixel_count * 4)
        for j, pixel in enumerate(pixels):
            rgba[j * 4 + 0] = (pixel >> 16) & 0xFF
            rgba[j * 4 + 1] = (pixel >> 8) & 0xFF
            rgba[j * 4 + 2] = pixel & 0xFF
            rgba[j * 4 + 3] = (pixel >> 24) & 0xFF
        images.append(
            {
                "nominal": subtype,
                "width": width,
                "height": height,
                "xhot": xhot,
                "yhot": yhot,
                "delay": delay,
                "image": Image.frombytes("RGBA", (width, height), bytes(rgba)),
            }
        )
    if not images:
        raise ValueError(f"no images in {path}")
    return images


def pick_image(images: list[dict], preferred: int = 96) -> dict:
    return min(images, key=lambda item: (abs(item["nominal"] - preferred), -item["nominal"]))


def ensure_cursor_dir(out: Path) -> Path:
    """Prefer the bundled archive, then the cursors installed by craft-rice."""
    if CURSOR_ARCHIVE is None:
        if INSTALLED_CURSORS.is_dir():
            return INSTALLED_CURSORS
        raise SystemExit(
            "cursor source not found. Run from the craft-rice repository or install the rice first."
        )
    target = out / "cursor-files"
    directory = target / "JuxCursor" / "cursors"
    if directory.is_dir():
        return directory
    target.mkdir(parents=True, exist_ok=True)
    with tarfile.open(CURSOR_ARCHIVE, "r:gz") as archive:
        try:
            archive.extractall(target, filter="data")  # Python >= 3.12
        except TypeError:  # pragma: no cover - older Python
            archive.extractall(target)
    if not directory.is_dir():
        raise SystemExit(f"unexpected cursor archive layout: {CURSOR_ARCHIVE}")
    return directory


def checker(size: tuple[int, int], cell: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            colour = (46, 48, 58, 255) if ((x // cell) + (y // cell)) % 2 else (36, 38, 46, 255)
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=colour)
    return image


def paste_cursor(
    canvas: Image.Image,
    images: list[dict],
    centre: tuple[int, int],
    box: int,
    hotspot: bool = False,
) -> None:
    chosen = pick_image(images, box)
    cursor = chosen["image"]
    scale = max(1.0, box / max(cursor.width, cursor.height))
    size = (max(1, round(cursor.width * scale)), max(1, round(cursor.height * scale)))
    scaled = cursor.resize(size, Image.LANCZOS)

    target = (centre[0] - size[0] // 2, centre[1] - size[1] // 2)
    canvas.alpha_composite(scaled, target)

    if hotspot:
        hx = target[0] + round(chosen["xhot"] * scale)
        hy = target[1] + round(chosen["yhot"] * scale)
        draw = ImageDraw.Draw(canvas)
        draw.ellipse((hx - 5, hy - 5, hx + 5, hy + 5), outline=(240, 96, 96, 230), width=1)
        draw.line((hx - 8, hy, hx + 8, hy), fill=(240, 96, 96, 160), width=1)
        draw.line((hx, hy - 8, hx, hy + 8), fill=(240, 96, 96, 160), width=1)


def make_cursor_sheet(out: Path) -> Path:
    cursor_dir = ensure_cursor_dir(out)
    available = {p.name for p in cursor_dir.iterdir() if p.is_file()}
    names = [name for name in SHEET_CURSORS if name in available]
    if not names:
        raise SystemExit(f"no cursor files in {cursor_dir}")
    missing = [name for name in SHEET_CURSORS if name not in available]

    columns = 5
    cell_w, cell_h = 280, 280
    margin = 48
    header = 112
    rows = (len(names) + columns - 1) // columns
    width = margin * 2 + columns * cell_w
    height = header + rows * cell_h + margin

    image = Image.new("RGBA", (width, height), BG + (255,))
    draw = ImageDraw.Draw(image)

    draw.text((margin, 34), "JuxCursor", font=face(FONT_FILE, 54, 2), fill=TEXT)
    draw.text(
        (margin, 92),
        "bundled cursor theme  ·  preview only  ·  red ring = hotspot",
        font=face(FONT_FILE, 18, 0),
        fill=MUTED,
    )
    draw.text(
        (width - margin, 40),
        "craft-rice",
        font=face(FONT_FILE, 20, 0),
        fill=ACCENT,
        anchor="ra",
    )
    draw.text(
        (width - margin, 70),
        f"{len(available)} cursors, 24–96px",
        font=face(FONT_FILE, 15, 0),
        fill=DIM,
        anchor="ra",
    )

    for index, name in enumerate(names):
        row, column = divmod(index, columns)
        x = margin + column * cell_w
        y = header + row * cell_h
        draw.rounded_rectangle(
            (x + 8, y + 8, x + cell_w - 8, y + cell_h - 8),
            radius=14,
            fill=PANEL,
            outline=BORDER,
            width=1,
        )
        tile = checker((cell_w - 32, 156), 10)
        image.paste(tile, (x + 16, y + 16), tile)

        try:
            images = parse_xcursor(cursor_dir / name)
        except (ValueError, struct.error) as error:
            draw.text((x + 24, y + 74), f"unreadable: {error}", font=face(FONT_FILE, 12, 0), fill=(224, 108, 108))
            continue

        paste_cursor(image, images, (x + cell_w // 2, y + 94), 108, hotspot=True)

        chosen = pick_image(images, 96)
        draw.text(
            (x + cell_w // 2, y + 188),
            name,
            font=face(FONT_FILE, 16, 0),
            fill=TEXT,
            anchor="ma",
        )
        draw.text(
            (x + cell_w // 2, y + 214),
            f"{chosen['nominal']}px · hotspot {chosen['xhot']},{chosen['yhot']}",
            font=face(FONT_FILE, 11, 0),
            fill=DIM,
            anchor="ma",
        )

    draw.text(
        (margin, height - 34),
        "extracted from assets/cursors/JuxCursor.tar.gz — nothing was installed",
        font=face(FONT_FILE, 12, 0),
        fill=DIM,
    )
    if missing:
        draw.text(
            (width - margin, height - 34),
            f"missing: {', '.join(missing)}",
            font=face(FONT_FILE, 12, 0),
            fill=(224, 108, 108),
            anchor="ra",
        )

    path = out / "cursors-sheet.png"
    image.convert("RGB").save(path)
    return path


def make_cursor_images(out: Path, scale: int = 2) -> list[Path]:
    cursor_dir = ensure_cursor_dir(out)
    target = out / "cursors"
    target.mkdir(parents=True, exist_ok=True)
    written = []
    for cursor_path in sorted(cursor_dir.iterdir()):
        if not cursor_path.is_file():
            continue
        try:
            images = parse_xcursor(cursor_path)
        except (ValueError, struct.error):
            continue
        chosen = pick_image(images, 96)
        cursor = chosen["image"]
        if scale != 1:
            cursor = cursor.resize((cursor.width * scale, cursor.height * scale), Image.LANCZOS)
        path = target / f"{cursor_path.name}.png"
        cursor.save(path)
        written.append(path)
    return written


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def default_out() -> Path:
    cache = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(cache) / "craft-rice" / "preview"


def main() -> int:
    parser = argparse.ArgumentParser(description="Preview bundled craft-rice assets without installing them.")
    parser.add_argument("what", nargs="?", default="all", choices=["all", "font", "cursor"])
    parser.add_argument("--out", type=Path, default=None, help="output directory (default: XDG cache)")
    parser.add_argument("--individual", action="store_true", help="also write one PNG per cursor")
    args = parser.parse_args()

    if not FONT_FILE.is_file():
        sys.stderr.write(
            "craft-rice preview: Monocraft not found.\n"
            "  Run this from the craft-rice repository, or install the rice first.\n"
        )
        return 1

    out = (args.out or default_out()).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    if args.what in ("all", "font"):
        written.append(make_font_preview(out))
    if args.what in ("all", "cursor"):
        written.append(make_cursor_sheet(out))
        if args.individual:
            written.extend(make_cursor_images(out))

    print(f"Preview written to {out}")
    for path in written:
        print(f"  {path}")
    if args.what in ("all", "cursor") and not args.individual:
        print("  (add --individual to write one PNG per cursor)")
    print("Nothing was installed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
