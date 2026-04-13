#ifndef PALETTE_H
#define PALETTE_H

#include <stdint.h>
#include <stdio.h>
#include <limits.h>

typedef struct { uint8_t r, g, b; } Color;

/* Paleta ZX Spectrum: 16 colores */
static const Color PALETTE_16[] = {
    {0,0,0},       {0,0,170},     {170,0,0},     {170,0,170},
    {0,170,0},     {0,170,170},   {170,85,0},    {170,170,170},
    {85,85,85},    {85,85,255},   {255,85,85},   {255,85,255},
    {85,255,85},   {85,255,255},  {255,255,85},  {255,255,255},
};

static const Color PALETTE_GRAY[] = {
    {0,0,0}, {85,85,85}, {170,170,170}, {255,255,255},
};

static const Color PALETTE_BW[] = {
    {0,0,0}, {255,255,255},
};

enum { MODE_16 = 0, MODE_GRAY = 1, MODE_BW = 2 };

static inline const Color *mode_palette(int mode, int *n) {
    switch (mode) {
        case MODE_GRAY: *n = 4;  return PALETTE_GRAY;
        case MODE_BW:   *n = 2;  return PALETTE_BW;
        default:        *n = 16; return PALETTE_16;
    }
}

static inline Color nearest_color(uint8_t r, uint8_t g, uint8_t b,
                                   const Color *pal, int n) {
    int best = 0, best_dist = INT_MAX;
    for (int i = 0; i < n; i++) {
        int dr = r - pal[i].r;
        int dg = g - pal[i].g;
        int db = b - pal[i].b;
        int d = dr*dr + dg*dg + db*db;
        if (d < best_dist) { best_dist = d; best = i; }
    }
    return pal[best];
}

/* Hex corto (#RGB) si los digitos se repiten, sino #RRGGBB */
static inline int rgb_to_hex(uint8_t r, uint8_t g, uint8_t b, char *buf) {
    int rh = r >> 4, rl = r & 0xF;
    int gh = g >> 4, gl = g & 0xF;
    int bh = b >> 4, bl = b & 0xF;
    if (rh == rl && gh == gl && bh == bl)
        return sprintf(buf, "#%X%X%X", rh, gh, bh);
    return sprintf(buf, "#%02X%02X%02X", r, g, b);
}

#endif
