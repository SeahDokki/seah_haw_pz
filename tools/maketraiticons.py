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

18x18 matches the vanilla icons exactly, and that matters: both panels build
the image at the texture's native size - ISImage:new(0, 0, tex:getWidth(),
tex:getHeight(), tex) - so a 32x32 icon renders 32px tall in a row laid out
for 18px and overflows next to the vanilla ones. At this size a single letter
is all that fits; the colour family carries the rest.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SIZE = 18

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "SHAW", "42", "media", "ui", "Traits")

FONTS = (
    "C:/Windows/Fonts/seguibl.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
    "C:/Windows/Fonts/bahnschrift.ttf",
)

# id -> (letter, colour). One letter each - 18x18 fits no more - and all 13 are
# distinct. Colour groups by what the trait does to you: red = it drops you,
# amber = chronic ache, green = body and immunity, violet = mind.
TRAITS = {
    "epileptic":         ("E", "#B4462F"),
    "narcoleptic":       ("N", "#B4462F"),
    "neuralgia":         ("P", "#B4462F"),
    "ehlersdanlos":      ("H", "#C08A3E"),
    "arthritis":         ("R", "#C08A3E"),
    "asthmatic":         ("S", "#C08A3E"),
    "diabetic":          ("D", "#4A8C7B"),
    "immunocompromised": ("I", "#4A8C7B"),
    "allergy":           ("L", "#4A8C7B"),
    "depressive":        ("V", "#6E6BA8"),
    "adhd":              ("A", "#6E6BA8"),
    "tourette":          ("T", "#6E6BA8"),
    "colorblind":        ("C", "#7A7A7A"),
}


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def draw(letter, colour):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pen = ImageDraw.Draw(img)

    pen.ellipse([0, 0, SIZE - 1, SIZE - 1], fill=colour, outline="#12141A", width=1)

    fnt = font(11)
    left, top, right, bottom = pen.textbbox((0, 0), letter, font=fnt)
    x = (SIZE - (right - left)) / 2 - left
    y = (SIZE - (bottom - top)) / 2 - top
    pen.text((x, y), letter, font=fnt, fill="#F2EDE6")

    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for trait_id, (letter, colour) in sorted(TRAITS.items()):
        path = os.path.join(OUT, "trait_SHAW_%s.png" % trait_id)
        draw(letter, colour).save(path, "PNG")
        print("wrote %s" % os.path.basename(path))
    print("%d icons in %s" % (len(TRAITS), OUT))


if __name__ == "__main__":
    sys.exit(main())
