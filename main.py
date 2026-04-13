#!/usr/bin/env python3
"""Spectrumify — Conversor de imagenes a pixel-art HTML con paleta ZX Spectrum."""

import pygame

from src.app import App
from src.ui import WINDOW_W, WINDOW_H


def main():
    pygame.init()
    screen = pygame.display.set_mode((WINDOW_W, WINDOW_H))
    pygame.display.set_caption("Spectrumify v0.1")

    app = App(screen)
    app.run()

    pygame.quit()


if __name__ == "__main__":
    main()
