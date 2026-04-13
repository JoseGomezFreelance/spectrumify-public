"""Definicion de paletas de colores para Spectrumify."""

# Paleta ZX Spectrum: 8 normales + 8 brillantes (negro compartido)
ZX_COLORS = {
    "ZX_BLACK":          (0,   0,   0),
    "ZX_BLUE_DARK":      (0,   0,   170),
    "ZX_RED_DARK":       (170, 0,   0),
    "ZX_MAGENTA_DARK":   (170, 0,   170),
    "ZX_GREEN_DARK":     (0,   170, 0),
    "ZX_CYAN":           (0,   170, 170),
    "ZX_BROWN":          (170, 85,  0),
    "ZX_GRAY_LIGHT":     (170, 170, 170),
    "ZX_GRAY_DARK":      (85,  85,  85),
    "ZX_BLUE_BRIGHT":    (85,  85,  255),
    "ZX_RED_BRIGHT":     (255, 85,  85),
    "ZX_MAGENTA_BRIGHT": (255, 85,  255),
    "ZX_GREEN_BRIGHT":   (85,  255, 85),
    "ZX_CYAN_BRIGHT":    (85,  255, 255),
    "ZX_YELLOW":         (255, 255, 85),
    "ZX_WHITE":          (255, 255, 255),
}

PALETTE_16 = list(ZX_COLORS.values())

PALETTE_GRAY = [(0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255)]

PALETTE_BW = [(0, 0, 0), (255, 255, 255)]

BW_THRESHOLD = 128


def nearest_color(rgb, palette=None):
    """Devuelve el color mas cercano de la paleta al (r,g,b) dado.

    Usa distancia euclidea en espacio RGB.
    """
    if palette is None:
        palette = PALETTE_16
    r, g, b = rgb
    best = None
    best_dist = float("inf")
    for c in palette:
        cr, cg, cb = c
        d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
        if d < best_dist:
            best_dist = d
            best = c
    return best


def nearest_color_bw(rgb):
    """Convierte un pixel a B&W usando umbral de brillo."""
    r, g, b = rgb
    brightness = (r + g + b) / 3
    if brightness > BW_THRESHOLD:
        return (255, 255, 255)
    return (0, 0, 0)


def rgb_to_hex(c):
    """Convierte (r, g, b) a hex corto (#RGB) si es posible, sino #RRGGBB.

    Los 16 colores ZX Spectrum son todos abreviables (AA→A, 55→5, FF→F, 00→0).
    Esto ahorra 3 bytes por celda en el HTML generado.
    """
    r, g, b = c
    rh = "%02X" % r
    gh = "%02X" % g
    bh = "%02X" % b
    if rh[0] == rh[1] and gh[0] == gh[1] and bh[0] == bh[1]:
        return "#%s%s%s" % (rh[0], gh[0], bh[0])
    return "#%s%s%s" % (rh, gh, bh)
