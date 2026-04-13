#ifndef EXPORTER_H
#define EXPORTER_H

#include "palette.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Export HTML (sin compresion — la compresion es compleja en C puro   */
/* y el HTML sin comprimir ya es funcional)                            */
/* ------------------------------------------------------------------ */

static int export_html(const uint8_t *pixels, int w, int h, int cell_size,
                        const char *path) {
    FILE *f = fopen(path, "w");
    if (!f) return -1;

    fprintf(f, "<table cellpadding=\"0\" cellspacing=\"0\">\n");
    for (int y = 0; y < h; y++) {
        fprintf(f, "<tr>");
        for (int x = 0; x < w; x++) {
            char hex[8];
            int idx = (y * w + x) * 3;
            rgb_to_hex(pixels[idx], pixels[idx+1], pixels[idx+2], hex);
            fprintf(f, "<td width=\"%d\" height=\"%d\" bgcolor=\"%s\"></td>",
                    cell_size, cell_size, hex);
        }
        fprintf(f, "</tr>\n");
    }
    fprintf(f, "</table>\n");
    fclose(f);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Export SCR (formato nativo ZX Spectrum, 6912 bytes)                 */
/* ------------------------------------------------------------------ */

/* Mapa de colores a atributo ZX: (indice 0-7, bright 0/1) */
typedef struct { uint8_t idx; uint8_t bright; } ZXAttr;

static ZXAttr color_to_zx_attr(uint8_t r, uint8_t g, uint8_t b) {
    /* Tabla de los 16 colores de nuestra paleta */
    static const struct { uint8_t r,g,b; ZXAttr a; } MAP[] = {
        {0,0,0,       {0,0}}, {0,0,170,     {1,0}}, {170,0,0,     {2,0}},
        {170,0,170,   {3,0}}, {0,170,0,     {4,0}}, {0,170,170,   {5,0}},
        {170,85,0,    {6,0}}, {170,170,170, {7,0}}, {85,85,85,    {0,1}},
        {85,85,255,   {1,1}}, {255,85,85,   {2,1}}, {255,85,255,  {3,1}},
        {85,255,85,   {4,1}}, {85,255,255,  {5,1}}, {255,255,85,  {6,1}},
        {255,255,255, {7,1}},
    };
    for (int i = 0; i < 16; i++) {
        if (MAP[i].r == r && MAP[i].g == g && MAP[i].b == b)
            return MAP[i].a;
    }
    return (ZXAttr){0, 0};
}

static int export_scr(const uint8_t *pixels, int w, int h, const char *path) {
    /* Necesita imagen de 256x192 — caller debe redimensionar antes */
    if (w != 256 || h != 192) return -1;

    uint8_t bitmap[6144] = {0};
    uint8_t attrs[768] = {0};

    for (int by = 0; by < 24; by++) {
        for (int bx = 0; bx < 32; bx++) {
            /* Contar colores en el bloque 8x8 */
            Color colors[64];
            int count[64] = {0};
            int unique = 0;

            for (int dy = 0; dy < 8; dy++) {
                for (int dx = 0; dx < 8; dx++) {
                    int idx = ((by*8+dy)*256 + bx*8+dx) * 3;
                    Color c = {pixels[idx], pixels[idx+1], pixels[idx+2]};
                    int found = 0;
                    for (int k = 0; k < unique; k++) {
                        if (colors[k].r==c.r && colors[k].g==c.g && colors[k].b==c.b) {
                            count[k]++;
                            found = 1;
                            break;
                        }
                    }
                    if (!found && unique < 64) {
                        colors[unique] = c;
                        count[unique] = 1;
                        unique++;
                    }
                }
            }

            /* Paper = mas comun, ink = segundo mas comun */
            int p_idx = 0, i_idx = 0;
            int p_max = 0, i_max = 0;
            for (int k = 0; k < unique; k++) {
                if (count[k] > p_max) { i_max = p_max; i_idx = p_idx; p_max = count[k]; p_idx = k; }
                else if (count[k] > i_max) { i_max = count[k]; i_idx = k; }
            }
            if (unique == 1) i_idx = p_idx;

            Color paper_c = colors[p_idx];
            Color ink_c = colors[i_idx];
            ZXAttr pa = color_to_zx_attr(paper_c.r, paper_c.g, paper_c.b);
            ZXAttr ia = color_to_zx_attr(ink_c.r, ink_c.g, ink_c.b);
            uint8_t bright = (pa.bright || ia.bright) ? 1 : 0;
            attrs[by*32+bx] = (bright << 6) | (pa.idx << 3) | ia.idx;

            /* Bitmap: 1=ink, 0=paper */
            for (int dy = 0; dy < 8; dy++) {
                uint8_t byte_val = 0;
                for (int dx = 0; dx < 8; dx++) {
                    int idx = ((by*8+dy)*256 + bx*8+dx) * 3;
                    Color c = {pixels[idx], pixels[idx+1], pixels[idx+2]};
                    /* Es ink? */
                    int is_ink = (c.r==ink_c.r && c.g==ink_c.g && c.b==ink_c.b);
                    if (!is_ink && !(c.r==paper_c.r && c.g==paper_c.g && c.b==paper_c.b)) {
                        /* Tercer color: elegir mas cercano */
                        int di = (c.r-ink_c.r)*(c.r-ink_c.r) + (c.g-ink_c.g)*(c.g-ink_c.g) + (c.b-ink_c.b)*(c.b-ink_c.b);
                        int dp = (c.r-paper_c.r)*(c.r-paper_c.r) + (c.g-paper_c.g)*(c.g-paper_c.g) + (c.b-paper_c.b)*(c.b-paper_c.b);
                        is_ink = (di < dp);
                    }
                    if (is_ink) byte_val |= (0x80 >> dx);
                }
                int py = by*8 + dy;
                int offset = ((py & 0xC0) << 5) | ((py & 0x07) << 8) | ((py & 0x38) << 2) | bx;
                bitmap[offset] = byte_val;
            }
        }
    }

    FILE *f = fopen(path, "wb");
    if (!f) return -1;
    fwrite(bitmap, 1, 6144, f);
    fwrite(attrs, 1, 768, f);
    fclose(f);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Export BMP via stb_image_write                                      */
/* ------------------------------------------------------------------ */

#ifndef STB_IMAGE_WRITE_IMPLEMENTATION
/* Se define en main.c */
#endif

static int export_bmp(const uint8_t *pixels, int w, int h, const char *path);
/* Implementado en main.c despues de definir STB_IMAGE_WRITE_IMPLEMENTATION */

#endif
