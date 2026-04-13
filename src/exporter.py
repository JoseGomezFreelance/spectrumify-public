"""Exportacion de pixel-art a HTML, GIF y SCR (formato nativo ZX Spectrum)."""

from PIL import Image

from src.converter import convert_image, quantize_image, calculate_dimensions
from src.compressor import compress_html, format_bytes
from src.palette import PALETTE_16, PALETTE_GRAY, PALETTE_BW


def export_html(image_path, target_w=None, target_h=None, cell_size=2,
                mode="16", compression="safari", output_path="output.html"):
    """Pipeline completo: convierte imagen y exporta HTML comprimido.

    Args:
        image_path: ruta a la imagen de entrada.
        target_w, target_h: dimensiones objetivo en celdas.
        cell_size: tamano de celda en pixeles HTML.
        mode: "16" o "bw".
        compression: "safari", "aggressive", o "none".
        output_path: ruta del HTML de salida.

    Returns:
        Dict con estadisticas de la exportacion.
    """
    html_raw, info, _ = convert_image(
        image_path, target_w, target_h, cell_size, mode
    )

    if compression == "none":
        html_final = html_raw
        stats = {
            "bytes_before": len(html_raw),
            "bytes_after": len(html_raw),
            "td_before": info["total_cells"],
            "td_after": info["total_cells"],
        }
    else:
        aggressive = compression == "aggressive"
        html_final, stats = compress_html(html_raw, aggressive=aggressive)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_final)

    stats.update(info)
    stats["output_path"] = output_path
    stats["compression"] = compression

    return stats


def export_gif(image_path, target_w=None, target_h=None, mode="16",
               output_path="output.gif"):
    """Exporta la imagen cuantizada como GIF con paleta indexada."""
    img = Image.open(image_path).convert("RGB")
    orig_w, orig_h = img.size
    final_w, final_h = calculate_dimensions(orig_w, orig_h, target_w, target_h)
    resized = img.resize((final_w, final_h), Image.Resampling.LANCZOS)
    quantized = quantize_image(resized, mode)

    # Construir paleta para el GIF
    if mode == "gray":
        palette = PALETTE_GRAY
    elif mode == "bw":
        palette = PALETTE_BW
    else:
        palette = PALETTE_16

    # Crear imagen en modo P (paleta indexada)
    palette_flat = []
    for r, g, b in palette:
        palette_flat.extend([r, g, b])
    # Rellenar hasta 256 colores (768 bytes)
    palette_flat.extend([0] * (768 - len(palette_flat)))

    gif_img = Image.new("P", (final_w, final_h))
    gif_img.putpalette(palette_flat)

    # Mapear cada pixel a su indice en la paleta
    color_to_idx = {c: i for i, c in enumerate(palette)}
    pixels_q = quantized.load()
    gif_pixels = gif_img.load()
    for y in range(final_h):
        for x in range(final_w):
            gif_pixels[x, y] = color_to_idx.get(pixels_q[x, y], 0)

    gif_img.save(output_path)


# ---------------------------------------------------------------------------
# Exportacion SCR (formato nativo ZX Spectrum: 6912 bytes)
# ---------------------------------------------------------------------------

# Mapa de colores de nuestra paleta al indice ZX (0-7) + bright
_ZX_ATTR_MAP = {
    (0,   0,   0):   (0, 0),  # black
    (0,   0,   170): (1, 0),  # blue
    (170, 0,   0):   (2, 0),  # red
    (170, 0,   170): (3, 0),  # magenta
    (0,   170, 0):   (4, 0),  # green
    (0,   170, 170): (5, 0),  # cyan
    (170, 85,  0):   (6, 0),  # brown (yellow dark)
    (170, 170, 170): (7, 0),  # gray light (white dark)
    (85,  85,  85):  (0, 1),  # gray dark -> bright black
    (85,  85,  255): (1, 1),  # blue bright
    (255, 85,  85):  (2, 1),  # red bright
    (255, 85,  255): (3, 1),  # magenta bright
    (85,  255, 85):  (4, 1),  # green bright
    (85,  255, 255): (5, 1),  # cyan bright
    (255, 255, 85):  (6, 1),  # yellow bright
    (255, 255, 255): (7, 1),  # white bright
}

# B&W y gray tambien necesitan mapping
_ZX_ATTR_MAP_BW = {
    (0, 0, 0):       (0, 0),
    (255, 255, 255): (7, 1),
}

_ZX_ATTR_MAP_GRAY = {
    (0,   0,   0):   (0, 0),
    (85,  85,  85):  (0, 1),
    (170, 170, 170): (7, 0),
    (255, 255, 255): (7, 1),
}


def _scr_pixel_offset(x, y):
    """Calcula el offset en el bitmap SCR para el pixel (x, y).

    El layout de memoria del Spectrum es no-lineal:
    bits 15-13: tercio (0-2)
    bits 12-10: linea dentro del caracter (0-7)
    bits 9-5:   fila de caracter dentro del tercio (0-7)
    bits 4-0:   columna de byte (0-31)
    """
    return ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2) | (x >> 3)


def export_scr(image_path, mode="16", output_path="output.scr"):
    """Exporta como archivo SCR nativo del ZX Spectrum (6912 bytes).

    Redimensiona a 256x192, aplica la restriccion de 2 colores por
    bloque 8x8, y genera el bitmap + atributos en el layout de memoria
    real del Spectrum.
    """
    img = Image.open(image_path).convert("RGB")
    resized = img.resize((256, 192), Image.Resampling.LANCZOS)
    quantized = quantize_image(resized, mode)
    pixels = quantized.load()

    # Elegir el mapa de atributos segun modo
    if mode == "bw":
        attr_map = _ZX_ATTR_MAP_BW
    elif mode == "gray":
        attr_map = _ZX_ATTR_MAP_GRAY
    else:
        attr_map = _ZX_ATTR_MAP

    bitmap = bytearray(6144)   # 256x192 bits
    attrs = bytearray(768)     # 32x24 atributos

    # Procesar cada bloque 8x8
    for block_y in range(24):
        for block_x in range(32):
            # Recoger colores del bloque
            block_colors = []
            for dy in range(8):
                for dx in range(8):
                    px = pixels[block_x * 8 + dx, block_y * 8 + dy]
                    block_colors.append(px)

            # Contar frecuencias para elegir ink y paper
            from collections import Counter
            freq = Counter(block_colors)
            most_common = freq.most_common()

            # Paper = color mas comun, ink = segundo mas comun (o paper si solo hay 1)
            paper_rgb = most_common[0][0]
            ink_rgb = most_common[1][0] if len(most_common) > 1 else paper_rgb

            paper_idx, paper_bright = attr_map.get(paper_rgb, (0, 0))
            ink_idx, ink_bright = attr_map.get(ink_rgb, (7, 1))

            # El bright se decide por mayoria entre ink y paper
            bright = 1 if (paper_bright + ink_bright) >= 1 else 0

            # Atributo: flash(0) | bright | paper(3 bits) | ink(3 bits)
            attr_byte = (bright << 6) | (paper_idx << 3) | ink_idx
            attrs[block_y * 32 + block_x] = attr_byte

            # Generar bitmap: 1 = ink, 0 = paper
            for dy in range(8):
                byte_val = 0
                for dx in range(8):
                    px = pixels[block_x * 8 + dx, block_y * 8 + dy]
                    # Si el pixel esta mas cerca de ink que de paper, es ink (1)
                    if px == ink_rgb:
                        byte_val |= (0x80 >> dx)
                    elif px != paper_rgb:
                        # Tercer color+ en el bloque: elegir el mas cercano
                        dist_ink = sum((a - b) ** 2 for a, b in zip(px, ink_rgb))
                        dist_paper = sum((a - b) ** 2 for a, b in zip(px, paper_rgb))
                        if dist_ink < dist_paper:
                            byte_val |= (0x80 >> dx)

                y = block_y * 8 + dy
                x = block_x * 8
                offset = _scr_pixel_offset(x, y)
                bitmap[offset] = byte_val

    with open(output_path, "wb") as f:
        f.write(bitmap)
        f.write(attrs)


def load_scr(scr_path):
    """Lee un archivo .scr del ZX Spectrum y devuelve una imagen PIL 256x192."""
    ZX_PAL = {
        (0, 0): (0,0,0),       (1, 0): (0,0,170),     (2, 0): (170,0,0),
        (3, 0): (170,0,170),   (4, 0): (0,170,0),     (5, 0): (0,170,170),
        (6, 0): (170,170,0),   (7, 0): (170,170,170),
        (0, 1): (0,0,0),       (1, 1): (0,0,255),     (2, 1): (255,0,0),
        (3, 1): (255,0,255),   (4, 1): (0,255,0),     (5, 1): (0,255,255),
        (6, 1): (255,255,0),   (7, 1): (255,255,255),
    }

    with open(scr_path, "rb") as f:
        data = f.read()

    if len(data) != 6912:
        return None

    bitmap, attrs = data[:6144], data[6144:]
    img = Image.new("RGB", (256, 192))
    pixels = img.load()

    for y in range(192):
        offset = ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2)
        for col in range(32):
            byte = bitmap[offset + col]
            attr = attrs[(y // 8) * 32 + col]
            ink = attr & 0x07
            paper = (attr >> 3) & 0x07
            bright = (attr >> 6) & 0x01
            ink_rgb = ZX_PAL[(ink, bright)]
            paper_rgb = ZX_PAL[(paper, bright)]
            for bit in range(8):
                pixels[col * 8 + bit, y] = ink_rgb if byte & (0x80 >> bit) else paper_rgb

    return img


def stats_summary(stats):
    """Genera un resumen legible de las estadisticas de exportacion."""
    saved = stats["bytes_before"] - stats["bytes_after"]
    pct = (100 * saved / stats["bytes_before"]) if stats["bytes_before"] > 0 else 0

    return {
        "size_before": format_bytes(stats["bytes_before"]),
        "size_after": format_bytes(stats["bytes_after"]),
        "saved": format_bytes(saved),
        "pct_saved": f"{pct:.1f}%",
        "cells_before": stats["td_before"],
        "cells_after": stats["td_after"],
    }
