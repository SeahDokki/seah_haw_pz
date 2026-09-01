# -*- coding: utf-8 -*-
"""Draw SHAW/preview.png - the 256x256 Workshop thumbnail.

    python tools/makepreview.py

Requires Pillow. This is a placeholder: flat colour, short code, title.
It is drawn deterministically rather than generated, because LICENSE
section 4 bars AI-generated image assets. Replace preview.png with real
artwork when there is some; re-running this overwrites it.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 256
ACCENT = "#B4462F"
GROUND = "#2A1A17"
SHORT = "H:AW"
TITLE_TOP = "HUMANS"
TITLE_BOTTOM = "ARE WEAK"

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "SHAW", "preview.png")

FONTS = (
    "C:/Windows/Fonts/bahnschrift.ttf",
    "C:/Windows/Fonts/seguibl.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
)


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def centre(draw, text, fnt, y, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=fnt)
    draw.text(((SIZE - (right - left)) / 2 - left, y - top), text,
              font=fnt, fill=fill)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), GROUND)
    draw = ImageDraw.Draw(img)

    # A band behind the short code, and a rule under the title.
    draw.rectangle([0, 74, SIZE, 150], fill=ACCENT)
    draw.rectangle([0, 150, SIZE, 154], fill="#0E0F12")

    centre(draw, "PROJECT ZOMBOID", font(15), 28, "#6A635C")
    centre(draw, "BUILD 42", font(15), 48, "#6A635C")
    centre(draw, SHORT, font(62), 84, "#F2EDE6")
    centre(draw, TITLE_TOP, font(23), 172, "#CFC7BC")
    centre(draw, TITLE_BOTTOM, font(23), 198, ACCENT)

    # Inner keyline, so the tile reads as deliberate at gallery size.
    draw.rectangle([3, 3, SIZE - 4, SIZE - 4], outline="#000000", width=2)

    img.save(OUT, "PNG")
    print("wrote %s (%dx%d)" % (OUT, SIZE, SIZE))


if __name__ == "__main__":
    sys.exit(main())
