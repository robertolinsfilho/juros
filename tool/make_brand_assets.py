"""Gera as imagens da marca Acertaí a partir do arquivo original do logo.

Uso: python tool/make_brand_assets.py caminho/do/logo.jpg
Cria assets/brand/*.png (fundo transparente) e os ícones de web/.
"""

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAVY = (3, 16, 35)


def color_to_alpha(img, bg=NAVY):
    """Troca o fundo azul-marinho por transparência, mantendo as cores do desenho."""
    img = img.convert("RGB")
    out = Image.new("RGBA", img.size)
    src = img.load()
    dst = out.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            c = src[x, y]
            alpha = 0.0
            for i in range(3):
                if c[i] > bg[i]:
                    alpha = max(alpha, (c[i] - bg[i]) / (255 - bg[i]))
            if alpha < 0.02:
                dst[x, y] = (0, 0, 0, 0)
                continue
            rgb = tuple(max(0, min(255, round((c[i] - bg[i] * (1 - alpha)) / alpha))) for i in range(3))
            dst[x, y] = rgb + (round(alpha * 255),)
    return out


def content_box(img, threshold=70):
    """Retângulo que contém o desenho (ignora o fundo escuro)."""
    gray = img.convert("L").point(lambda value: 255 if value > threshold else 0)
    return gray.getbbox()


def groups(img, threshold=70):
    """Faixas horizontais de conteúdo: o símbolo, o nome e a frase."""
    width, height = img.size
    gray = img.convert("L").load()
    bands = []
    start = None
    for y in range(height):
        has_ink = any(gray[x, y] > threshold for x in range(0, width, 2))
        if has_ink and start is None:
            start = y
        elif not has_ink and start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, height - 1))
    return [band for band in bands if band[1] - band[0] > 8]


def trimmed(img, box):
    return img.crop(box)


def square_icon(mark, size, fill, background=NAVY):
    canvas = Image.new("RGB", (size, size), background)
    target = round(size * fill)
    scale = target / max(mark.size)
    resized = mark.resize((round(mark.size[0] * scale), round(mark.size[1] * scale)), Image.LANCZOS)
    canvas.paste(resized, ((size - resized.size[0]) // 2, (size - resized.size[1]) // 2), resized)
    return canvas


def main(path):
    source = Image.open(path).convert("RGB")
    bands = groups(source)
    if len(bands) < 2:
        raise SystemExit("não encontrei o símbolo e o nome na imagem")
    brand = os.path.join(ROOT, "assets", "brand")
    os.makedirs(brand, exist_ok=True)

    symbol_band = bands[0]
    symbol_box = content_box(source.crop((0, symbol_band[0], source.size[0], symbol_band[1] + 1)))
    symbol_box = (
        symbol_box[0],
        symbol_box[1] + symbol_band[0],
        symbol_box[2],
        symbol_box[3] + symbol_band[0],
    )
    pad = 6
    mark = color_to_alpha(
        source.crop(
            (
                max(0, symbol_box[0] - pad),
                max(0, symbol_box[1] - pad),
                min(source.size[0], symbol_box[2] + pad),
                min(source.size[1], symbol_box[3] + pad),
            )
        )
    )
    mark.save(os.path.join(brand, "mark.png"), optimize=True)

    lockup = color_to_alpha(source.crop((0, symbol_box[1] - pad, source.size[0], bands[-1][1] + pad)))
    lockup = lockup.crop(content_box(lockup, 20))
    lockup.save(os.path.join(brand, "logo.png"), optimize=True)

    web = os.path.join(ROOT, "web")
    square_icon(mark, 64, 0.82).save(os.path.join(web, "favicon.png"), optimize=True)
    for size in (192, 512):
        square_icon(mark, size, 0.62).save(os.path.join(web, "icons", f"Icon-{size}.png"), optimize=True)
        square_icon(mark, size, 0.46).save(os.path.join(web, "icons", f"Icon-maskable-{size}.png"), optimize=True)
    print("ok", lockup.size, mark.size)


if __name__ == "__main__":
    main(sys.argv[1])
