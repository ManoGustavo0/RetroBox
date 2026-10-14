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
ICON_BLOCK = re.search(r"-- BEGIN PIXEL ICONS(.*?)-- END PIXEL ICONS", source, re.S).group(1)
ICONS = dict(re.findall(r'\["([a-z0-9_-]+)"\] = "([.#ahsmgr/]+)"', ICON_BLOCK))
PIXEL_ROLES = {"#": "Text", "a": "Accent", "h": "Highlight", "s": "Shadow", "m": "Muted", "g": "Success", "r": "Danger"}
raw = re.search(r"Library.Themes.Retro98 = palette\(\{(.*?)\}\)", source, re.S).group(1)
values = [tuple(map(int, m)) for m in re.findall(r"\{(\d+),(\d+),(\d+)\}", raw)]
COLORS = dict(zip(["Background", "Surface", "Inset", "Text", "Muted", "Border", "Highlight", "Shadow", "Accent", "AccentText", "Success", "Danger"], values))


def draw_icon(draw, name, x, y, scale=2, foreground="Text"):
    for row_index, row in enumerate(ICONS[name].split("/")):
        for column, char in enumerate(row):
            if char != ".":
                role = foreground if char == "#" else PIXEL_ROLES[char]
                px, py = x + column * scale, y + row_index * scale
                draw.rectangle((px, py, px + scale - 1, py + scale - 1), fill=COLORS[role])


def icon_svg(name, background=False):
    rects = []
    for y, row in enumerate(ICONS[name].split("/")):
        for x, char in enumerate(row):
            if char != ".":
                color = "#%02X%02X%02X" % COLORS[PIXEL_ROLES[char]]
                rects.append(f'<rect x="{x}" y="{y}" width="1" height="1" fill="{color}"/>')
    content = "".join(rects)
    if background:
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 16 16" shape-rendering="crispEdges"><rect width="16" height="16" fill="#D2CFC3"/><g transform="translate(2 2)">{content}</g></svg>\n'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 12 12" shape-rendering="crispEdges" role="img" aria-label="{name}">{content}</svg>\n'


def pixel_catalog():
    folder = ROOT / "assets/pixel-icons"
    folder.mkdir(exist_ok=True)
    for name in ICONS:
        (folder / f"{name}.svg").write_text(icon_svg(name), encoding="utf-8")
    names = sorted(ICONS)
    cols, cell_w, cell_h = 6, 200, 98
    rows = (len(names) + cols - 1) // cols
    image = Image.new("RGB", (1280, 178 + rows * cell_h), COLORS["Background"])
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype("DejaVuSansMono.ttf", 29)
    body_font = ImageFont.truetype("DejaVuSansMono.ttf", 14)
    draw_icon(draw, "retrobox", 42, 29, 4)
    draw.text((111, 27), "RETROBOX / PIXEL ICONS", font=title_font, fill=COLORS["Accent"])
    draw.text((112, 74), f"{len(names)} ícones embutidos  /  temas adaptáveis  /  v{VERSION}", font=body_font, fill=COLORS["Muted"])
    for index, name in enumerate(names):
        x, y = 40 + index % cols * cell_w, 128 + index // cols * cell_h
        draw.rectangle((x, y, x + cell_w - 12, y + cell_h - 12), fill=COLORS["Surface"])
        draw.line((x, y + cell_h - 12, x, y, x + cell_w - 12, y), fill=COLORS["Highlight"])
        draw.line((x, y + cell_h - 12, x + cell_w - 12, y + cell_h - 12, x + cell_w - 12, y), fill=COLORS["Shadow"])
        draw_icon(draw, name, x + 14, y + 10, 3)
        draw.text((x + 14, y + 58), name, font=body_font, fill=COLORS["Text"])
    draw.text((40, image.height - 27), 'Icon = "nome"  /  Library:GetIconNames()  /  Library:RegisterIcon()', font=body_font, fill=COLORS["Muted"])
    image.save(ROOT / "docs/pixel-icons.png", optimize=True)


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

    draw_icon(draw, "retrobox", 116, 29, 4)
    text(180, 39, "RETROBOX UI", "Accent", 29)
    text(116, 82, f"Executor GUI Library  /  {VERSION}", "Muted", 16)
    x, y, w, h = 116, 134, 1048, 684
    rect((x + 8, y + 8, x + w + 8, y + h + 8), "#BAB7AC")
    raised((x, y, x + w, y + h), "Background")
    rect((x + 5, y + 5, x + w - 5, y + 47), "Accent")
    draw_icon(draw, "retrobox", x + 13, y + 11, 2, "AccentText")
    text(x + 48, y + 14, "RetroBox UI / Showcase", "AccentText", 20)
    for offset, caption in [(118, "_"), (81, "[]"), (44, "X")]:
        raised((x + w - offset, y + 11, x + w - offset + 30, y + 40))
        draw_icon(draw, {"_": "minimize", "[]": "maximize", "X": "close"}[caption], x + w - offset + 9, y + 19, 1)
    text(x + 17, y + 60, "Pequenas peças. Interfaces completas.", "Muted", 15)
    for index, icon in enumerate(("spark", "retrobox", "spark")):
        draw_icon(draw, icon, x + w - 78 + index * 18, y + 64, 1, "Muted")
    nav_x, nav_y = x + 14, y + 96
    for i, (caption, icon) in enumerate([("Início", "home"), ("Visual", "palette"), ("Componentes", "grid"), ("Eventos", "terminal"), ("Configurações", "settings")]):
        box = (nav_x, nav_y + i * 49, nav_x + 186, nav_y + i * 49 + 40)
        raised(box, "Accent" if i == 1 else "Surface")
        draw_icon(draw, icon, nav_x + 9, box[1] + 8, 2, "AccentText" if i == 1 else "Text")
        text(nav_x + 43, box[1] + 10, caption, "AccentText" if i == 1 else "Text", 15)
    page_x = x + 219
    raised((page_x, y + 93, x + w - 20, y + 126), "Inset", down=True)
    draw_icon(draw, "search", page_x + 10, y + 103, 1, "Muted")
    text(page_x + 33, y + 100, "Pesquisar funções...", "Muted", 14)

    left_x, left_y, left_w = page_x, y + 144, 359
    right_x, right_y, right_w = page_x + left_w + 17, left_y, 434
    rect((left_x, left_y, left_x + left_w, left_y + 382), "Surface", "Border")
    rect((right_x, right_y, right_x + right_w, right_y + 439), "Surface", "Border")
    draw_icon(draw, "target", left_x + 15, left_y + 17, 1, "Muted")
    text(left_x + 36, left_y + 14, "CAMPO DE VISÃO", "Muted", 15)
    text(left_x + 15, left_y + 51, "Exemplo visual do seu script.", size=14)
    text(left_x + 15, left_y + 75, "A cor acompanha o ColorPicker.", "Muted", 13)
    text(left_x + 15, left_y + 121, "Mostrar círculo", size=16)
    raised((left_x + left_w - 153, left_y + 117, left_x + left_w - 62, left_y + 146))
    text(left_x + left_w - 143, left_y + 125, "Mouse 2", "Muted", 12)
    raised((left_x + left_w - 51, left_y + 117, left_x + left_w - 20, left_y + 146), down=True)
    draw_icon(draw, "check", left_x + left_w - 44, left_y + 125, 1, "Accent")
    text(left_x + 15, left_y + 179, "Diâmetro do círculo", size=15)
    raised((left_x + left_w - 81, left_y + 174, left_x + left_w - 17, left_y + 202), "Inset", down=True)
    text(left_x + left_w - 73, left_y + 180, "220", "Muted", 14)
    raised((left_x + 18, left_y + 227, left_x + left_w - 21, left_y + 239), "Inset", down=True)
    rect((left_x + 20, left_y + 229, left_x + 165, left_y + 236), "Accent")
    raised((left_x + 159, left_y + 218, left_x + 174, left_y + 247))
    text(left_x + 15, left_y + 280, "O avatar vem do Roblox.", "Muted", 13)
    text(left_x + 15, left_y + 305, "Sua lógica entra nos callbacks.", "Muted", 13)

    draw_icon(draw, "palette", right_x + 15, right_y + 16, 1, "Muted")
    text(right_x + 37, right_y + 14, "PALETA / RGB", "Muted", 15)
    text(right_x + 15, right_y + 49, "Cor do FOV", size=17)
    text(right_x + 15, right_y + 77, "Cor fixa, HSV, HEX ou RGB animado.", "Muted", 12)
    raised((right_x + 15, right_y + 112, right_x + right_w - 15, right_y + 147))
    text(right_x + 25, right_y + 120, "#326EAA", size=14)
    rect((right_x + right_w - 57, right_y + 120, right_x + right_w - 27, right_y + 138), "#326EAA", "Border")
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
    draw_icon(draw, "settings", x + 236, footer_y + 21, 2)
    for row in range(2):
        for column in range(6):
            sx, sy = x + 282 + column * 6, footer_y + 25 + row * 6
            rect((sx, sy, sx + 3, sy + 3), "Accent" if (column + row) % 2 == 0 else "Muted")
    text(x + w - 219, footer_y + 29, f"Visual | v{VERSION}", "Muted", 13)
    text(116, 853, "CONCEITO VISUAL  /  perfil ilustrativo  /  validação visual no executor pendente", "Muted", 13)
    text(116, 891, "Retro98   Terminal   GameBoy   Paper   Midnight   Monokai", "Accent", 15)
    text(116, 918, "Hacker   Dracula   Nord   Sakura   Ocean   Amber", "Accent", 15)
    image.save(ROOT / "docs/visual-concept.png", optimize=True)


def dashboard_concept():
    import math

    image = Image.new("RGB", (1280, 1040), "#F0EDDF")
    draw = ImageDraw.Draw(image)

    def text(x, y, value, role="Text", size=16):
        draw.text((x, y), value, fill=COLORS[role], font=ImageFont.truetype("DejaVuSansMono.ttf", size))

    def box(bounds, role="Surface", inset=False):
        x1, y1, x2, y2 = bounds
        draw.rectangle(bounds, fill=COLORS[role])
        bright, dark = ("Shadow", "Highlight") if inset else ("Highlight", "Shadow")
        draw.line((x1, y2, x1, y1, x2, y1), fill=COLORS[bright], width=2)
        draw.line((x1, y2, x2, y2, x2, y1), fill=COLORS[dark], width=2)

    draw_icon(draw, "retrobox", 54, 35, 4)
    text(122, 39, "RETROBOX / LIVE COMPONENTS", "Accent", 28)
    text(56, 101, f"v{VERSION}  /  dados simulados  /  identidade retrô", "Muted")
    box((50, 148, 1228, 940), "Background")
    draw.rectangle((55, 153, 1223, 190), fill=COLORS["Accent"])
    draw_icon(draw, "terminal", 67, 161, 2, "AccentText")
    text(103, 161, "RetroBox / Dashboard", "AccentText", 17)
    for index, name in enumerate(("minimize", "maximize", "close")):
        box((1115 + index * 34, 159, 1143 + index * 34, 184))
        draw_icon(draw, name, 1123 + index * 34, 166, 1)
    text(68, 207, "Controles dinâmicos, sem perder o estilo da RetroBox.", "Muted", 14)
    for index, (title, icon) in enumerate((("Dashboard", "grid"), ("Ações", "chevron-right"), ("Visual", "palette"), ("Configurações", "settings"))):
        y = 250 + index * 46
        box((66, y, 230, y + 35), "Accent" if index == 0 else "Surface")
        draw_icon(draw, icon, 77, y + 11, 1, "AccentText" if index == 0 else "Text")
        text(101, y + 9, title, "AccentText" if index == 0 else "Text", 13)
    box((251, 248, 1209, 285), "Inset", True)
    draw_icon(draw, "search", 264, 260, 1)
    text(287, 258, "Buscar controles...", "Muted", 14)
    for x, title, value, subtitle, icon in ((251, "TOTAL", "12.5K", "+250 nesta sessão", "star"), (575, "TEMPO ATIVO", "03:42", "Atualização gerenciada", "refresh"), (899, "AMOSTRA ATUAL", "24 un/s", "+6 desde a última", "bolt")):
        box((x, 307, x + 310, 440))
        draw_icon(draw, icon, x + 13, 323, 1, "Muted")
        text(x + 35, 321, title, "Muted", 12)
        box((x + 10, 348, x + 300, 430), "Inset", True)
        text(x + 22, 359, value, size=30)
        text(x + 22, 405, subtitle, "Success" if icon != "refresh" else "Muted", 12)
    box((251, 460, 831, 730)); text(269, 474, "HISTÓRICO / 60 AMOSTRAS", "Muted", 12)
    box((309, 511, 812, 695), "Inset", True)
    for row in range(5):
        y = 514 + row * 44
        draw.line((312, y, 808, y), fill=COLORS["Border"])
    points = [(313 + index * 8, 608 - int(47 * math.sin(index * .27) + 14 * math.cos(index * .71))) for index in range(62)]
    draw.line(points, fill=COLORS["Accent"], width=3)
    text(270, 511, "32", "Muted", 11); text(270, 678, "8", "Muted", 11)
    text(311, 703, "1", "Muted", 11); text(785, 703, "60", "Muted", 11)
    box((849, 460, 1209, 730)); text(865, 474, "CATEGORIAS", "Muted", 12)
    box((877, 511, 1191, 695), "Inset", True)
    for index, height in enumerate((93, 144, 117, 68)):
        x = 896 + index * 71
        draw.rectangle((x, 691 - height, x + 44, 691), fill=COLORS["Accent"])
        text(x + 16, 703, "ABCD"[index], "Muted", 11)
    box((251, 749, 1209, 869)); text(269, 762, "AÇÃO CANCELÁVEL", "Muted", 12)
    box((269, 791, 768, 818), "Inset", True)
    draw.rectangle((272, 794, 577, 815), fill=COLORS["Accent"])
    text(486, 797, "62%", "AccentText", 12)
    text(270, 834, "Etapa 12 de 20  /  cancelamento cooperativo", "Muted", 12)
    box((790, 791, 983, 825)); text(815, 798, "Cancelar ação", size=14)
    box((1001, 791, 1190, 825)); draw_icon(draw, "close", 1016, 801, 1)
    text(1040, 798, "Parar tudo", size=14)
    draw.line((66, 887, 1210, 887), fill=COLORS["Border"])
    box((70, 900, 104, 931), "Inset", True); text(79, 903, "R", "Accent", 20)
    text(116, 899, "Seu nome", size=13); text(116, 918, "@usuario", "Muted", 11)
    draw_icon(draw, "settings", 240, 906, 2)
    text(981, 910, "RightShift / menu", "Muted", 12)
    text(54, 970, "CONCEITO VISUAL · perfil ilustrativo · conferência no executor pendente", "Muted", 14)
    text(54, 1005, "States + Tasks + Scopes + Charts + Actions", "Accent", 15)
    image.save(ROOT / "docs/dashboard-concept.png", optimize=True)


def mark():
    (ROOT / "assets/retrobox-mark.svg").write_text(icon_svg("retrobox", background=True))


def release_zip():
    for file in sorted(ROOT.rglob("*.md")):
        for link in re.findall(r"\]\(([^)]+)\)", file.read_text()):
            if not link.startswith(("https://", "http://", "#")):
                assert (file.parent / link.split("#", 1)[0]).exists(), f"Broken link: {file.name}: {link}"
    out = ROOT.parent / f"RetroBox-UI-v{VERSION}.zip"
    repository = ROOT.parent.parent if ROOT.parent.name == "RetroBox-UI-v1.1.0" else ROOT.parent
    files = [(p, "RetroBox-UI-v1.1.0/retrobox-ui/" + p.relative_to(ROOT).as_posix())
             for p in sorted(ROOT.rglob("*")) if p.is_file() and "__pycache__" not in p.parts]
    files += [(p, "dist/" + p.relative_to(repository / "dist").as_posix())
              for p in sorted((repository / "dist").rglob("*")) if p.is_file()]
    prompt = repository / "Prompt-RetroBox-IA.md"
    if prompt.is_file():
        files.append((prompt, "Prompt-RetroBox-IA.md"))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for file, name in files:
            archive.write(file, name)
    with zipfile.ZipFile(out) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(files)
    print(f"Built {out.name}: {len(files)} files, {out.stat().st_size:,} bytes")


if __name__ == "__main__":
    pixel_catalog()
    visual_concept()
    dashboard_concept()
    mark()
    release_zip()
