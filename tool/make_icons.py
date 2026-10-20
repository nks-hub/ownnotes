#!/usr/bin/env python3
"""Draws the OwnNotes icon and writes every launcher/App Store size in place.

    py -3 tool/make_icons.py

Each existing icon file is overwritten at its current pixel size, so the
Android mipmaps and the iOS asset catalogue stay exactly as Flutter laid
them out. Also writes apps/mobile/assets/brand/play-store-icon.png (512 px)
and docs/store/feature-graphic.png (1024 × 500).
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1] / "apps/mobile"
BRAND = (49, 91, 119)  # the app's seed colour, 0xff315b77
FOLD = (169, 199, 219)
SIZE = 1024


def master(rounded: bool) -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if rounded:
        draw.rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), 224, fill=BRAND)
    else:
        draw.rectangle((0, 0, SIZE, SIZE), fill=BRAND)
    left, top, right, bottom, fold = 272, 200, 752, 824, 150
    draw.polygon(
        [(left, top), (right - fold, top), (right, top + fold),
         (right, bottom), (left, bottom)],
        fill="white",
    )
    draw.polygon(
        [(right - fold, top), (right - fold, top + fold), (right, top + fold)],
        fill=FOLD,
    )
    for y, end in ((450, 672), (550, 672), (650, 560)):
        draw.rounded_rectangle((352, y - 18, end, y + 18), 18, fill=BRAND)
    return image


def write(path: pathlib.Path, art: Image.Image, opaque: bool) -> None:
    size = Image.open(path).size
    icon = art.resize(size, Image.LANCZOS)
    if opaque:
        icon = icon.convert("RGB")
    icon.save(path, optimize=True)


ios = master(rounded=False)  # iOS masks the corners itself and needs no alpha
android = master(rounded=True)
for png in (ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("*.png"):
    write(png, ios, opaque=True)
for png in (ROOT / "android/app/src/main/res").glob("mipmap-*/ic_launcher.png"):
    write(png, android, opaque=False)
store = ROOT / "assets/brand/play-store-icon.png"
store.parent.mkdir(parents=True, exist_ok=True)
ios.resize((512, 512), Image.LANCZOS).convert("RGB").save(store, optimize=True)

# Play feature graphic: the icon on the brand colour with the app name.
banner = Image.new("RGB", (1024, 500), BRAND)
banner.paste(android.resize((300, 300), Image.LANCZOS), (110, 100),
             android.resize((300, 300), Image.LANCZOS))
draw = ImageDraw.Draw(banner)
draw.text((450, 250), "OwnNotes", fill="white", anchor="lm",
          font=ImageFont.truetype("arialbd.ttf", 96))
banner.save(ROOT.parent.parent / "docs/store/feature-graphic.png", optimize=True)
print("icons written")
