"""Conversion de imagenes a pixel-art con paleta ZX Spectrum."""

from PIL import Image

from src.palette import nearest_color, nearest_color_bw, rgb_to_hex, PALETTE_16, PALETTE_GRAY


def calculate_dimensions(orig_w, orig_h, target_w=None, target_h=None):
    """Calcula dimensiones objetivo preservando ratio de aspecto.

    - Nada dado: dimensiones originales.
    - Solo target_w: alto proporcional.
    - Solo target_h: ancho proporcional.
    - Ambos: ajusta dentro de la caja sin estirar.
    """
    ratio = orig_w / orig_h

    if target_w is None and target_h is None:
        return orig_w, orig_h

    if target_w is not None and target_h is None:
        return target_w, max(1, round(target_w / ratio))

    if target_h is not None and target_w is None:
        return max(1, round(target_h * ratio)), target_h

    box_ratio = target_w / target_h
    if box_ratio > ratio:
        return max(1, round(target_h * ratio)), target_h
    else:
        return target_w, max(1, round(target_w / ratio))


def quantize_image(img, mode="16"):
    """Cuantiza una imagen PIL a la paleta indicada.

    Args:
        img: imagen PIL en modo RGB.
        mode: "16" para paleta ZX completa, "gray" para 4 grises, "bw" para B&W.

    Returns:
        Nueva imagen PIL con los colores cuantizados.
    """
    img = img.copy()
    pixels = img.load()
    w, h = img.size

    if mode == "bw":
        for y in range(h):
            for x in range(w):
                pixels[x, y] = nearest_color_bw(pixels[x, y])
    else:
        palette = PALETTE_GRAY if mode == "gray" else PALETTE_16
        for y in range(h):
            for x in range(w):
                pixels[x, y] = nearest_color(pixels[x, y], palette)

    return img


def convert_image(path, target_w=None, target_h=None, cell_size=2, mode="16"):
    """Convierte una imagen en HTML pixel-art con la paleta ZX Spectrum.

    Args:
        path: ruta al archivo de imagen.
        target_w: ancho objetivo en celdas.
        target_h: alto objetivo en celdas.
        cell_size: tamano de cada celda en pixeles HTML.
        mode: "16" o "bw".

    Returns:
        Tupla (html_string, info_dict, quantized_image).
    """
    img = Image.open(path).convert("RGB")
    orig_w, orig_h = img.size

    final_w, final_h = calculate_dimensions(orig_w, orig_h, target_w, target_h)
    img = img.resize((final_w, final_h), Image.Resampling.LANCZOS)

    quantized = quantize_image(img, mode)
    pixels = quantized.load()

    html = ['<table cellpadding="0" cellspacing="0">']
    for y in range(final_h):
        html.append("<tr>")
        for x in range(final_w):
            hex_color = rgb_to_hex(pixels[x, y])
            html.append(
                f'<td width="{cell_size}" height="{cell_size}" '
                f'bgcolor="{hex_color}"></td>'
            )
        html.append("</tr>")
    html.append("</table>")

    info = {
        "orig_w": orig_w,
        "orig_h": orig_h,
        "final_w": final_w,
        "final_h": final_h,
        "total_cells": final_w * final_h,
        "cell_size": cell_size,
    }

    return "\n".join(html), info, quantized
