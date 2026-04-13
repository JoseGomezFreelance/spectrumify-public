// ================================================================
// Spectrumify — Main loop (SDL2)
// ARM64 AArch64 — macOS
// (c) 2026 JGF
//
// La app completa en ensamblador ARM64.
// ================================================================

.equ WIN_W, 1024
.equ WIN_H, 700
.equ HEADER_H, 40
.equ CONTROLS_H, 36
.equ SEP_H, 2
.equ MARGIN, 16
.equ PREVIEW_Y, 42
.equ PREVIEW_H, 558

// SDL constants
.equ SDL_INIT_VIDEO, 0x20
.equ SDL_WINDOWPOS_CENTERED, 0x2FFF0000
.equ SDL_WINDOW_SHOWN, 0x4
.equ SDL_RENDERER_ACCELERATED, 0x2
.equ SDL_RENDERER_PRESENTVSYNC, 0x4
.equ SDL_QUIT_EVENT, 0x100
.equ SDL_KEYDOWN, 0x300
.equ SDL_PIXELFORMAT_RGB24, 0x17101803
.equ SDL_TEXTUREACCESS_STATIC, 0

// Key codes
.equ SDLK_q, 113
.equ SDLK_l, 108
.equ SDLK_e, 101
.equ SDLK_m, 109
.equ SDLK_s, 115
.equ SDLK_c, 99
.equ SDLK_h, 104
.equ SDLK_g, 103
.equ SDLK_EQUALS, 61
.equ SDLK_MINUS, 45
.equ SDLK_ESCAPE, 27

// ----------------------------------------------------------------
// Estado de la app (struct en .data)
// ----------------------------------------------------------------
.section __DATA,__data
.p2align 3
.globl _app_state

_app_state:
_st_orig_pixels:    .quad 0         // 0: puntero a pixels originales
_st_orig_w:         .word 0         // 8: ancho original
_st_orig_h:         .word 0         // 12: alto original
_st_quant_pixels:   .quad 0         // 16: puntero a pixels cuantizados
_st_quant_w:        .word 0         // 24: ancho cuantizado
_st_quant_h:        .word 0         // 28: alto cuantizado
_st_orig_tex:       .quad 0         // 32: SDL_Texture original
_st_quant_tex:      .quad 0         // 40: SDL_Texture cuantizada
_st_mode:           .word 0         // 48: 0=16, 1=gray, 2=bw
_st_size_index:     .word 1         // 52: 0=S, 1=M, 2=L
_st_target_width:   .word 153       // 56: ancho objetivo
_st_cell_size:      .word 3         // 60: tamano celda HTML
_st_compression:    .word 0         // 64: 0=safari, 1=aggr, 2=none
_st_zoom:           .word 0x3F800000 // 68: 1.0f (IEEE754)
_st_export_menu:    .word 0         // 72: submenu activo
_st_running:        .word 1         // 76: app corriendo
_st_file_size:      .quad 0         // 80: tamano del archivo
_st_image_path:     .space 1024     // 88: path de la imagen

// Renderer y window (guardados globalmente)
_g_window:          .quad 0
_g_renderer:        .quad 0

// Sizes lookup
.p2align 2
_sizes_table:       .word 80, 153, 256

// SDL_Event buffer (64 bytes)
.p2align 3
_event_buf:         .space 64

// String buffers
_hex_buf:           .space 16
_status_buf:        .space 256
_path_buf:          .space 1024
_cmd_buf:           .space 2048

// ----------------------------------------------------------------
// Strings
// ----------------------------------------------------------------
.section __TEXT,__cstring
_str_wintitle:  .asciz "Spectrumify v0.1 [ARM64 ASM]"
_str_osascript_open:
    .asciz "osascript -e 'set f to choose file with prompt \"Cargar imagen\" of type {\"public.image\",\"public.data\"}' -e 'return POSIX path of f' 2>/dev/null"
_str_osascript_save:
    .asciz "osascript -e 'set f to choose file name with prompt \"Exportar\" default name \"%s\"' -e 'return POSIX path of f' 2>/dev/null"
_str_r:         .asciz "r"
_str_html_ext:  .asciz ".html"
_str_scr_ext:   .asciz ".scr"
_str_suffix_zx: .asciz "_zx"
_str_suffix_gray: .asciz "_gray"
_str_suffix_byn: .asciz "_ByN"
_str_fmt_defname: .asciz "%s%s%s"
_str_loaded:    .asciz "SDL init OK\n"
_str_sdl_err:   .asciz "SDL_Init error: %s\n"
_str_channels:  .asciz "stbi_load: %dx%d (%d channels)\n"

// ----------------------------------------------------------------
// _main
// ----------------------------------------------------------------
.text
.globl _main
.p2align 2

_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // SDL_Init(SDL_INIT_VIDEO)
    mov     w0, #SDL_INIT_VIDEO
    bl      _SDL_Init
    cbnz    w0, .Lmain_sdl_err

    // SDL_CreateWindow(title, centered, centered, W, H, SHOWN)
    adrp    x0, _str_wintitle@PAGE
    add     x0, x0, _str_wintitle@PAGEOFF
    mov     w1, #SDL_WINDOWPOS_CENTERED
    mov     w2, #SDL_WINDOWPOS_CENTERED
    mov     w3, #WIN_W
    mov     w4, #WIN_H
    mov     w5, #SDL_WINDOW_SHOWN
    bl      _SDL_CreateWindow
    adrp    x1, _g_window@PAGE
    add     x1, x1, _g_window@PAGEOFF
    str     x0, [x1]

    // SDL_CreateRenderer(win, -1, ACCELERATED | PRESENTVSYNC)
    mov     w1, #-1
    mov     w2, #(SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
    bl      _SDL_CreateRenderer
    adrp    x1, _g_renderer@PAGE
    add     x1, x1, _g_renderer@PAGEOFF
    str     x0, [x1]

    // ============================================================
    // Main loop
    // ============================================================
.Lmain_loop:
    // Check running flag
    adrp    x8, _st_running@PAGE
    add     x8, x8, _st_running@PAGEOFF
    ldr     w9, [x8]
    cbz     w9, .Lmain_quit

    // ---- Event polling ----
.Lmain_event:
    adrp    x0, _event_buf@PAGE
    add     x0, x0, _event_buf@PAGEOFF
    bl      _SDL_PollEvent
    cbz     w0, .Lmain_draw     // no more events

    // Read event type (offset 0, uint32)
    adrp    x8, _event_buf@PAGE
    add     x8, x8, _event_buf@PAGEOFF
    ldr     w9, [x8]            // event.type

    // SDL_QUIT
    cmp     w9, #SDL_QUIT_EVENT
    b.ne    .Lev_not_quit
    adrp    x10, _st_running@PAGE
    add     x10, x10, _st_running@PAGEOFF
    str     wzr, [x10]
    b       .Lmain_event

.Lev_not_quit:
    // SDL_KEYDOWN
    cmp     w9, #SDL_KEYDOWN
    b.ne    .Lmain_event

    // key.keysym.sym is at offset 20 (keysym at +16, sym at +4 within)
    ldr     w9, [x8, #20]      // keysym.sym

    // Check export menu first
    adrp    x10, _st_export_menu@PAGE
    add     x10, x10, _st_export_menu@PAGEOFF
    ldr     w11, [x10]
    cbz     w11, .Lev_normal

    // Export menu active
    cmp     w9, #SDLK_h
    b.ne    1f
    str     wzr, [x10]          // close menu
    mov     w0, #0              // format = HTML
    bl      _do_export
    b       .Lmain_event
1:
    cmp     w9, #SDLK_s
    b.ne    2f
    str     wzr, [x10]
    mov     w0, #1              // format = SCR
    bl      _do_export
    b       .Lmain_event
2:
    cmp     w9, #SDLK_ESCAPE
    b.ne    .Lmain_event
    str     wzr, [x10]
    b       .Lmain_event

.Lev_normal:
    // Normal key handling
    cmp     w9, #SDLK_q
    b.ne    1f
    adrp    x10, _st_running@PAGE
    add     x10, x10, _st_running@PAGEOFF
    str     wzr, [x10]
    b       .Lmain_event
1:
    cmp     w9, #SDLK_l
    b.ne    2f
    bl      _load_image
    b       .Lmain_event
2:
    cmp     w9, #SDLK_e
    b.ne    3f
    // Check if image loaded
    adrp    x10, _st_orig_pixels@PAGE
    add     x10, x10, _st_orig_pixels@PAGEOFF
    ldr     x11, [x10]
    cbz     x11, .Lmain_event
    adrp    x10, _st_export_menu@PAGE
    add     x10, x10, _st_export_menu@PAGEOFF
    mov     w11, #1
    str     w11, [x10]
    b       .Lmain_event
3:
    cmp     w9, #SDLK_m
    b.ne    4f
    // mode = (mode + 1) % 3
    adrp    x10, _st_mode@PAGE
    add     x10, x10, _st_mode@PAGEOFF
    ldr     w11, [x10]
    add     w11, w11, #1
    mov     w12, #3
    udiv    w13, w11, w12
    msub    w11, w13, w12, w11  // w11 = w11 % 3
    str     w11, [x10]
    bl      _update_preview
    b       .Lmain_event
4:
    cmp     w9, #SDLK_s
    b.ne    5f
    // size_index = (size_index + 1) % 3, update target_width
    adrp    x10, _st_size_index@PAGE
    add     x10, x10, _st_size_index@PAGEOFF
    ldr     w11, [x10]
    add     w11, w11, #1
    mov     w12, #3
    udiv    w13, w11, w12
    msub    w11, w13, w12, w11
    str     w11, [x10]
    // target_width = sizes[size_index]
    adrp    x12, _sizes_table@PAGE
    add     x12, x12, _sizes_table@PAGEOFF
    ldr     w13, [x12, x11, lsl #2]
    adrp    x14, _st_target_width@PAGE
    add     x14, x14, _st_target_width@PAGEOFF
    str     w13, [x14]
    bl      _update_preview
    b       .Lmain_event
5:
    cmp     w9, #SDLK_c
    b.ne    6f
    // compression = (compression + 1) % 3
    adrp    x10, _st_compression@PAGE
    add     x10, x10, _st_compression@PAGEOFF
    ldr     w11, [x10]
    add     w11, w11, #1
    mov     w12, #3
    udiv    w13, w11, w12
    msub    w11, w13, w12, w11
    str     w11, [x10]
    b       .Lmain_event
6:
    cmp     w9, #SDLK_EQUALS
    b.ne    7f
    // zoom += 0.5 (if < 8.0)
    // Simplified: skip zoom for ASM version
    b       .Lmain_event
7:
    cmp     w9, #SDLK_MINUS
    b.ne    .Lmain_event
    // zoom -= 0.5 (if > 0.5)
    b       .Lmain_event

    // ---- Draw ----
.Lmain_draw:
    adrp    x19, _g_renderer@PAGE
    add     x19, x19, _g_renderer@PAGEOFF
    ldr     x19, [x19]

    // Clear screen (black)
    mov     x0, x19
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    mov     x0, x19
    bl      _SDL_RenderClear

    // Draw header
    mov     x0, x19
    bl      _draw_header

    // Draw separator at HEADER_H
    mov     x0, x19
    mov     w1, #0
    mov     w2, #170
    mov     w3, #170
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    sub     sp, sp, #16
    str     wzr, [sp]           // x=0
    mov     w8, #HEADER_H
    str     w8, [sp, #4]        // y=HEADER_H
    mov     w8, #WIN_W
    str     w8, [sp, #8]        // w=WIN_W
    mov     w8, #SEP_H
    str     w8, [sp, #12]       // h=SEP_H
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderFillRect
    add     sp, sp, #16

    // Draw "Pulsa [L]" if no image, or preview
    adrp    x8, _st_orig_pixels@PAGE
    add     x8, x8, _st_orig_pixels@PAGEOFF
    ldr     x8, [x8]
    cbz     x8, .Ldraw_noimage

    // Draw preview: original texture
    adrp    x8, _st_orig_tex@PAGE
    add     x8, x8, _st_orig_tex@PAGEOFF
    ldr     x8, [x8]
    cbz     x8, .Ldraw_labels

    // Labels
.Ldraw_labels:
    mov     x0, x19
    mov     w1, #MARGIN
    mov     w2, #(PREVIEW_Y + 2)
    adrp    x3, _str_original@PAGE
    add     x3, x3, _str_original@PAGEOFF
    mov     w4, #85
    mov     w5, #85
    mov     w6, #85
    bl      _draw_text

    mov     x0, x19
    mov     w1, #(MARGIN * 2 + (WIN_W - MARGIN*3)/2)
    mov     w2, #(PREVIEW_Y + 2)
    adrp    x3, _str_pixelart@PAGE
    add     x3, x3, _str_pixelart@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text

    // Render original texture (left half) con aspect ratio
    adrp    x8, _st_orig_tex@PAGE
    add     x8, x8, _st_orig_tex@PAGEOFF
    ldr     x8, [x8]
    cbz     x8, .Ldraw_quant

    mov     w10, #((WIN_W - MARGIN*3) / 2)  // half_w
    mov     w11, #(PREVIEW_H - MARGIN*2 - 16)  // avail_h

    // Scale = min(half_w/orig_w, avail_h/orig_h) usando division entera
    adrp    x12, _st_orig_w@PAGE
    add     x12, x12, _st_orig_w@PAGEOFF
    ldr     w12, [x12]          // orig_w
    adrp    x13, _st_orig_h@PAGE
    add     x13, x13, _st_orig_h@PAGEOFF
    ldr     w13, [x13]          // orig_h

    // nw = half_w, nh = half_w * orig_h / orig_w
    mul     w14, w10, w13       // half_w * orig_h
    udiv    w14, w14, w12       // / orig_w = nh
    // Si nh > avail_h, recalcular: nw = avail_h * orig_w / orig_h, nh = avail_h
    cmp     w14, w11
    b.le    .Lorig_fit
    mov     w14, w11            // nh = avail_h
    mul     w10, w11, w12       // avail_h * orig_w
    udiv    w10, w10, w13       // / orig_h = nw
.Lorig_fit:
    // Centrar: x = MARGIN + (half_w - nw)/2
    mov     w15, #((WIN_W - MARGIN*3) / 2)
    sub     w15, w15, w10
    lsr     w15, w15, #1
    add     w15, w15, #MARGIN   // cx

    mov     w16, #(PREVIEW_H - MARGIN*2 - 16)
    sub     w16, w16, w14
    lsr     w16, w16, #1
    add     w16, w16, #(PREVIEW_Y + 20) // cy

    sub     sp, sp, #16
    str     w15, [sp]           // dst.x = cx
    str     w16, [sp, #4]       // dst.y = cy
    str     w10, [sp, #8]       // dst.w = nw
    str     w14, [sp, #12]      // dst.h = nh
    mov     x0, x19
    mov     x1, x8
    mov     x2, #0
    mov     x3, sp
    bl      _SDL_RenderCopy
    add     sp, sp, #16

.Ldraw_quant:
    // Render quantized texture (right half) con aspect ratio
    adrp    x8, _st_quant_tex@PAGE
    add     x8, x8, _st_quant_tex@PAGEOFF
    ldr     x8, [x8]
    cbz     x8, .Ldraw_status

    mov     w10, #((WIN_W - MARGIN*3) / 2)  // half_w
    mov     w11, #(PREVIEW_H - MARGIN*2 - 16)  // avail_h

    adrp    x12, _st_quant_w@PAGE
    add     x12, x12, _st_quant_w@PAGEOFF
    ldr     w12, [x12]          // quant_w
    adrp    x13, _st_quant_h@PAGE
    add     x13, x13, _st_quant_h@PAGEOFF
    ldr     w13, [x13]          // quant_h

    mul     w14, w10, w13
    udiv    w14, w14, w12       // nh
    cmp     w14, w11
    b.le    .Lquant_fit
    mov     w14, w11
    mul     w10, w11, w12
    udiv    w10, w10, w13       // nw
.Lquant_fit:
    mov     w15, #((WIN_W - MARGIN*3) / 2)
    sub     w15, w15, w10
    lsr     w15, w15, #1
    mov     w16, #(MARGIN*2 + (WIN_W - MARGIN*3)/2)
    add     w15, w15, w16       // cx = right_x + (half_w-nw)/2

    mov     w16, #(PREVIEW_H - MARGIN*2 - 16)
    sub     w16, w16, w14
    lsr     w16, w16, #1
    add     w16, w16, #(PREVIEW_Y + 20) // cy

    sub     sp, sp, #16
    str     w15, [sp]
    str     w16, [sp, #4]
    str     w10, [sp, #8]
    str     w14, [sp, #12]
    mov     x0, x19
    mov     x1, x8
    mov     x2, #0
    mov     x3, sp
    bl      _SDL_RenderCopy
    add     sp, sp, #16
    b       .Ldraw_status

.Ldraw_noimage:
    mov     x0, x19
    mov     w1, #(WIN_W/2 - 15*4)
    mov     w2, #(PREVIEW_Y + PREVIEW_H/2)
    adrp    x3, _str_noimage@PAGE
    add     x3, x3, _str_noimage@PAGEOFF
    mov     w4, #85
    mov     w5, #85
    mov     w6, #85
    bl      _draw_text

.Ldraw_status:
    // Separator at PREVIEW_Y + PREVIEW_H
    mov     x0, x19
    mov     w1, #0
    mov     w2, #170
    mov     w3, #170
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    sub     sp, sp, #16
    str     wzr, [sp]
    mov     w8, #(PREVIEW_Y + PREVIEW_H)
    str     w8, [sp, #4]
    mov     w8, #WIN_W
    str     w8, [sp, #8]
    mov     w8, #SEP_H
    str     w8, [sp, #12]
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderFillRect
    add     sp, sp, #16

    // Status line 1: "MODO: xxx    SIZE: xxx (nnn)"
    // Seleccionar mode name por branching (evita tablas de punteros)
    adrp    x8, _st_mode@PAGE
    add     x8, x8, _st_mode@PAGEOFF
    ldr     w9, [x8]
    cmp     w9, #1
    b.eq    .Lst_mode_gray
    cmp     w9, #2
    b.eq    .Lst_mode_bw
    adrp    x10, _local_mn_16@PAGE
    add     x10, x10, _local_mn_16@PAGEOFF
    b       .Lst_mode_done
.Lst_mode_gray:
    adrp    x10, _local_mn_gray@PAGE
    add     x10, x10, _local_mn_gray@PAGEOFF
    b       .Lst_mode_done
.Lst_mode_bw:
    adrp    x10, _local_mn_bw@PAGE
    add     x10, x10, _local_mn_bw@PAGEOFF
.Lst_mode_done:

    // Seleccionar size name
    adrp    x8, _st_size_index@PAGE
    add     x8, x8, _st_size_index@PAGEOFF
    ldr     w11, [x8]
    cmp     w11, #1
    b.eq    .Lst_sz_med
    cmp     w11, #2
    b.eq    .Lst_sz_big
    adrp    x12, _local_sn_small@PAGE
    add     x12, x12, _local_sn_small@PAGEOFF
    b       .Lst_sz_done
.Lst_sz_med:
    adrp    x12, _local_sn_medium@PAGE
    add     x12, x12, _local_sn_medium@PAGEOFF
    b       .Lst_sz_done
.Lst_sz_big:
    adrp    x12, _local_sn_big@PAGE
    add     x12, x12, _local_sn_big@PAGEOFF
.Lst_sz_done:

    adrp    x8, _st_target_width@PAGE
    add     x8, x8, _st_target_width@PAGEOFF
    ldr     w13, [x8]

    // sprintf(status_buf, fmt, mode, size, width)
    adrp    x0, _status_buf@PAGE
    add     x0, x0, _status_buf@PAGEOFF
    adrp    x1, _local_status_fmt@PAGE
    add     x1, x1, _local_status_fmt@PAGEOFF
    mov     x2, x10
    mov     x3, x12
    mov     w4, w13
    bl      _sprintf

    mov     x0, x19
    mov     w1, #MARGIN
    mov     w2, #(PREVIEW_Y + PREVIEW_H + SEP_H + 4)
    adrp    x3, _status_buf@PAGE
    add     x3, x3, _status_buf@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text

    // Status line 2: "COMPRESION: xxx"
    adrp    x8, _st_compression@PAGE
    add     x8, x8, _st_compression@PAGEOFF
    ldr     w9, [x8]
    cmp     w9, #1
    b.eq    .Lst_cmp_aggr
    cmp     w9, #2
    b.eq    .Lst_cmp_none
    adrp    x10, _local_cn_safari@PAGE
    add     x10, x10, _local_cn_safari@PAGEOFF
    b       .Lst_cmp_done
.Lst_cmp_aggr:
    adrp    x10, _local_cn_aggr@PAGE
    add     x10, x10, _local_cn_aggr@PAGEOFF
    b       .Lst_cmp_done
.Lst_cmp_none:
    adrp    x10, _local_cn_none@PAGE
    add     x10, x10, _local_cn_none@PAGEOFF
.Lst_cmp_done:

    adrp    x0, _status_buf@PAGE
    add     x0, x0, _status_buf@PAGEOFF
    adrp    x1, _local_comp_fmt@PAGE
    add     x1, x1, _local_comp_fmt@PAGEOFF
    mov     x2, x10
    bl      _sprintf

    mov     x0, x19
    mov     w1, #MARGIN
    mov     w2, #(PREVIEW_Y + PREVIEW_H + SEP_H + 20)
    adrp    x3, _status_buf@PAGE
    add     x3, x3, _status_buf@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text

    // Separator before controls
    mov     x0, x19
    mov     w1, #0
    mov     w2, #170
    mov     w3, #170
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    sub     sp, sp, #16
    str     wzr, [sp]
    mov     w8, #(WIN_H - CONTROLS_H - SEP_H)
    str     w8, [sp, #4]
    mov     w8, #WIN_W
    str     w8, [sp, #8]
    mov     w8, #SEP_H
    str     w8, [sp, #12]
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderFillRect
    add     sp, sp, #16

    // Draw controls
    mov     x0, x19
    bl      _draw_controls

    // Draw export menu if active
    adrp    x8, _st_export_menu@PAGE
    add     x8, x8, _st_export_menu@PAGEOFF
    ldr     w8, [x8]
    cbz     w8, .Ldraw_present

    // Simple export menu box
    mov     x0, x19
    mov     w1, #0
    mov     w2, #0
    mov     w3, #0
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    sub     sp, sp, #16
    mov     w8, #((WIN_W-380)/2)
    str     w8, [sp]
    mov     w8, #(PREVIEW_Y + (PREVIEW_H-120)/2)
    str     w8, [sp, #4]
    mov     w8, #380
    str     w8, [sp, #8]
    mov     w8, #120
    str     w8, [sp, #12]
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderFillRect

    // Border
    mov     x0, x19
    mov     w1, #0
    mov     w2, #170
    mov     w3, #170
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderDrawRect
    add     sp, sp, #16

    // Menu text
    mov     w8, #((WIN_W-380)/2 + 20)
    mov     w9, #(PREVIEW_Y + (PREVIEW_H-120)/2 + 12)

    mov     x0, x19
    mov     w1, w8
    mov     w2, w9
    adrp    x3, _menu_title@PAGE
    add     x3, x3, _menu_title@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text

    add     w9, w9, #28
    mov     x0, x19
    mov     w1, w8
    mov     w2, w9
    adrp    x3, _menu_h@PAGE
    add     x3, x3, _menu_h@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text

    add     w9, w9, #20
    mov     x0, x19
    mov     w1, w8
    mov     w2, w9
    adrp    x3, _menu_s@PAGE
    add     x3, x3, _menu_s@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text

    add     w9, w9, #24
    mov     x0, x19
    mov     w1, w8
    mov     w2, w9
    adrp    x3, _menu_esc@PAGE
    add     x3, x3, _menu_esc@PAGEOFF
    mov     w4, #85
    mov     w5, #85
    mov     w6, #85
    bl      _draw_text

.Ldraw_present:
    mov     x0, x19
    bl      _SDL_RenderPresent

    b       .Lmain_loop

    // ---- SDL error ----
.Lmain_sdl_err:
    bl      _SDL_GetError
    mov     x1, x0
    adrp    x0, _str_sdl_err@PAGE
    add     x0, x0, _str_sdl_err@PAGEOFF
    bl      _printf
    mov     w0, #1
    ldp     x29, x30, [sp], #16
    ret

    // ---- Quit ----
.Lmain_quit:
    // Cleanup
    adrp    x0, _g_renderer@PAGE
    add     x0, x0, _g_renderer@PAGEOFF
    ldr     x0, [x0]
    bl      _SDL_DestroyRenderer
    adrp    x0, _g_window@PAGE
    add     x0, x0, _g_window@PAGEOFF
    ldr     x0, [x0]
    bl      _SDL_DestroyWindow
    bl      _SDL_Quit

    mov     w0, #0
    ldp     x29, x30, [sp], #16
    ret

// ================================================================
// load_image — abre dialogo, carga con stbi_load, crea texturas
// ================================================================
.globl _load_image
.p2align 2

_load_image:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    // popen(osascript command, "r")
    adrp    x0, _str_osascript_open@PAGE
    add     x0, x0, _str_osascript_open@PAGEOFF
    adrp    x1, _str_r@PAGE
    add     x1, x1, _str_r@PAGEOFF
    bl      _popen
    mov     x19, x0             // FILE *pipe
    cbz     x19, .Lli_done

    // fgets(path_buf, 1024, pipe)
    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    mov     w1, #1024
    mov     x2, x19
    bl      _fgets
    cbz     x0, .Lli_close

    // pclose
    mov     x0, x19
    bl      _pclose

    // Trim newline
    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    bl      _trim_newline

    // Check empty
    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    ldrb    w1, [x0]
    cbz     w1, .Lli_done

    // load_bmp(path, &w, &h)
    sub     sp, sp, #16
    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    add     x1, sp, #0          // &w
    add     x2, sp, #4          // &h
    bl      _load_bmp
    mov     x19, x0             // pixels ptr
    ldr     w21, [sp]           // w
    ldr     w22, [sp, #4]       // h
    add     sp, sp, #16

    cbz     x19, .Lli_done

    // Store in state
    adrp    x8, _st_orig_pixels@PAGE
    add     x8, x8, _st_orig_pixels@PAGEOFF
    str     x19, [x8]
    adrp    x8, _st_orig_w@PAGE
    add     x8, x8, _st_orig_w@PAGEOFF
    str     w21, [x8]
    adrp    x8, _st_orig_h@PAGE
    add     x8, x8, _st_orig_h@PAGEOFF
    str     w22, [x8]

    // Create texture
    adrp    x0, _g_renderer@PAGE
    add     x0, x0, _g_renderer@PAGEOFF
    ldr     x0, [x0]
    movz    w1, #0x1803
    movk    w1, #0x1710, lsl #16
    mov     w2, #SDL_TEXTUREACCESS_STATIC
    mov     w3, w21
    mov     w4, w22
    bl      _SDL_CreateTexture
    mov     x20, x0             // texture

    // SDL_UpdateTexture(tex, NULL, pixels, w*3)
    mov     x0, x20
    mov     x1, #0
    mov     x2, x19
    mov     w3, w21
    mov     w4, #3
    mul     w3, w3, w4
    bl      _SDL_UpdateTexture

    // Store texture
    adrp    x8, _st_orig_tex@PAGE
    add     x8, x8, _st_orig_tex@PAGEOFF
    str     x20, [x8]

    // Update preview
    bl      _update_preview

    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.Lli_close:
    mov     x0, x19
    bl      _pclose
.Lli_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ================================================================
// update_preview — resize + quantize + create texture
// ================================================================
.globl _update_preview
.p2align 2

_update_preview:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    // Load state
    adrp    x8, _st_orig_pixels@PAGE
    add     x8, x8, _st_orig_pixels@PAGEOFF
    ldr     x19, [x8]          // orig pixels
    cbz     x19, .Lup_done

    adrp    x8, _st_orig_w@PAGE
    add     x8, x8, _st_orig_w@PAGEOFF
    ldr     w20, [x8]
    adrp    x8, _st_orig_h@PAGE
    add     x8, x8, _st_orig_h@PAGEOFF
    ldr     w21, [x8]
    adrp    x8, _st_target_width@PAGE
    add     x8, x8, _st_target_width@PAGEOFF
    ldr     w22, [x8]

    // calculate_dimensions
    sub     sp, sp, #16
    mov     x0, x20             // orig_w
    mov     x1, x21             // orig_h
    mov     x2, x22             // target_w
    mov     x3, sp              // out_w
    add     x4, sp, #4          // out_h
    bl      _calculate_dimensions
    ldr     w20, [sp]           // new_w
    ldr     w21, [sp, #4]       // new_h
    add     sp, sp, #16

    // Store quant dimensions
    adrp    x8, _st_quant_w@PAGE
    add     x8, x8, _st_quant_w@PAGEOFF
    str     w20, [x8]
    adrp    x8, _st_quant_h@PAGE
    add     x8, x8, _st_quant_h@PAGEOFF
    str     w21, [x8]

    // Free old quant pixels
    adrp    x8, _st_quant_pixels@PAGE
    add     x8, x8, _st_quant_pixels@PAGEOFF
    ldr     x0, [x8]
    cbz     x0, .Lup_resize
    bl      _free

.Lup_resize:
    // resize_image(orig, orig_w, orig_h, new_w, new_h)
    mov     x0, x19
    adrp    x8, _st_orig_w@PAGE
    add     x8, x8, _st_orig_w@PAGEOFF
    ldr     w1, [x8]
    adrp    x8, _st_orig_h@PAGE
    add     x8, x8, _st_orig_h@PAGEOFF
    ldr     w2, [x8]
    mov     w3, w20
    mov     w4, w21
    bl      _resize_image
    mov     x19, x0             // resized pixels

    // Store quant pixels
    adrp    x8, _st_quant_pixels@PAGE
    add     x8, x8, _st_quant_pixels@PAGEOFF
    str     x19, [x8]

    // quantize_image(pixels, w, h, mode)
    mov     x0, x19
    mov     w1, w20
    mov     w2, w21
    adrp    x8, _st_mode@PAGE
    add     x8, x8, _st_mode@PAGEOFF
    ldr     w3, [x8]
    bl      _quantize_image

    // Free old texture
    adrp    x8, _st_quant_tex@PAGE
    add     x8, x8, _st_quant_tex@PAGEOFF
    ldr     x0, [x8]
    cbz     x0, .Lup_tex
    bl      _SDL_DestroyTexture

.Lup_tex:
    // Create new texture
    adrp    x0, _g_renderer@PAGE
    add     x0, x0, _g_renderer@PAGEOFF
    ldr     x0, [x0]
    movz    w1, #0x1803
    movk    w1, #0x1710, lsl #16
    mov     w2, #SDL_TEXTUREACCESS_STATIC
    mov     w3, w20
    mov     w4, w21
    bl      _SDL_CreateTexture
    mov     x22, x0

    // Update texture
    mov     x0, x22
    mov     x1, #0
    mov     x2, x19
    mov     w3, w20
    mov     w4, #3
    mul     w3, w3, w4
    bl      _SDL_UpdateTexture

    // Store
    adrp    x8, _st_quant_tex@PAGE
    add     x8, x8, _st_quant_tex@PAGEOFF
    str     x22, [x8]

.Lup_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

// ================================================================
// do_export — exporta segun formato (0=HTML, 1=SCR)
// ================================================================
.globl _do_export
.p2align 2

_do_export:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    mov     w19, w0             // format

    // Construct default filename
    // For simplicity: "output_zx.html" or "output_zx.scr"
    adrp    x0, _cmd_buf@PAGE
    add     x0, x0, _cmd_buf@PAGEOFF

    cmp     w19, #0
    b.ne    .Lde_scr

    // HTML export
    adrp    x1, _str_osascript_save@PAGE
    add     x1, x1, _str_osascript_save@PAGEOFF
    adrp    x2, _def_html@PAGE
    add     x2, x2, _def_html@PAGEOFF
    bl      _sprintf

    // popen
    adrp    x0, _cmd_buf@PAGE
    add     x0, x0, _cmd_buf@PAGEOFF
    adrp    x1, _str_r@PAGE
    add     x1, x1, _str_r@PAGEOFF
    bl      _popen
    mov     x19, x0
    cbz     x19, .Lde_done

    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    mov     w1, #1024
    mov     x2, x19
    bl      _fgets

    mov     x0, x19
    bl      _pclose

    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    bl      _trim_newline

    ldrb    w1, [x0]
    cbz     w1, .Lde_done

    // export_html(pixels, w, h, cell_size, path)
    adrp    x0, _st_quant_pixels@PAGE
    add     x0, x0, _st_quant_pixels@PAGEOFF
    ldr     x0, [x0]
    adrp    x1, _st_quant_w@PAGE
    add     x1, x1, _st_quant_w@PAGEOFF
    ldr     w1, [x1]
    adrp    x2, _st_quant_h@PAGE
    add     x2, x2, _st_quant_h@PAGEOFF
    ldr     w2, [x2]
    adrp    x3, _st_cell_size@PAGE
    add     x3, x3, _st_cell_size@PAGEOFF
    ldr     w3, [x3]
    adrp    x4, _path_buf@PAGE
    add     x4, x4, _path_buf@PAGEOFF
    bl      _export_html_asm
    b       .Lde_done

.Lde_scr:
    // SCR export — similar pero con export_scr
    // Para simplificar: resize a 256x192 y exportar
    adrp    x1, _str_osascript_save@PAGE
    add     x1, x1, _str_osascript_save@PAGEOFF
    adrp    x2, _def_scr@PAGE
    add     x2, x2, _def_scr@PAGEOFF
    bl      _sprintf

    adrp    x0, _cmd_buf@PAGE
    add     x0, x0, _cmd_buf@PAGEOFF
    adrp    x1, _str_r@PAGE
    add     x1, x1, _str_r@PAGEOFF
    bl      _popen
    mov     x19, x0
    cbz     x19, .Lde_done

    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    mov     w1, #1024
    mov     x2, x19
    bl      _fgets

    mov     x0, x19
    bl      _pclose

    adrp    x0, _path_buf@PAGE
    add     x0, x0, _path_buf@PAGEOFF
    bl      _trim_newline

    ldrb    w1, [x0]
    cbz     w1, .Lde_done

    // Resize orig to 256x192
    adrp    x0, _st_orig_pixels@PAGE
    add     x0, x0, _st_orig_pixels@PAGEOFF
    ldr     x0, [x0]
    adrp    x1, _st_orig_w@PAGE
    add     x1, x1, _st_orig_w@PAGEOFF
    ldr     w1, [x1]
    adrp    x2, _st_orig_h@PAGE
    add     x2, x2, _st_orig_h@PAGEOFF
    ldr     w2, [x2]
    mov     w3, #256
    mov     w4, #192
    bl      _resize_image
    mov     x19, x0             // scr_pixels

    // Quantize
    mov     x0, x19
    mov     w1, #256
    mov     w2, #192
    adrp    x3, _st_mode@PAGE
    add     x3, x3, _st_mode@PAGEOFF
    ldr     w3, [x3]
    bl      _quantize_image

    // Export SCR
    mov     x0, x19
    mov     w1, #256
    mov     w2, #192
    adrp    x3, _path_buf@PAGE
    add     x3, x3, _path_buf@PAGEOFF
    bl      _export_scr

    // Free scr_pixels
    mov     x0, x19
    bl      _free

.Lde_done:
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ================================================================
// trim_newline — quita \n al final de un string
// X0 = string ptr
// ================================================================
.globl _trim_newline
.p2align 2

_trim_newline:
    mov     x1, x0
.Ltn_find_end:
    ldrb    w2, [x1]
    cbz     w2, .Ltn_check
    add     x1, x1, #1
    b       .Ltn_find_end
.Ltn_check:
    sub     x1, x1, #1
    cmp     x1, x0
    b.lt    .Ltn_done
    ldrb    w2, [x1]
    cmp     w2, #10             // '\n'
    b.ne    .Ltn_done
    strb    wzr, [x1]
.Ltn_done:
    ret

// ----------------------------------------------------------------
// Strings para export menu
// ----------------------------------------------------------------
.section __TEXT,__cstring
_menu_title:    .asciz "EXPORTAR COMO:"
_menu_h:        .asciz "[H]  HTML  -  Tabla pixel-art"
_menu_s:        .asciz "[S]  SCR   -  Nativo ZX Spectrum"
_menu_esc:      .asciz "[ESC] Cancelar"
_def_html:      .asciz "output_zx.html"
_def_scr:       .asciz "output_zx.scr"

// Strings locales para status bar (evitan tablas de punteros cross-module)
_local_mn_16:       .asciz "16 COLORES"
_local_mn_gray:     .asciz "GRISES"
_local_mn_bw:       .asciz "B&W"
_local_sn_small:    .asciz "SMALL"
_local_sn_medium:   .asciz "MEDIUM"
_local_sn_big:      .asciz "BIG"
_local_cn_safari:   .asciz "SAFARI-SAFE"
_local_cn_aggr:     .asciz "AGRESIVA"
_local_cn_none:     .asciz "SIN COMPR."
_local_status_fmt:  .asciz "MODO: %s    SIZE: %s (%d)"
_local_comp_fmt:    .asciz "COMPRESION: %s"
