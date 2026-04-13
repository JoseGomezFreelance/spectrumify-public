"""Loop principal y manejo de eventos de Spectrumify."""

import os
import platform
import subprocess

import pygame
from PIL import Image

from src.converter import convert_image, quantize_image, calculate_dimensions
from src.compressor import compress_html, format_bytes
from src.exporter import export_html, export_gif, export_scr, load_scr
from src.ui import UI, WINDOW_W, WINDOW_H


def _pil_to_surface(img):
    """Convierte una imagen PIL RGB a pygame.Surface."""
    data = img.tobytes()
    return pygame.image.fromstring(data, img.size, "RGB")


def _open_file_dialog():
    """Abre un dialogo nativo para seleccionar imagen.

    Usa osascript en macOS para evitar el conflicto SDL/tkinter.
    """
    if platform.system() == "Darwin":
        script = (
            'set theFile to choose file with prompt "Cargar imagen" '
            'of type {"public.image", "public.data"}\n'
            'return POSIX path of theFile'
        )
        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True, text=True, timeout=60,
            )
            path = result.stdout.strip()
            return path if path else None
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
    else:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        path = filedialog.askopenfilename(
            title="Cargar imagen",
            filetypes=[
                ("Imagenes", "*.png *.jpg *.jpeg *.bmp *.gif *.tiff *.webp"),
                ("Todos", "*.*"),
            ],
        )
        root.destroy()
        return path if path else None


def _save_file_dialog(default_name="output.html", ext=".html"):
    """Abre un dialogo nativo para guardar archivo.

    Usa osascript en macOS para evitar el conflicto SDL/tkinter.
    """
    if platform.system() == "Darwin":
        script = (
            f'set theFile to choose file name with prompt "Exportar" '
            f'default name "{default_name}"\n'
            f'return POSIX path of theFile'
        )
        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                capture_output=True, text=True, timeout=60,
            )
            path = result.stdout.strip()
            if path and not path.endswith(ext):
                path += ext
            return path if path else None
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
    else:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        path = filedialog.asksaveasfilename(
            title="Exportar",
            defaultextension=ext,
            initialfile=default_name,
        )
        root.destroy()
        return path if path else None


class App:
    def __init__(self, screen):
        self.screen = screen
        self.ui = UI(screen)
        self.clock = pygame.time.Clock()
        self.running = True

        # Estado
        self.image_path = None
        self.original_file_size = 0
        self.original_image = None       # PIL Image (full res)
        self.quantized_image = None      # PIL Image (cuantizado)
        self.sizes = {"SMALL": 80, "MEDIUM": 153, "BIG": 256}
        self.size_cycle = ["SMALL", "MEDIUM", "BIG"]
        self.size_index = 1              # MEDIUM por defecto
        self.target_width = self.sizes[self.size_cycle[self.size_index]]
        self.zoom = 1.0                  # factor de zoom del preview
        self.cell_size = 3
        self.mode = "16"                 # "16" o "bw"
        self.compression = "safari"      # "safari", "aggressive", "none"
        self.info = None                 # dict de dimensiones
        self.export_menu = False         # submenu de exportacion activo
        self.scr_mode = False            # modo secreto SCR viewer
        self.scr_image = None            # PIL Image del SCR cargado

    def _get_state(self):
        return {
            "original_pil_preview": self.original_image,
            "quantized_pil_preview": self.quantized_image,
            "mode": self.mode,
            "size_name": self.size_cycle[self.size_index],
            "zoom": self.zoom,
            "compression": self.compression,
            "target_width": self.target_width,
            "cell_size": self.cell_size,
            "info": self.info,
            "original_file_size": self.original_file_size,
            "export_menu": self.export_menu,
            "scr_mode": self.scr_mode,
            "scr_image": self.scr_image,
        }

    def load_image(self):
        path = _open_file_dialog()
        if not path:
            return

        self.image_path = path
        self.original_file_size = os.path.getsize(path)

        # Modo secreto: cargar archivos .scr del ZX Spectrum
        if path.lower().endswith(".scr"):
            scr_img = load_scr(path)
            if scr_img is None:
                self.ui.show_message("Error: SCR invalido")
                return
            self.scr_mode = True
            self.scr_image = scr_img
            self.original_image = None
            self.quantized_image = None
            self.info = None
            self.ui.show_message("SCR LOADED - ZX SPECTRUM 48K READY")
            return

        self.scr_mode = False
        self.scr_image = None
        self.original_image = Image.open(path).convert("RGB")
        self._update_preview()
        self.ui.show_message(f"Cargada: {os.path.basename(path)}")

    def _update_preview(self):
        if self.original_image is None:
            return

        orig_w, orig_h = self.original_image.size
        final_w, final_h = calculate_dimensions(
            orig_w, orig_h, self.target_width, None
        )
        resized = self.original_image.resize(
            (final_w, final_h), Image.Resampling.LANCZOS
        )
        self.quantized_image = quantize_image(resized, self.mode)

        # Estimar tamano HTML generando en memoria
        from src.palette import rgb_to_hex
        pixels = self.quantized_image.load()
        html_lines = ['<table cellpadding="0" cellspacing="0">']
        for y in range(final_h):
            html_lines.append("<tr>")
            for x in range(final_w):
                hex_color = rgb_to_hex(pixels[x, y])
                html_lines.append(
                    f'<td width="{self.cell_size}" height="{self.cell_size}" '
                    f'bgcolor="{hex_color}"></td>'
                )
            html_lines.append("</tr>")
        html_lines.append("</table>")
        html_raw = "\n".join(html_lines)

        aggressive = self.compression == "aggressive"
        if self.compression == "none":
            html_size = len(html_raw)
        else:
            _, comp_stats = compress_html(html_raw, aggressive=aggressive)
            html_size = comp_stats["bytes_after"]

        self.info = {
            "orig_w": orig_w,
            "orig_h": orig_h,
            "final_w": final_w,
            "final_h": final_h,
            "total_cells": final_w * final_h,
            "cell_size": self.cell_size,
            "html_raw_size": len(html_raw),
            "html_final_size": html_size,
        }

    def _export_suffix(self):
        return {"16": "_zx", "gray": "_gray", "bw": "_ByN"}[self.mode]

    def export_as(self, fmt):
        """Exporta en el formato indicado: 'html', 'gif', 'scr'."""
        if self.image_path is None:
            self.ui.show_message("No hay imagen cargada")
            return

        base = os.path.splitext(os.path.basename(self.image_path))[0]
        suffix = self._export_suffix()

        if fmt == "html":
            default_name = f"{base}{suffix}.html"
            path = _save_file_dialog(default_name, ".html")
            if not path:
                return
            export_html(
                self.image_path,
                target_w=self.target_width,
                cell_size=self.cell_size,
                mode=self.mode,
                compression=self.compression,
                output_path=path,
            )
        elif fmt == "gif":
            default_name = f"{base}{suffix}.gif"
            path = _save_file_dialog(default_name, ".gif")
            if not path:
                return
            export_gif(
                self.image_path,
                target_w=self.target_width,
                mode=self.mode,
                output_path=path,
            )
        elif fmt == "scr":
            default_name = f"{base}{suffix}.scr"
            path = _save_file_dialog(default_name, ".scr")
            if not path:
                return
            export_scr(
                self.image_path,
                mode=self.mode,
                output_path=path,
            )

        self.ui.show_message(f"Exportado: {os.path.basename(path)}")

    def _export_scr_direct(self):
        """Exporta la imagen SCR cargada directamente como GIF."""
        if self.scr_image is None:
            return
        base = os.path.splitext(os.path.basename(self.image_path))[0]
        default_name = f"{base}.gif"
        path = _save_file_dialog(default_name, ".gif")
        if not path:
            return
        self.scr_image.save(path)
        self.ui.show_message(f"Exportado: {os.path.basename(path)}")

    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                return

            if event.type == pygame.KEYDOWN:
                # Submenu de exportacion activo
                if self.export_menu:
                    if event.key == pygame.K_h:
                        self.export_menu = False
                        self.export_as("html")
                    elif event.key == pygame.K_s:
                        self.export_menu = False
                        self.export_as("scr")
                    elif event.key == pygame.K_g:
                        self.export_menu = False
                        self.export_as("gif")
                    elif event.key == pygame.K_ESCAPE:
                        self.export_menu = False
                    return

                if event.key == pygame.K_q:
                    self.running = False
                elif event.key == pygame.K_l:
                    self.load_image()
                elif event.key == pygame.K_e:
                    if self.scr_mode:
                        self._export_scr_direct()
                        return
                    elif self.image_path is None:
                        self.ui.show_message("No hay imagen cargada")
                    else:
                        self.export_menu = True
                elif event.key == pygame.K_m:
                    cycle_mode = {"16": "gray", "gray": "bw", "bw": "16"}
                    self.mode = cycle_mode[self.mode]
                    self._update_preview()
                elif event.key == pygame.K_s:
                    self.size_index = (self.size_index + 1) % len(self.size_cycle)
                    self.target_width = self.sizes[self.size_cycle[self.size_index]]
                    self.zoom = 1.0
                    self._update_preview()
                elif event.key in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
                    self.zoom = min(8.0, self.zoom + 0.5)
                elif event.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                    self.zoom = max(0.5, self.zoom - 0.5)
                elif event.key == pygame.K_c:
                    cycle = {"safari": "aggressive", "aggressive": "none", "none": "safari"}
                    self.compression = cycle[self.compression]
                    self._update_preview()

    def run(self):
        while self.running:
            self.handle_events()
            self.ui.draw(self._get_state())
            pygame.display.flip()
            self.clock.tick(30)
