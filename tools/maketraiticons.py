# -*- coding: utf-8 -*-
"""Draw the trait icons into SHAW/42/media/ui/Traits/.

    python tools/maketraiticons.py

Requires Pillow. Placeholders: a coloured disc with one or two letters, drawn
deterministically rather than generated, because LICENSE section 4 bars
AI-generated image assets. Replace them with real art when there is some.

WHY THESE EXIST AT ALL. A trait with no texture is invisible in both panels
that list traits - ISCharacterScreen.setDisplayedTraits and
ISPlayerStatsUI.loadTraits both skip any definition whose getTexture() is nil.
The engine's documented fallback, media/ui/Traits/trait_generic.png, is
referenced in CharacterTraitDefinition but **does not ship** - the folder holds
only 16 icons for ~90 vanilla traits, which is why most vanilla traits are
invisible there too. So a mod that wants its traits to show has to supply art.

32x32 matches the vanilla icons.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 32

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "SHAW", "42", "media", "ui", "Traits")

FONTS = (
    "C:/Windows/Fonts/seguibl.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/bahnschrift.ttf",
)

# id -> (letters, colour). Colours group by what the trait does to you:
# red = collapse, amber = chronic, violet = mind, green = body/immune.
TRAITS = {
    "epileptic":         ("EP", "#B4462F"),
    "narcoleptic":       ("NA", "#B4462F"),
    "neuralgia":         ("NE", "#B4462F"),
    "ehlersdanlos":      ("ED", "#C08A3E"),
    "arthritis":         ("AR", "#C08A3E"),
    "asthmatic":         ("AS", "#C08A3E"),
    "diabetic":          ("DI", "#4A8C7B"),
    "immunocompromised": ("IM", "#4A8C7B"),
    "allergy":           ("AL", "#4A8C7B"),
    "depressive":        ("DE", "#6E6BA8"),
    "adhd":              ("AD", "#6E6BA8"),
    "tourette":          ("TO", "#6E6BA8"),
    "colorblind":        ("CB", "#7A7A7A"),
}


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def draw(letters, colour):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pen = ImageDraw.Draw(img)

    pen.ellipse([1, 1, SIZE - 2, SIZE - 2], fill=colour, outline="#12141A", width=2)

    fnt = font(15)
    left, top, right, bottom = pen.textbbox((0, 0), letters, font=fnt)
    x = (SIZE - (right - left)) / 2 - left
    y = (SIZE - (bottom - top)) / 2 - top
    pen.text((x, y), letters, font=fnt, fill="#F2EDE6")

    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for trait_id, (letters, colour) in sorted(TRAITS.items()):
        path = os.path.join(OUT, "trait_SHAW_%s.png" % trait_id)
        draw(letters, colour).save(path, "PNG")
        print("wrote %s" % os.path.basename(path))
    print("%d icons in %s" % (len(TRAITS), OUT))


if __name__ == "__main__":
    sys.exit(main())
