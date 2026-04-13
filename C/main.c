/*
 * Spectrumify — Version C + SDL2
 * Conversor de imagenes a pixel-art HTML con paleta ZX Spectrum
 * (c) 2026 JGF
 *
 * Compilar: make
 * Ejecutar: ./spectrumify
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define MSF_GIF_IMPL
#include "msf_gif.h"

#include <SDL.h>

#include "palette.h"
#include "converter.h"
#include "exporter.h"
#include "ui.h"

/* Export BMP via stb_image_write */
static int export_bmp(const uint8_t *pixels, int w, int h, const char *path) {
    return stbi_write_bmp(path, w, h, 3, pixels) ? 0 : -1;
}

/* Export GIF via msf_gif */
static int export_gif(const uint8_t *rgb, int w, int h, const char *path) {
    /* msf_gif necesita RGBA, convertir desde RGB */
    uint8_t *rgba = (uint8_t *)malloc(w * h * 4);
    if (!rgba) return -1;
    for (int i = 0; i < w * h; i++) {
        rgba[i*4]   = rgb[i*3];
        rgba[i*4+1] = rgb[i*3+1];
        rgba[i*4+2] = rgb[i*3+2];
        rgba[i*4+3] = 255;
    }
    MsfGifState state = {0};
    msf_gif_begin(&state, w, h);
    msf_gif_frame(&state, rgba, 0, 16, w * 4);
    MsfGifResult result = msf_gif_end(&state);
    free(rgba);
    if (!result.data) return -1;

    FILE *f = fopen(path, "wb");
    if (!f) { msf_gif_free(result); return -1; }
    fwrite(result.data, 1, result.dataSize, f);
    fclose(f);
    msf_gif_free(result);
    return 0;
}

/* ------------------------------------------------------------------ */
/* Dialogos nativos (osascript en macOS)                               */
/* ------------------------------------------------------------------ */

static int open_file_dialog(char *buf, int bufsize) {
    FILE *p = popen("osascript -e 'set f to choose file with prompt "
                    "\"Cargar imagen\" of type {\"public.image\",\"public.data\"}' "
                    "-e 'return POSIX path of f' 2>/dev/null", "r");
    if (!p) return 0;
    if (!fgets(buf, bufsize, p)) { pclose(p); return 0; }
    pclose(p);
    buf[strcspn(buf, "\n")] = 0;
    return buf[0] != 0;
}

static int save_file_dialog(char *buf, int bufsize, const char *default_name,
                             const char *ext) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
        "osascript -e 'set f to choose file name with prompt \"Exportar\" "
        "default name \"%s\"' -e 'return POSIX path of f' 2>/dev/null",
        default_name);
    FILE *p = popen(cmd, "r");
    if (!p) return 0;
    if (!fgets(buf, bufsize, p)) { pclose(p); return 0; }
    pclose(p);
    buf[strcspn(buf, "\n")] = 0;
    if (buf[0] && !strstr(buf, ext)) strcat(buf, ext);
    return buf[0] != 0;
}

/* ------------------------------------------------------------------ */
/* Estado de la app                                                    */
/* ------------------------------------------------------------------ */

typedef struct {
    char image_path[1024];
    uint8_t *original;       /* pixels RGB originales (full res) */
    int orig_w, orig_h;
    uint8_t *quantized;      /* pixels RGB cuantizados (target size) */
    int quant_w, quant_h;
    SDL_Texture *orig_tex;
    SDL_Texture *quant_tex;
    int mode;                /* MODE_16, MODE_GRAY, MODE_BW */
    int size_index;
    int target_width;
    int cell_size;
    int compression;         /* 0=safari, 1=aggressive, 2=none */
    float zoom;
    int export_menu;
    int running;
    long file_size;          /* tamano del archivo original */
    long html_raw_size;      /* tamano HTML sin comprimir */
    long html_comp_size;     /* tamano HTML comprimido (estimado) */
    /* Modo SCR viewer */
    int scr_mode;
    uint8_t *scr_pixels;     /* imagen renderizada del SCR (256x192) */
    SDL_Texture *scr_tex;
} AppState;

static const int SIZES[] = {80, 153, 256};
static const char *SIZE_NAMES[] = {"SMALL", "MEDIUM", "BIG"};
static const char *MODE_NAMES[] = {"16 COLORES", "GRISES", "B&W"};
static const char *COMP_NAMES[] = {"SAFARI-SAFE", "AGRESIVA", "SIN COMPR."};
static const char *MODE_SUFFIX[] = {"_zx", "_gray", "_ByN"};

static void estimate_html_sizes(AppState *st); /* forward declaration */

static SDL_Texture *pixels_to_texture(SDL_Renderer *ren, const uint8_t *px,
                                       int w, int h) {
    SDL_Texture *tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_RGB24,
                                          SDL_TEXTUREACCESS_STATIC, w, h);
    if (tex) SDL_UpdateTexture(tex, NULL, px, w * 3);
    return tex;
}

static void update_preview(AppState *st, SDL_Renderer *ren) {
    if (!st->original) return;

    if (st->quantized) free(st->quantized);
    if (st->quant_tex) SDL_DestroyTexture(st->quant_tex);

    calculate_dimensions(st->orig_w, st->orig_h, st->target_width,
                          &st->quant_w, &st->quant_h);

    st->quantized = resize_image(st->original, st->orig_w, st->orig_h,
                                  st->quant_w, st->quant_h);
    quantize_image(st->quantized, st->quant_w, st->quant_h, st->mode);

    st->quant_tex = pixels_to_texture(ren, st->quantized,
                                       st->quant_w, st->quant_h);
    /* Nearest-neighbor para pixel-art */
    SDL_SetTextureScaleMode(st->quant_tex, SDL_ScaleModeNearest);

    estimate_html_sizes(st);
}

/* Calcula tamano real del HTML y estima compresion analizando los pixeles */
static void estimate_html_sizes(AppState *st) {
    if (!st->quantized || st->quant_w == 0) return;

    int w = st->quant_w, h = st->quant_h;

    /* Tamano real del HTML raw: generar cada celda y medir */
    long raw = 42; /* <table cellpadding="0" cellspacing="0">\n...\n</table>\n */
    for (int y = 0; y < h; y++) {
        raw += 9; /* <tr></tr>\n */
        for (int x = 0; x < w; x++) {
            char hex[8];
            int idx = (y * w + x) * 3;
            rgb_to_hex(st->quantized[idx], st->quantized[idx+1], st->quantized[idx+2], hex);
            /* <td width="3" height="3" bgcolor="#XXX"></td> */
            raw += 39 + (int)strlen(hex);
        }
    }
    st->html_raw_size = raw;

    /* Estimar compresion analizando los datos reales */
    if (st->compression == 2) { /* none */
        st->html_comp_size = raw;
        return;
    }

    if (st->compression == 1) { /* aggressive: contar runs horizontales */
        long comp = 42;
        for (int y = 0; y < h; y++) {
            comp += 30; /* <tr height="3">...</tr> */
            int runs = 0;
            for (int x = 0; x < w; x++) {
                if (x == 0) { runs++; continue; }
                int i0 = (y*w + x-1)*3, i1 = (y*w + x)*3;
                if (st->quantized[i0] != st->quantized[i1] ||
                    st->quantized[i0+1] != st->quantized[i1+1] ||
                    st->quantized[i0+2] != st->quantized[i1+2])
                    runs++;
            }
            /* Cada run: ~35 bytes (con colspan) vs ~43 por celda individual */
            comp += (long)runs * 38;
        }
        st->html_comp_size = comp;
        return;
    }

    /* safari-safe: contar filas identicas consecutivas */
    long comp = 42;
    int y = 0;
    while (y < h) {
        /* Contar filas identicas a esta */
        int identical = 1;
        for (int j = y+1; j < h; j++) {
            int same = 1;
            for (int x = 0; x < w*3; x++) {
                if (st->quantized[y*w*3 + x] != st->quantized[j*w*3 + x]) {
                    same = 0; break;
                }
            }
            if (same) identical++; else break;
        }

        if (identical >= 2) {
            /* Filas fusionadas con rowspan: contar runs + rowspan */
            int runs = 0;
            for (int x = 0; x < w; x++) {
                if (x == 0) { runs++; continue; }
                int i0 = (y*w + x-1)*3, i1 = (y*w + x)*3;
                if (st->quantized[i0] != st->quantized[i1] ||
                    st->quantized[i0+1] != st->quantized[i1+1] ||
                    st->quantized[i0+2] != st->quantized[i1+2])
                    runs++;
            }
            comp += (long)runs * 50; /* celdas con rowspan+colspan */
            comp += (long)(identical - 1) * 12; /* <tr></tr> vacios */
        } else {
            /* Fila individual: celdas normales */
            comp += 9;
            for (int x = 0; x < w; x++) {
                char hex[8];
                int idx = (y*w + x)*3;
                rgb_to_hex(st->quantized[idx], st->quantized[idx+1], st->quantized[idx+2], hex);
                comp += 39 + (int)strlen(hex);
            }
        }
        y += identical;
    }
    st->html_comp_size = comp;
}

/* Cargar y renderizar un archivo .scr del ZX Spectrum */
static int load_scr_file(const char *path, uint8_t *out_pixels) {
    static const Color ZX_PAL[2][8] = {
        {{0,0,0},{0,0,170},{170,0,0},{170,0,170},{0,170,0},{0,170,170},{170,170,0},{170,170,170}},
        {{0,0,0},{0,0,255},{255,0,0},{255,0,255},{0,255,0},{0,255,255},{255,255,0},{255,255,255}},
    };
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    uint8_t data[6912];
    if (fread(data, 1, 6912, f) != 6912) { fclose(f); return 0; }
    fclose(f);

    for (int y = 0; y < 192; y++) {
        int offset = ((y&0xC0)<<5) | ((y&0x07)<<8) | ((y&0x38)<<2);
        for (int col = 0; col < 32; col++) {
            uint8_t byte = data[offset + col];
            uint8_t attr = data[6144 + (y/8)*32 + col];
            int ink = attr & 7, paper = (attr>>3) & 7, bright = (attr>>6) & 1;
            for (int bit = 0; bit < 8; bit++) {
                Color c = (byte & (0x80>>bit)) ? ZX_PAL[bright][ink] : ZX_PAL[bright][paper];
                int px_idx = (y*256 + col*8 + bit) * 3;
                out_pixels[px_idx] = c.r;
                out_pixels[px_idx+1] = c.g;
                out_pixels[px_idx+2] = c.b;
            }
        }
    }
    return 1;
}

static void load_image(AppState *st, SDL_Renderer *ren) {
    char path[1024];
    if (!open_file_dialog(path, sizeof(path))) return;

    /* File size */
    FILE *fsz = fopen(path, "rb");
    if (fsz) { fseek(fsz, 0, SEEK_END); st->file_size = ftell(fsz); fclose(fsz); }

    strncpy(st->image_path, path, sizeof(st->image_path)-1);

    /* Detectar .scr */
    int len = (int)strlen(path);
    if (len > 4 && strcasecmp(path + len - 4, ".scr") == 0) {
        uint8_t *scr_px = (uint8_t *)malloc(256 * 192 * 3);
        if (scr_px && load_scr_file(path, scr_px)) {
            if (st->scr_pixels) free(st->scr_pixels);
            if (st->scr_tex) SDL_DestroyTexture(st->scr_tex);
            st->scr_pixels = scr_px;
            st->scr_tex = pixels_to_texture(ren, scr_px, 256, 192);
            SDL_SetTextureScaleMode(st->scr_tex, SDL_ScaleModeNearest);
            st->scr_mode = 1;
            /* Limpiar estado normal */
            if (st->original) { free(st->original); st->original = NULL; }
            if (st->orig_tex) { SDL_DestroyTexture(st->orig_tex); st->orig_tex = NULL; }
            if (st->quantized) { free(st->quantized); st->quantized = NULL; }
            if (st->quant_tex) { SDL_DestroyTexture(st->quant_tex); st->quant_tex = NULL; }
        } else {
            free(scr_px);
        }
        return;
    }

    /* Imagen normal */
    st->scr_mode = 0;
    int w, h, ch;
    uint8_t *px = stbi_load(path, &w, &h, &ch, 3);
    if (!px) return;

    if (st->original) free(st->original);
    if (st->orig_tex) SDL_DestroyTexture(st->orig_tex);

    st->original = px;
    st->orig_w = w;
    st->orig_h = h;
    st->orig_tex = pixels_to_texture(ren, px, w, h);
    st->zoom = 1.0f;

    update_preview(st, ren);
}

static void do_export(AppState *st, int fmt) {
    /* fmt: 0=html, 1=scr, 2=bmp */
    if (!st->quantized) return;
    char path[1024];
    char base[256];
    const char *fname = strrchr(st->image_path, '/');
    fname = fname ? fname + 1 : st->image_path;
    strncpy(base, fname, sizeof(base)-1);
    char *dot = strrchr(base, '.');
    if (dot) *dot = 0;

    const char *suffix = MODE_SUFFIX[st->mode];

    if (fmt == 0) { /* HTML */
        char def[512];
        snprintf(def, sizeof(def), "%s%s.html", base, suffix);
        if (!save_file_dialog(path, sizeof(path), def, ".html")) return;
        export_html(st->quantized, st->quant_w, st->quant_h,
                     st->cell_size, path);
    } else if (fmt == 1) { /* SCR */
        char def[512];
        snprintf(def, sizeof(def), "%s%s.scr", base, suffix);
        if (!save_file_dialog(path, sizeof(path), def, ".scr")) return;
        /* SCR necesita 256x192 */
        int sw = 256, sh = 192;
        uint8_t *scr_px = resize_image(st->original, st->orig_w, st->orig_h, sw, sh);
        quantize_image(scr_px, sw, sh, st->mode);
        export_scr(scr_px, sw, sh, path);
        free(scr_px);
    } else { /* GIF */
        char def[512];
        snprintf(def, sizeof(def), "%s%s.gif", base, suffix);
        if (!save_file_dialog(path, sizeof(path), def, ".gif")) return;
        export_gif(st->quantized, st->quant_w, st->quant_h, path);
    }
}

/* ------------------------------------------------------------------ */
/* Draw status bar                                                     */
/* ------------------------------------------------------------------ */

static const char *format_bytes(long n, char *buf, int bufsize) {
    if (n < 1024) snprintf(buf, bufsize, "%ld B", n);
    else if (n < 1024*1024) snprintf(buf, bufsize, "%.1f KB", n/1024.0);
    else snprintf(buf, bufsize, "%.2f MB", n/(1024.0*1024.0));
    return buf;
}

static void draw_status(SDL_Renderer *ren, AppState *st) {
    int y = PREVIEW_Y + PREVIEW_H + SEP_H + 4;
    char buf[512], fb1[32], fb2[32], fb3[32];

    snprintf(buf, sizeof(buf), "MODO: %s    SIZE: %s (%d)    ZOOM: %.1fx    CELDA: %d",
             MODE_NAMES[st->mode], SIZE_NAMES[st->size_index],
             st->target_width, st->zoom, st->cell_size);
    draw_text(ren, MARGIN, y, buf, C_YELLOW, 1);

    /* Linea 2: compresion + tamanos */
    if (st->file_size > 0 && st->html_raw_size > 0) {
        long saved = st->html_raw_size - st->html_comp_size;
        int pct = st->html_raw_size > 0 ? (int)(100 * saved / st->html_raw_size) : 0;
        snprintf(buf, sizeof(buf), "COMPRESION: %s    PNG: %s    HTML: %s > %s (-%d%%)",
                 COMP_NAMES[st->compression],
                 format_bytes(st->file_size, fb1, sizeof(fb1)),
                 format_bytes(st->html_raw_size, fb2, sizeof(fb2)),
                 format_bytes(st->html_comp_size, fb3, sizeof(fb3)),
                 pct);
    } else {
        snprintf(buf, sizeof(buf), "COMPRESION: %s", COMP_NAMES[st->compression]);
    }
    draw_text(ren, MARGIN, y + 16, buf, C_YELLOW, 1);
}

/* ------------------------------------------------------------------ */
/* SCR Viewer (modo secreto)                                           */
/* ------------------------------------------------------------------ */

static void draw_scr_viewer(SDL_Renderer *ren, AppState *st) {
    /* Header con colores secretos */
    SDL_Color scr_red   = {255,85,85,255};
    SDL_Color scr_mag_d = {170,0,170,255};
    SDL_Color scr_grn_b = {85,255,85,255};
    SDL_Color scr_grn_d = {0,170,0,255};
    SDL_Color scr_mag_b = {255,85,255,255};

    draw_text(ren, MARGIN, 12, "SCR VIEWER", scr_red, 2);
    draw_text(ren, WIN_W - 15*8 - MARGIN, 18, "ZX Spectrum 48K", scr_mag_d, 1);

    /* Separadores magenta */
    SDL_SetRenderDrawColor(ren, 170, 0, 170, 255);
    SDL_Rect s1 = {0, HEADER_H, WIN_W, SEP_H};
    SDL_RenderFillRect(ren, &s1);
    SDL_Rect s2 = {0, WIN_H - CONTROLS_H - SEP_H, WIN_W, SEP_H};
    SDL_RenderFillRect(ren, &s2);

    /* Imagen SCR centrada */
    if (st->scr_tex) {
        int avail_w = WIN_W - MARGIN*2, avail_h = PREVIEW_H - MARGIN*2;
        float sc = avail_w/256.0f;
        if (avail_h/192.0f < sc) sc = avail_h/192.0f;
        int nw = (int)(256*sc), nh = (int)(192*sc);
        int cx = (WIN_W-nw)/2, cy = PREVIEW_Y + (PREVIEW_H-nh)/2;
        /* Borde magenta */
        SDL_SetRenderDrawColor(ren, 170, 0, 170, 255);
        SDL_Rect border = {cx-2, cy-2, nw+4, nh+4};
        SDL_RenderDrawRect(ren, &border);
        SDL_Rect dst = {cx, cy, nw, nh};
        SDL_RenderCopy(ren, st->scr_tex, NULL, &dst);
    }

    /* Info */
    char buf[128], fb[32];
    snprintf(buf, sizeof(buf), "256x192  6,912 bytes  %s",
             format_bytes(st->file_size, fb, sizeof(fb)));
    draw_text(ren, MARGIN, WIN_H - CONTROLS_H - SEP_H - 20, buf, scr_mag_b, 1);

    /* Controles */
    int y = WIN_H - CONTROLS_H + 10;
    draw_text(ren, MARGIN, y, "[L]", scr_grn_b, 1);
    draw_text(ren, MARGIN+24, y, "OAD  ", scr_grn_d, 1);
    draw_text(ren, MARGIN+64, y, "[E]", scr_grn_b, 1);
    draw_text(ren, MARGIN+88, y, "XPORT  ", scr_grn_d, 1);
    draw_text(ren, MARGIN+176, y, "[Q]", scr_grn_b, 1);
    draw_text(ren, MARGIN+200, y, "UIT", scr_grn_d, 1);
}

/* ------------------------------------------------------------------ */
/* Draw export menu                                                    */
/* ------------------------------------------------------------------ */

static void draw_export_menu(SDL_Renderer *ren) {
    int box_w = 380, box_h = 160;
    int box_x = (WIN_W - box_w)/2, box_y = PREVIEW_Y + (PREVIEW_H - box_h)/2;

    SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
    SDL_Rect bg = {box_x, box_y, box_w, box_h};
    SDL_RenderFillRect(ren, &bg);
    SDL_SetRenderDrawColor(ren, C_BORDER.r, C_BORDER.g, C_BORDER.b, 255);
    SDL_RenderDrawRect(ren, &bg);

    draw_text(ren, box_x+20, box_y+12, "EXPORTAR COMO:", C_CYAN, 1);
    draw_text(ren, box_x+20, box_y+40, "[H]", C_GREEN, 1);
    draw_text(ren, box_x+44, box_y+40, "  HTML  -  Tabla pixel-art", C_WHITE, 1);
    draw_text(ren, box_x+20, box_y+60, "[S]", C_GREEN, 1);
    draw_text(ren, box_x+44, box_y+60, "  SCR   -  Nativo ZX Spectrum", C_WHITE, 1);
    draw_text(ren, box_x+20, box_y+80, "[G]", C_GREEN, 1);
    draw_text(ren, box_x+44, box_y+80, "  GIF   -  Imagen retro (1987)", C_WHITE, 1);
    draw_text(ren, box_x+20, box_y+115, "[ESC]", C_GREEN, 1);
    draw_text(ren, box_x+60, box_y+115, " Cancelar", C_GRAY, 1);
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window *win = SDL_CreateWindow("Spectrumify v0.1 [C]",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIN_W, WIN_H, 0);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    AppState st = {0};
    st.mode = MODE_16;
    st.size_index = 1;
    st.target_width = SIZES[1];
    st.cell_size = 3;
    st.zoom = 1.0f;
    st.running = 1;

    while (st.running) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT) { st.running = 0; break; }
            if (ev.type != SDL_KEYDOWN) continue;

            if (st.export_menu) {
                switch (ev.key.keysym.sym) {
                    case SDLK_h: st.export_menu=0; do_export(&st,0); break;
                    case SDLK_s: st.export_menu=0; do_export(&st,1); break;
                    case SDLK_g: st.export_menu=0; do_export(&st,2); break;
                    case SDLK_ESCAPE: st.export_menu=0; break;
                }
                continue;
            }

            /* Modo SCR: solo L, E (exporta BMP directo), Q */
            if (st.scr_mode) {
                switch (ev.key.keysym.sym) {
                    case SDLK_q: st.running = 0; break;
                    case SDLK_l: load_image(&st, ren); break;
                    case SDLK_e:
                        if (st.scr_pixels) {
                            char path[1024], base[256];
                            const char *fn = strrchr(st.image_path, '/');
                            fn = fn ? fn+1 : st.image_path;
                            strncpy(base, fn, sizeof(base)-1);
                            char *dot = strrchr(base, '.'); if (dot) *dot = 0;
                            char def[512];
                            snprintf(def, sizeof(def), "%s.gif", base);
                            if (save_file_dialog(path, sizeof(path), def, ".gif"))
                                export_gif(st.scr_pixels, 256, 192, path);
                        }
                        break;
                }
                continue;
            }

            switch (ev.key.keysym.sym) {
                case SDLK_q: st.running = 0; break;
                case SDLK_l: load_image(&st, ren); break;
                case SDLK_e:
                    if (st.original) st.export_menu = 1;
                    break;
                case SDLK_m:
                    st.mode = (st.mode + 1) % 3;
                    update_preview(&st, ren);
                    break;
                case SDLK_s:
                    st.size_index = (st.size_index + 1) % 3;
                    st.target_width = SIZES[st.size_index];
                    st.zoom = 1.0f;
                    update_preview(&st, ren);
                    break;
                case SDLK_c:
                    st.compression = (st.compression + 1) % 3;
                    estimate_html_sizes(&st);
                    break;
                case SDLK_EQUALS: case SDLK_PLUS: case SDLK_KP_PLUS:
                    if (st.zoom < 8.0f) st.zoom += 0.5f;
                    break;
                case SDLK_MINUS: case SDLK_KP_MINUS:
                    if (st.zoom > 0.5f) st.zoom -= 0.5f;
                    break;
            }
        }

        /* Draw */
        SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
        SDL_RenderClear(ren);

        if (st.scr_mode) {
            draw_scr_viewer(ren, &st);
        } else {
            draw_header(ren);
            draw_separator(ren, HEADER_H);
            draw_preview(ren, st.orig_tex, st.orig_w, st.orig_h,
                         st.quant_tex, st.quant_w, st.quant_h, st.zoom);
            draw_separator(ren, PREVIEW_Y + PREVIEW_H);
            draw_status(ren, &st);
            draw_separator(ren, WIN_H - CONTROLS_H - SEP_H);
            draw_controls(ren);
            if (st.export_menu) draw_export_menu(ren);
        }

        SDL_RenderPresent(ren);
    }

    if (st.original) free(st.original);
    if (st.quantized) free(st.quantized);
    if (st.scr_pixels) free(st.scr_pixels);
    if (st.orig_tex) SDL_DestroyTexture(st.orig_tex);
    if (st.quant_tex) SDL_DestroyTexture(st.quant_tex);
    if (st.scr_tex) SDL_DestroyTexture(st.scr_tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
