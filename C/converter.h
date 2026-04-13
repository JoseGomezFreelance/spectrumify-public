#ifndef CONVERTER_H
#define CONVERTER_H

#include "palette.h"
#include <stdlib.h>
#include <math.h>

/* Calcula dimensiones preservando ratio. Devuelve ancho y alto finales. */
static inline void calculate_dimensions(int orig_w, int orig_h, int target_w,
                                         int *out_w, int *out_h) {
    if (target_w <= 0) { *out_w = orig_w; *out_h = orig_h; return; }
    double ratio = (double)orig_w / orig_h;
    *out_w = target_w;
    *out_h = (int)round(target_w / ratio);
    if (*out_h < 1) *out_h = 1;
}

/* Resize bilinear simple. Caller debe free() el resultado. */
static uint8_t *resize_image(const uint8_t *src, int sw, int sh,
                              int dw, int dh) {
    uint8_t *dst = (uint8_t *)malloc(dw * dh * 3);
    if (!dst) return NULL;

    for (int y = 0; y < dh; y++) {
        double sy = (double)y * sh / dh;
        int y0 = (int)sy;
        int y1 = y0 + 1 < sh ? y0 + 1 : y0;
        double fy = sy - y0;

        for (int x = 0; x < dw; x++) {
            double sx = (double)x * sw / dw;
            int x0 = (int)sx;
            int x1 = x0 + 1 < sw ? x0 + 1 : x0;
            double fx = sx - x0;

            for (int c = 0; c < 3; c++) {
                double v00 = src[(y0 * sw + x0) * 3 + c];
                double v10 = src[(y0 * sw + x1) * 3 + c];
                double v01 = src[(y1 * sw + x0) * 3 + c];
                double v11 = src[(y1 * sw + x1) * 3 + c];
                double v = v00*(1-fx)*(1-fy) + v10*fx*(1-fy)
                         + v01*(1-fx)*fy     + v11*fx*fy;
                dst[(y * dw + x) * 3 + c] = (uint8_t)(v + 0.5);
            }
        }
    }
    return dst;
}

/* Cuantiza imagen in-place a la paleta del modo indicado. */
static void quantize_image(uint8_t *pixels, int w, int h, int mode) {
    int n;
    const Color *pal = mode_palette(mode, &n);
    int total = w * h;

    for (int i = 0; i < total; i++) {
        Color c = nearest_color(pixels[i*3], pixels[i*3+1], pixels[i*3+2], pal, n);
        pixels[i*3]   = c.r;
        pixels[i*3+1] = c.g;
        pixels[i*3+2] = c.b;
    }
}

#endif
