"""Rebuild the visual concept and GitHub-ready executor release ZIP."""
from pathlib import Path
import re
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "RetroBox.lua").read_text()
VERSION = re.search(r'Version = "([^"]+)"', source).group(1)
ROOT.joinpath("docs").mkdir(exist_ok=True)
ROOT.joinpath("assets").mkdir(exist_ok=True)


def visual_concept():
    raw = re.search(r"Library.Themes.Retro98 = palette\(\{(.*?)\}\)", source, re.S).group(1)
    values = [tuple(map(int, m)) for m in re.findall(r"\{(\d+),(\d+),(\d+)\}", raw)]
    roles = ["Background", "Surface", "Inset", "Text", "Muted", "Border", "Highlight", "Shadow", "Accent", "AccentText", "Success", "Danger"]
    colors = dict(zip(roles, values))
    image = Image.new("RGB", (1280, 940), "#F0EDDF")
    draw = ImageDraw.Draw(image)

    def font(size=17):
        try:
            return ImageFont.truetype("DejaVuSansMono.ttf", size)
        except OSError:
            return ImageFont.load_default(size=size)

    def rect(box, fill, outline=None, width=1):
        draw.rectangle(box, fill=colors.get(fill, fill), outline=colors.get(outline, outline), width=width)

    def text(x, y, content, fill="Text", size=17):
        draw.text((x, y), content, fill=colors.get(fill, fill), font=font(size))

    def raised(box, fill="Surface", down=False):
        x1, y1, x2, y2 = box
        rect(box, fill)
        bright, dark = ("Shadow", "Highlight") if down else ("Highlight", "Shadow")
        draw.line((x1, y2, x1, y1, x2, y1), fill=colors[bright], width=2)
        draw.line((x1, y2, x2, y2, x2, y1), fill=colors[dark], width=2)

    text(116, 39, "RETROBOX UI", "Accent", 29)
    text(116, 82, f"Executor GUI Library  /  {VERSION}", "Muted", 16)
    x, y, w, h = 116, 134, 1048, 684
    rect((x + 8, y + 8, x + w + 8, y + h + 8), "#BAB7AC")
    raised((x, y, x + w, y + h), "Background")
    rect((x + 5, y + 5, x + w - 5, y + 47), "Accent")
    text(x + 17, y + 14, "RetroBox UI / Showcase", "AccentText", 20)
    for offset, caption in [(118, "_"), (81, "[]"), (44, "X")]:
        raised((x + w - offset, y + 11, x + w - offset + 30, y + 40))
        text(x + w - offset + 6, y + 15, caption, size=15)
    text(x + 17, y + 60, "Pequenas peças. Interfaces completas.", "Muted", 15)
    nav_x, nav_y = x + 14, y + 96
    for i, caption in enumerate([">  Início", "*  Visual", "+  Componentes", "#  Eventos"]):
        box = (nav_x, nav_y + i * 49, nav_x + 186, nav_y + i * 49 + 40)
        raised(box, "Accent" if i == 1 else "Surface")
        text(nav_x + 12, box[1] + 10, caption, "AccentText" if i == 1 else "Text", 16)
    page_x = x + 219
    raised((page_x, y + 93, x + w - 20, y + 126), "Inset", down=True)
    text(page_x + 12, y + 100, "Buscar nesta aba...", "Muted", 14)

    left_x, left_y, left_w = page_x, y + 144, 359
    right_x, right_y, right_w = page_x + left_w + 17, left_y, 434
    rect((left_x, left_y, left_x + left_w, left_y + 382), "Surface", "Border")
    rect((right_x, right_y, right_x + right_w, right_y + 439), "Surface", "Border")
    text(left_x + 15, left_y + 14, "CAMPO DE VISÃO", "Muted", 15)
    text(left_x + 15, left_y + 51, "Exemplo visual do seu script.", size=14)
    text(left_x + 15, left_y + 75, "A cor acompanha o ColorPicker.", "Muted", 13)
    text(left_x + 15, left_y + 121, "Mostrar círculo", size=16)
    raised((left_x + left_w - 51, left_y + 117, left_x + left_w - 20, left_y + 146), down=True)
    text(left_x + left_w - 43, left_y + 120, "X", "Accent", 18)
    text(left_x + 15, left_y + 179, "Diâmetro do círculo", size=15)
    raised((left_x + left_w - 81, left_y + 174, left_x + left_w - 17, left_y + 202), "Inset", down=True)
    text(left_x + left_w - 73, left_y + 180, "220", "Muted", 14)
    raised((left_x + 18, left_y + 227, left_x + left_w - 21, left_y + 239), "Inset", down=True)
    rect((left_x + 20, left_y + 229, left_x + 165, left_y + 236), "Accent")
    raised((left_x + 159, left_y + 218, left_x + 174, left_y + 247))
    text(left_x + 15, left_y + 280, "O avatar vem do Roblox.", "Muted", 13)
    text(left_x + 15, left_y + 305, "Sua lógica entra nos callbacks.", "Muted", 13)

    text(right_x + 15, right_y + 14, "PALETA / RGB", "Muted", 15)
    text(right_x + 15, right_y + 49, "Cor do FOV", size=17)
    text(right_x + 15, right_y + 77, "Cor fixa, HSV, HEX ou RGB animado.", "Muted", 12)
    raised((right_x + 15, right_y + 112, right_x + right_w - 15, right_y + 147))
    rect((right_x + 25, right_y + 120, right_x + 55, right_y + 138), "#326EAA", "Border")
    text(right_x + 67, right_y + 120, "#326EAA", size=14)
    pad_x, pad_y = right_x + 24, right_y + 166
    pad_w, pad_h = right_w - 48, 105
    target = (0, 125, 230)
    for px in range(pad_w):
        saturation = px / max(1, pad_w - 1)
        for py in range(pad_h):
            brightness = 1 - py / max(1, pad_h - 1)
            image.putpixel((pad_x + px, pad_y + py), tuple(round((255 * (1 - saturation) + c * saturation) * brightness) for c in target))
    marker_x, marker_y = pad_x + 238, pad_y + 29
    draw.rectangle((marker_x - 4, marker_y - 4, marker_x + 4, marker_y + 4), outline="#FFFFFF", width=2)
    import colorsys
    for px in range(pad_w):
        rgb = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(px / pad_w, 1, 1))
        draw.line((pad_x + px, pad_y + 116, pad_x + px, pad_y + 131), fill=rgb)
    for i, (caption, value) in enumerate([("R", "50"), ("G", "110"), ("B", "170")]):
        fx = pad_x + i * 130
        text(fx, pad_y + 151, caption, "Muted", 14)
        raised((fx + 21, pad_y + 143, fx + 119, pad_y + 174), "Inset", down=True)
        text(fx + 33, pad_y + 151, value, size=14)
    raised((pad_x, pad_y + 187, pad_x + 194, pad_y + 217), "Inset", down=True)
    text(pad_x + 10, pad_y + 194, "#326EAA", size=14)
    text(pad_x + 219, pad_y + 195, "%", "Muted", 14)
    raised((pad_x + 243, pad_y + 187, pad_x + pad_w, pad_y + 217), "Inset", down=True)
    text(pad_x + 256, pad_y + 194, "100", size=14)
    raised((pad_x, pad_y + 229, pad_x + 218, pad_y + 259))
    text(pad_x + 10, pad_y + 236, "[ ] RGB animado", size=14)
    raised((pad_x + 235, pad_y + 229, pad_x + 293, pad_y + 259), "Inset", down=True)
    text(pad_x + 247, pad_y + 236, "6", size=14)
    text(pad_x + 307, pad_y + 238, "s/ciclo", "Muted", 12)

    footer_y = y + h - 62
    draw.line((x + 15, footer_y, x + w - 15, footer_y), fill=colors["Border"])
    raised((x + 18, footer_y + 12, x + 60, footer_y + 52), "Inset", down=True)
    text(x + 29, footer_y + 18, "R", "Accent", 24)
    text(x + 74, footer_y + 13, "Seu nome", size=16)
    text(x + 74, footer_y + 36, "@usuario", "Muted", 13)
    raised((x + 228, footer_y + 14, x + 267, footer_y + 51))
    text(x + 236, footer_y + 20, "⚙", "Text", 24)
    text(x + w - 219, footer_y + 29, f"Visual | v{VERSION}", "Muted", 13)
    text(116, 853, "CONCEITO VISUAL  /  perfil ilustrativo  /  validação visual no executor pendente", "Muted", 13)
    text(116, 891, "Retro98   Terminal   GameBoy   Paper   Midnight   Monokai", "Accent", 15)
    image.save(ROOT / "docs/visual-concept.png", optimize=True)


def mark():
    svg = """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<rect width="256" height="256" fill="#D2CFC3"/>
<path d="M20 236V20H236" fill="none" stroke="#FFFDF1" stroke-width="8"/>
<path d="M20 236H236V20" fill="none" stroke="#736F65" stroke-width="8"/>
<rect x="32" y="32" width="192" height="36" fill="#1C3B65"/>
<rect x="176" y="42" width="34" height="16" fill="#E6E3D8"/>
<path d="M70 200V92H146V144H70M116 144L154 200" fill="none" stroke="#1C3B65" stroke-width="18" stroke-linecap="square"/>
</svg>"""
    (ROOT / "assets/retrobox-mark.svg").write_text(svg)


def release_zip():
    for file in sorted(ROOT.rglob("*.md")):
        for link in re.findall(r"\]\(([^)]+)\)", file.read_text()):
            if not link.startswith(("https://", "http://", "#")):
                assert (file.parent / link.split("#", 1)[0]).exists(), f"Broken link: {file.name}: {link}"
    out = ROOT.parent / f"RetroBox-UI-v{VERSION}.zip"
    files = sorted(p for p in ROOT.rglob("*") if p.is_file() and "__pycache__" not in p.parts)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file in files:
            archive.write(file, "retrobox-ui/" + file.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(out) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files)
    print(f"Built {out.name}: {len(files)} files, {out.stat().st_size:,} bytes")


if __name__ == "__main__":
    visual_concept()
    mark()
    release_zip()
