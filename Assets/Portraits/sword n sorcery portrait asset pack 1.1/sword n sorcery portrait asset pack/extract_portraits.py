#!/usr/bin/env python3

from pathlib import Path
from io import BytesIO
import base64
import xml.etree.ElementTree as ET

from PIL import Image, ImageOps


PORTRAIT_DIRECTORY = Path(
    "/home/Francois/Projects/Godot/JameGam60/Assets/Portraits/"
    "sword n sorcery portrait asset pack 1.1/"
    "sword n sorcery portrait asset pack/Indiviual_portraits/"
)

BLUE = (0x4D, 0xD9, 0xFF)


def apply_blue_filter(image):
    image = image.convert("RGBA")
    alpha = image.getchannel("A")

    grayscale = ImageOps.grayscale(image.convert("RGB"))
    tinted = ImageOps.colorize(
        grayscale,
        black=(0, 0, 0),
        white=BLUE,
    ).convert("RGBA")

    tinted.putalpha(alpha)
    return tinted


def update_svg_with_png(svg_path, image):
    png_buffer = BytesIO()
    image.save(png_buffer, format="PNG")
    encoded_png = base64.b64encode(png_buffer.getvalue()).decode("ascii")

    svg = ET.Element(
        "svg",
        {
            "xmlns": "http://www.w3.org/2000/svg",
            "width": str(image.width),
            "height": str(image.height),
            "viewBox": f"0 0 {image.width} {image.height}",
        },
    )

    ET.SubElement(
        svg,
        "image",
        {
            "width": str(image.width),
            "height": str(image.height),
            "href": f"data:image/png;base64,{encoded_png}",
        },
    )

    ET.ElementTree(svg).write(
        svg_path,
        encoding="unicode",
        xml_declaration=True,
    )


def main():
    if not PORTRAIT_DIRECTORY.is_dir():
        raise FileNotFoundError(
            f"Portrait directory does not exist: {PORTRAIT_DIRECTORY}"
        )

    png_files = sorted(PORTRAIT_DIRECTORY.glob("*.png"))

    if not png_files:
        print(f"No PNG images found in: {PORTRAIT_DIRECTORY}")
        return

    for png_path in png_files:
        with Image.open(png_path) as source_image:
            filtered_image = apply_blue_filter(source_image)

        filtered_image.save(png_path, format="PNG")

        svg_path = png_path.with_suffix(".svg")
        if svg_path.exists():
            update_svg_with_png(svg_path, filtered_image)

        print(f"Updated: {png_path.name}")

    print(f"Finished. Updated {len(png_files)} PNG images.")
    print("Matching SVG files were updated where present.")
    print(f"Colour used: #{BLUE[0]:02X}{BLUE[1]:02X}{BLUE[2]:02X}")


if __name__ == "__main__":
    main()
