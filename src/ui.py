"""Renderizado de la interfaz pygame estilo ZX Spectrum."""

import pygame
from PIL import Image


# ---------------------------------------------------------------------------
# Colores de la UI (subconjunto de la paleta ZX)
# ---------------------------------------------------------------------------

COL_BLACK   = (0, 0, 0)
COL_WHITE   = (255, 255, 255)
COL_GREEN   = (85, 255, 85)
COL_CYAN    = (85, 255, 255)
COL_YELLOW  = (255, 255, 85)
COL_RED     = (255, 85, 85)
COL_GRAY    = (85, 85, 85)
COL_BORDER  = (0, 170, 170)

# Colores del modo secreto SCR viewer
SCR_GREEN_D  = (0,   170, 0)
SCR_GREEN_B  = (85,  255, 85)
SCR_RED      = (255, 85,  85)
SCR_MAG_B    = (255, 85,  255)
SCR_MAG_D    = (170, 0,   170)

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

WINDOW_W = 1024
WINDOW_H = 700

HEADER_H = 40
STATUS_H = 60
CONTROLS_H = 36
SEPARATOR_H = 2

PREVIEW_Y = HEADER_H + SEPARATOR_H
PREVIEW_H = WINDOW_H - HEADER_H - STATUS_H - CONTROLS_H - SEPARATOR_H * 3
PREVIEW_W = WINDOW_W

MARGIN = 16


class UI:
    def __init__(self, screen):
        self.screen = screen
        self.font_big = pygame.font.SysFont("courier", 22, bold=True)
        self.font_med = pygame.font.SysFont("courier", 16, bold=True)
        self.font_sml = pygame.font.SysFont("courier", 14)
        self.message_text = ""
        self.message_timer = 0

    def show_message(self, text, duration_ms=2500):
        self.message_text = text
        self.message_timer = pygame.time.get_ticks() + duration_ms

    def draw(self, state):
        self.screen.fill(COL_BLACK)
        if state.get("scr_mode"):
            self._draw_scr_viewer(state)
        else:
            self._draw_header()
            self._draw_separator(HEADER_H)
            self._draw_preview(state)
            self._draw_separator(PREVIEW_Y + PREVIEW_H)
            self._draw_status(state)
            self._draw_separator(WINDOW_H - CONTROLS_H - SEPARATOR_H)
            self._draw_controls(state)
            if state.get("export_menu"):
                self._draw_export_menu()
        self._draw_message()

    def _draw_header(self):
        title = self.font_big.render(
            "SPECTRUMIFY v0.1", True, COL_CYAN
        )
        copy = self.font_sml.render(
            "(c) 2026 JGF", True, COL_GRAY
        )
        self.screen.blit(title, (MARGIN, 8))
        self.screen.blit(copy, (WINDOW_W - copy.get_width() - MARGIN, 14))

    def _draw_separator(self, y):
        pygame.draw.rect(
            self.screen, COL_BORDER,
            (0, y, WINDOW_W, SEPARATOR_H)
        )

    def _draw_preview(self, state):
        area_y = PREVIEW_Y
        area_h = PREVIEW_H

        if state.get("original_pil_preview") is None:
            # Sin imagen cargada
            text = self.font_med.render(
                "Pulsa [L] para cargar una imagen", True, COL_GRAY
            )
            tx = (WINDOW_W - text.get_width()) // 2
            ty = area_y + (area_h - text.get_height()) // 2
            self.screen.blit(text, (tx, ty))
            return

        # Dividir la zona en dos mitades con un margen
        half_w = (WINDOW_W - MARGIN * 3) // 2
        avail_h = area_h - MARGIN * 2 - 20  # espacio para labels

        # Label
        lbl_orig = self.font_sml.render("ORIGINAL", True, COL_GRAY)
        lbl_quant = self.font_sml.render("PIXEL-ART", True, COL_GREEN)
        self.screen.blit(lbl_orig, (MARGIN, area_y + 4))
        self.screen.blit(
            lbl_quant, (MARGIN * 2 + half_w, area_y + 4)
        )

        img_y = area_y + 22

        zoom = state.get("zoom", 1.0)

        # Original: Lanczos (suavizado para reducir fotos)
        # Pixel-art: nearest-neighbor (bordes nitidos al ampliar)
        for pil_img, x_offset, resample in [
            (state["original_pil_preview"], MARGIN, Image.Resampling.LANCZOS),
            (state["quantized_pil_preview"], MARGIN * 2 + half_w, Image.Resampling.NEAREST),
        ]:
            pw, ph = pil_img.size
            fit_scale = min(half_w / pw, avail_h / ph)
            sc = fit_scale * zoom
            new_w = max(1, int(pw * sc))
            new_h = max(1, int(ph * sc))
            resized = pil_img.resize((new_w, new_h), resample)
            surf = pygame.image.fromstring(resized.tobytes(), resized.size, "RGB")

            # Centrar y recortar al area disponible
            cx = x_offset + (half_w - new_w) // 2
            cy = img_y + (avail_h - new_h) // 2
            clip_rect = pygame.Rect(x_offset, img_y, half_w, avail_h)
            self.screen.set_clip(clip_rect)
            self.screen.blit(surf, (cx, cy))
            self.screen.set_clip(None)

    def _draw_status(self, state):
        y = PREVIEW_Y + PREVIEW_H + SEPARATOR_H + 4

        mode_labels = {"16": "16 COLORES", "gray": "GRISES", "bw": "B&W"}
        mode_label = mode_labels.get(state["mode"], state["mode"])
        comp_labels = {"safari": "SAFARI-SAFE", "aggressive": "AGRESIVA", "none": "SIN COMPR."}
        comp_label = comp_labels.get(state["compression"], state["compression"])

        size_label = f"{state.get('size_name', 'MEDIUM')} ({state['target_width']})"
        zoom_label = f"{state.get('zoom', 1.0):.1f}x"

        line1_parts = [
            ("MODO: ", COL_WHITE),
            (mode_label, COL_YELLOW),
            ("    SIZE: ", COL_WHITE),
            (size_label, COL_YELLOW),
            ("    ZOOM: ", COL_WHITE),
            (zoom_label, COL_YELLOW),
            ("    CELDA: ", COL_WHITE),
            (str(state["cell_size"]), COL_YELLOW),
        ]

        x = MARGIN
        for text, color in line1_parts:
            surf = self.font_med.render(text, True, color)
            self.screen.blit(surf, (x, y))
            x += surf.get_width()

        y2 = y + 22
        info = state.get("info")

        line2_parts = [
            ("COMPRESION: ", COL_WHITE),
            (comp_label, COL_YELLOW),
        ]

        orig_size = state.get("original_file_size", 0)
        if orig_size > 0:
            from src.compressor import format_bytes
            line2_parts += [
                ("    PNG: ", COL_WHITE),
                (format_bytes(orig_size), COL_YELLOW),
            ]

        if info:
            from src.compressor import format_bytes
            raw = info.get("html_raw_size", 0)
            final = info.get("html_final_size", 0)
            pct = (100 * (raw - final) / raw) if raw > 0 else 0

            line2_parts += [
                ("    HTML: ", COL_WHITE),
                (format_bytes(raw), COL_YELLOW),
            ]
            if pct > 0:
                line2_parts += [
                    (" > ", COL_WHITE),
                    (format_bytes(final), COL_GREEN),
                    (f" (-{pct:.0f}%)", COL_GREEN),
                ]

        x = MARGIN
        for text, color in line2_parts:
            surf = self.font_med.render(text, True, color)
            self.screen.blit(surf, (x, y2))
            x += surf.get_width()


    def _draw_controls(self, state):
        y = WINDOW_H - CONTROLS_H + 8

        controls = [
            ("[L]", "OAD  "),
            ("[E]", "XPORT  "),
            ("[M]", "ODE  "),
            ("[S]", "IZE  "),
            ("[+/-]", " ZOOM  "),
            ("[C]", "OMPRESS  "),
            ("[Q]", "UIT"),
        ]

        x = MARGIN
        for key, label in controls:
            key_surf = self.font_med.render(key, True, COL_GREEN)
            label_surf = self.font_med.render(label, True, COL_WHITE)
            self.screen.blit(key_surf, (x, y))
            x += key_surf.get_width()
            self.screen.blit(label_surf, (x, y))
            x += label_surf.get_width()

    def _draw_message(self):
        now = pygame.time.get_ticks()
        if self.message_text and now < self.message_timer:
            surf = self.font_med.render(self.message_text, True, COL_BLACK)
            bg_w = surf.get_width() + 20
            bg_h = surf.get_height() + 10
            bg_x = (WINDOW_W - bg_w) // 2
            bg_y = PREVIEW_Y + PREVIEW_H // 2 - bg_h // 2

            pygame.draw.rect(
                self.screen, COL_YELLOW,
                (bg_x, bg_y, bg_w, bg_h)
            )
            self.screen.blit(surf, (bg_x + 10, bg_y + 5))

    def _draw_scr_viewer(self, state):
        """Modo secreto: visualizador de archivos .scr del ZX Spectrum."""
        # Header con colores secretos
        title = self.font_big.render("SCR VIEWER", True, SCR_RED)
        sub = self.font_sml.render("ZX Spectrum 48K", True, SCR_MAG_D)
        self.screen.blit(title, (MARGIN, 8))
        self.screen.blit(sub, (WINDOW_W - sub.get_width() - MARGIN, 14))

        # Separadores magenta
        pygame.draw.rect(self.screen, SCR_MAG_D, (0, HEADER_H, WINDOW_W, SEPARATOR_H))
        pygame.draw.rect(self.screen, SCR_MAG_D, (0, WINDOW_H - CONTROLS_H - SEPARATOR_H, WINDOW_W, SEPARATOR_H))

        # Imagen SCR centrada en el area de preview
        scr_img = state.get("scr_image")
        if scr_img:
            pw, ph = scr_img.size  # 256x192
            avail_w = WINDOW_W - MARGIN * 2
            avail_h = PREVIEW_H - MARGIN * 2
            sc = min(avail_w / pw, avail_h / ph)
            new_w = int(pw * sc)
            new_h = int(ph * sc)
            resized = scr_img.resize((new_w, new_h), Image.Resampling.NEAREST)
            surf = pygame.image.fromstring(resized.tobytes(), resized.size, "RGB")
            cx = (WINDOW_W - new_w) // 2
            cy = PREVIEW_Y + (PREVIEW_H - new_h) // 2
            # Borde magenta alrededor de la imagen
            pygame.draw.rect(self.screen, SCR_MAG_D,
                             (cx - 2, cy - 2, new_w + 4, new_h + 4), 2)
            self.screen.blit(surf, (cx, cy))

        # Info bar
        from src.compressor import format_bytes
        info_y = WINDOW_H - CONTROLS_H - SEPARATOR_H - 30
        info_parts = [
            ("256x192  ", SCR_MAG_B),
            ("6,912 bytes  ", SCR_GREEN_B),
            (format_bytes(state.get("original_file_size", 0)), SCR_GREEN_D),
        ]
        x = MARGIN
        for text, color in info_parts:
            s = self.font_med.render(text, True, color)
            self.screen.blit(s, (x, info_y))
            x += s.get_width()

        # Controles
        y = WINDOW_H - CONTROLS_H + 8
        controls = [("[L]", "OAD  "), ("[E]", "XPORT  "), ("[Q]", "UIT")]
        x = MARGIN
        for key, label in controls:
            key_surf = self.font_med.render(key, True, SCR_GREEN_B)
            label_surf = self.font_med.render(label, True, SCR_GREEN_D)
            self.screen.blit(key_surf, (x, y))
            x += key_surf.get_width()
            self.screen.blit(label_surf, (x, y))
            x += label_surf.get_width()

    def _draw_export_menu(self):
        lines = [
            ("EXPORTAR COMO:", COL_CYAN),
            ("", None),
            ("[H]  HTML  -  Tabla pixel-art", COL_WHITE),
            ("[S]  SCR   -  Nativo ZX Spectrum", COL_WHITE),
            ("[G]  GIF   -  Imagen retro (1987)", COL_WHITE),
            ("", None),
            ("[ESC] Cancelar", COL_GRAY),
        ]

        line_h = 24
        box_w = 460
        box_h = len(lines) * line_h + 20
        box_x = (WINDOW_W - box_w) // 2
        box_y = PREVIEW_Y + (PREVIEW_H - box_h) // 2

        # Fondo y borde
        pygame.draw.rect(self.screen, COL_BLACK, (box_x, box_y, box_w, box_h))
        pygame.draw.rect(self.screen, COL_BORDER, (box_x, box_y, box_w, box_h), 2)

        for i, (text, color) in enumerate(lines):
            if not text:
                continue
            # Resaltar la letra entre corchetes
            if text.startswith("["):
                bracket_end = text.index("]") + 1
                key_surf = self.font_med.render(text[:bracket_end], True, COL_GREEN)
                rest_surf = self.font_med.render(text[bracket_end:], True, color)
                self.screen.blit(key_surf, (box_x + 20, box_y + 10 + i * line_h))
                self.screen.blit(rest_surf, (box_x + 20 + key_surf.get_width(), box_y + 10 + i * line_h))
            else:
                surf = self.font_med.render(text, True, color)
                self.screen.blit(surf, (box_x + 20, box_y + 10 + i * line_h))
