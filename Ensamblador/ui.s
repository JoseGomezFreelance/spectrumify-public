// ================================================================
// Spectrumify — UI renderizado SDL2
// ARM64 AArch64 — macOS
// ================================================================

.text

// ----------------------------------------------------------------
// Constantes de layout
// ----------------------------------------------------------------
.equ WIN_W, 1024
.equ WIN_H, 700
.equ HEADER_H, 40
.equ STATUS_H, 60
.equ CONTROLS_H, 36
.equ SEP_H, 2
.equ MARGIN, 16
.equ PREVIEW_Y, 42     // HEADER_H + SEP_H
.equ PREVIEW_H, 558    // WIN_H - HEADER_H - STATUS_H - CONTROLS_H - SEP_H*3

// ----------------------------------------------------------------
// Strings
// ----------------------------------------------------------------
.section __TEXT,__cstring
.globl _str_title
.globl _str_copy
.globl _str_original
.globl _str_pixelart
.globl _str_noimage
.globl _str_load, _str_oad, _str_export, _str_xport
.globl _str_mode, _str_ode, _str_size, _str_ize
.globl _str_zoom, _str_zoomtxt, _str_comp, _str_ompress
.globl _str_quit, _str_uit
.globl _str_scr_title, _str_scr_sub

_str_title:     .asciz "SPECTRUMIFY v0.1"
_str_copy:      .asciz "(c) 2026 JGF"
_str_original:  .asciz "ORIGINAL"
_str_pixelart:  .asciz "PIXEL-ART"
_str_noimage:   .asciz "Pulsa [L] para cargar"
_str_load:      .asciz "[L]"
_str_oad:       .asciz "OAD  "
_str_export:    .asciz "[E]"
_str_xport:     .asciz "XPORT  "
_str_mode:      .asciz "[M]"
_str_ode:       .asciz "ODE  "
_str_size:      .asciz "[S]"
_str_ize:       .asciz "IZE  "
_str_zoom:      .asciz "[+/-]"
_str_zoomtxt:   .asciz " ZOOM  "
_str_comp:      .asciz "[C]"
_str_ompress:   .asciz "OMPRESS  "
_str_quit:      .asciz "[Q]"
_str_uit:       .asciz "UIT"
.globl _str_status_fmt
.globl _str_comp_fmt
_str_status_fmt: .asciz "MODO: %s    SIZE: %s (%d)"
_str_comp_fmt:  .asciz "COMPRESION: %s"
_str_scr_title: .asciz "SCR VIEWER"
_str_scr_sub:   .asciz "ZX Spectrum 48K"

// Mode/size/compression name arrays (punteros)
.section __DATA,__const
.p2align 3
.globl _mode_names
_mode_names:
    .quad _mn_16
    .quad _mn_gray
    .quad _mn_bw
.globl _size_names
_size_names:
    .quad _sn_small
    .quad _sn_medium
    .quad _sn_big
.globl _comp_names
_comp_names:
    .quad _cn_safari
    .quad _cn_aggr
    .quad _cn_none

.section __TEXT,__cstring
_mn_16:     .asciz "16 COLORES"
_mn_gray:   .asciz "GRISES"
_mn_bw:     .asciz "B&W"
_sn_small:  .asciz "SMALL"
_sn_medium: .asciz "MEDIUM"
_sn_big:    .asciz "BIG"
_cn_safari: .asciz "SAFARI-SAFE"
_cn_aggr:   .asciz "AGRESIVA"
_cn_none:   .asciz "SIN COMPR."

// ----------------------------------------------------------------
// draw_char(renderer, x, y, ch, r, g, b)
// X0=ren, X1=x, X2=y, X3=ch, X4=r, X5=g, X6=b
// ----------------------------------------------------------------
.text
.globl _draw_char
.p2align 2

_draw_char:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x19, x0             // renderer
    mov     w20, w1             // x
    mov     w21, w2             // y
    mov     w22, w3             // ch

    // idx = ch - 32
    sub     w22, w22, #32
    cmp     w22, #0
    b.lt    .Ldc_done
    cmp     w22, #95
    b.gt    .Ldc_done

    // SDL_SetRenderDrawColor(ren, r, g, b, 255)
    mov     x0, x19
    mov     w1, w4
    mov     w2, w5
    mov     w3, w6
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor

    // font_ptr = font_8x8 + idx * 8
    adrp    x23, _font_8x8@PAGE
    add     x23, x23, _font_8x8@PAGEOFF
    lsl     w24, w22, #3        // idx * 8
    add     x23, x23, x24      // font_ptr

    // Copiar 8 bytes del glyph al stack
    sub     sp, sp, #16
    ldr     x8, [x23]
    str     x8, [sp]            // glyph data en stack

    mov     w8, #0              // row
.Ldc_row:
    cmp     w8, #8
    b.ge    .Ldc_done2

    ldrb    w9, [sp, x8]       // bits = glyph[row] desde stack

    mov     w10, #0             // col
.Ldc_col:
    cmp     w10, #8
    b.ge    .Ldc_row_next

    mov     w11, #0x80
    lsr     w11, w11, w10
    tst     w9, w11
    b.eq    .Ldc_col_next

    // Guardar row, col, bits
    sub     sp, sp, #16
    str     w8, [sp]
    str     w10, [sp, #4]
    str     w9, [sp, #8]

    mov     x0, x19
    add     w1, w20, w10       // x + col
    add     w2, w21, w8        // y + row
    bl      _SDL_RenderDrawPoint

    // Restaurar
    ldr     w8, [sp]
    ldr     w10, [sp, #4]
    ldr     w9, [sp, #8]
    add     sp, sp, #16

.Ldc_col_next:
    add     w10, w10, #1
    b       .Ldc_col

.Ldc_row_next:
    add     w8, w8, #1
    b       .Ldc_row

.Ldc_done2:
    add     sp, sp, #16

.Ldc_done:
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ----------------------------------------------------------------
// draw_text(renderer, x, y, str, r, g, b)
// X0=ren, X1=x, X2=y, X3=str, X4=r, X5=g, X6=b
// Dibuja string con font 8x8 (escala 1)
// ----------------------------------------------------------------
.globl _draw_text
.p2align 2

_draw_text:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x19, x0             // renderer
    mov     w20, w1             // x
    mov     w21, w2             // y
    mov     x22, x3             // str
    mov     w23, w4             // r
    mov     w24, w5             // g
    // b queda en w6, guardamos
    str     w6, [sp, #-16]!

.Ldt_loop:
    ldrb    w8, [x22]
    cbz     w8, .Ldt_done

    // draw_char(ren, x, y, ch, r, g, b)
    mov     x0, x19
    mov     w1, w20
    mov     w2, w21
    mov     w3, w8
    mov     w4, w23
    mov     w5, w24
    ldr     w6, [sp]            // b
    bl      _draw_char

    add     w20, w20, #8        // x += 8
    add     x22, x22, #1       // str++
    b       .Ldt_loop

.Ldt_done:
    add     sp, sp, #16
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ----------------------------------------------------------------
// draw_text_scaled(renderer, x, y, str, r, g, b, scale)
// Como draw_text pero con factor de escala
// X0=ren, X1=x, X2=y, X3=str, X4=r, X5=g, X6=b, X7=scale
// ----------------------------------------------------------------
.globl _draw_text_scaled
.p2align 2

_draw_text_scaled:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    mov     x19, x0             // renderer
    mov     w20, w1             // x_start
    mov     w21, w2             // y
    mov     x22, x3             // str
    mov     w23, w4             // r
    mov     w24, w5             // g
    mov     w25, w6             // b
    mov     w26, w7             // scale

    cmp     w26, #1
    b.le    .Ldts_simple

    // Escala > 1: precomputar font, dibujar rects
    // Usamos stack para guardar estado entre llamadas SDL
    mov     w20, w1             // x_cursor (callee-saved)

.Ldts_char:
    ldrb    w8, [x22]
    cbz     w8, .Ldts_done

    sub     w9, w8, #32
    cmp     w9, #0
    b.lt    .Ldts_next_char
    cmp     w9, #95
    b.gt    .Ldts_next_char

    // SDL_SetRenderDrawColor (una vez por caracter)
    mov     x0, x19
    mov     w1, w23
    mov     w2, w24
    mov     w3, w25
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor

    // Precomputar font_ptr — guardar en stack
    adrp    x10, _font_8x8@PAGE
    add     x10, x10, _font_8x8@PAGEOFF
    lsl     w11, w9, #3
    add     x10, x10, x11      // x10 = font glyph ptr

    // Leer los 8 bytes del glyph al stack para no perderlos
    sub     sp, sp, #32
    str     x10, [sp]           // [sp] = font_ptr
    // Copiar 8 bytes del font al stack para acceso seguro
    ldr     x11, [x10]          // cargar 8 bytes del glyph
    str     x11, [sp, #8]       // [sp+8] = glyph data (8 bytes)
    str     w20, [sp, #16]      // [sp+16] = x_cursor
    str     w9, [sp, #20]       // [sp+20] = char_idx

    mov     w12, #0             // row
.Ldts_row:
    cmp     w12, #8
    b.ge    .Ldts_row_done

    // Leer bits del glyph desde el stack
    add     x10, sp, #8
    ldrb    w13, [x10, x12]    // bits = glyph[row]

    mov     w14, #0             // col
.Ldts_col:
    cmp     w14, #8
    b.ge    .Ldts_row_next

    mov     w15, #0x80
    lsr     w15, w15, w14
    tst     w13, w15
    b.eq    .Ldts_col_next

    // Guardar row, col, bits antes de SDL call
    sub     sp, sp, #16
    str     w12, [sp]           // row
    str     w14, [sp, #4]       // col
    str     w13, [sp, #8]       // bits

    // SDL_RenderFillRect
    sub     sp, sp, #16
    ldr     w0, [sp, #48]       // x_cursor (sp+32+16)
    mul     w1, w14, w26
    add     w0, w0, w1
    str     w0, [sp]            // rect.x
    mul     w0, w12, w26
    add     w0, w0, w21
    str     w0, [sp, #4]        // rect.y
    str     w26, [sp, #8]       // rect.w
    str     w26, [sp, #12]      // rect.h
    mov     x0, x19
    mov     x1, sp
    bl      _SDL_RenderFillRect
    add     sp, sp, #16

    // Restaurar row, col, bits
    ldr     w12, [sp]
    ldr     w14, [sp, #4]
    ldr     w13, [sp, #8]
    add     sp, sp, #16

.Ldts_col_next:
    add     w14, w14, #1
    b       .Ldts_col

.Ldts_row_next:
    add     w12, w12, #1
    b       .Ldts_row

.Ldts_row_done:
    // Restaurar x_cursor del stack
    ldr     w20, [sp, #16]
    add     sp, sp, #32

.Ldts_next_char:
    // x += 8 * scale
    lsl     w8, w26, #3
    add     w20, w20, w8
    add     x22, x22, #1
    b       .Ldts_char

.Ldts_simple:
    // Escala 1: usar draw_text normal
    mov     x0, x19
    mov     w1, w20
    mov     w2, w21
    mov     x3, x22
    mov     w4, w23
    mov     w5, w24
    mov     w6, w25
    bl      _draw_text

.Ldts_done:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ----------------------------------------------------------------
// draw_separator(renderer, y)
// X0=ren, X1=y
// ----------------------------------------------------------------
.globl _draw_separator
.p2align 2

_draw_separator:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    mov     x19, x0

    // SDL_SetRenderDrawColor(ren, 0, 170, 170, 255)
    mov     x0, x19
    mov     w1, #0
    mov     w2, #170
    mov     w3, #170
    mov     w4, #255
    bl      _SDL_SetRenderDrawColor

    // SDL_RenderFillRect(ren, &rect)
    sub     sp, sp, #16
    str     wzr, [sp]           // x = 0
    str     w1, [sp, #4]        // y (already in w1 from entry... need to save)
    // Oops, w1 was clobbered. Let me fix: save y before the call
    // Actually let me redo this properly
    add     sp, sp, #16

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// NOTE: draw_separator reimplementado limpio en main.s como inline
// por la complejidad de preservar registros. Esta version es stub.

// ----------------------------------------------------------------
// draw_header(renderer)
// X0=ren
// ----------------------------------------------------------------
.globl _draw_header
.p2align 2

_draw_header:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!

    mov     x19, x0

    // Titulo: doble render para simular negrita (evita bugs del scaled render)
    mov     x0, x19
    mov     w1, #MARGIN
    mov     w2, #8
    adrp    x3, _str_title@PAGE
    add     x3, x3, _str_title@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    mov     x0, x19
    mov     w1, #(MARGIN+1)
    mov     w2, #8
    adrp    x3, _str_title@PAGE
    add     x3, x3, _str_title@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text

    // draw_text(ren, WIN_W-13*8-MARGIN, 18, "(c) 2026 JGF", 85,85,85)
    mov     x0, x19
    mov     w1, #(WIN_W - 13*8 - MARGIN)
    mov     w2, #18
    adrp    x3, _str_copy@PAGE
    add     x3, x3, _str_copy@PAGEOFF
    mov     w4, #85
    mov     w5, #85
    mov     w6, #85
    bl      _draw_text

    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// ----------------------------------------------------------------
// draw_controls(renderer)
// X0=ren
// ----------------------------------------------------------------
.globl _draw_controls
.p2align 2

_draw_controls:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x0             // renderer
    mov     w20, #MARGIN        // x cursor

    // Macro-like: green key, white label
    // [L]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_load@PAGE
    add     x3, x3, _str_load@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24       // 3*8

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_oad@PAGE
    add     x3, x3, _str_oad@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #40       // 5*8

    // [E]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_export@PAGE
    add     x3, x3, _str_export@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_xport@PAGE
    add     x3, x3, _str_xport@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #56       // 7*8

    // [M]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_mode@PAGE
    add     x3, x3, _str_mode@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_ode@PAGE
    add     x3, x3, _str_ode@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #40

    // [S]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_size@PAGE
    add     x3, x3, _str_size@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_ize@PAGE
    add     x3, x3, _str_ize@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #40

    // [+/-]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_zoom@PAGE
    add     x3, x3, _str_zoom@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #40       // 5*8

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_zoomtxt@PAGE
    add     x3, x3, _str_zoomtxt@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #56       // 7*8

    // [C]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_comp@PAGE
    add     x3, x3, _str_comp@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_ompress@PAGE
    add     x3, x3, _str_ompress@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text
    add     w20, w20, #72       // 9*8

    // [Q]
    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_quit@PAGE
    add     x3, x3, _str_quit@PAGEOFF
    mov     w4, #85
    mov     w5, #255
    mov     w6, #85
    bl      _draw_text
    add     w20, w20, #24

    mov     x0, x19
    mov     w1, w20
    mov     w2, #(WIN_H - CONTROLS_H + 10)
    adrp    x3, _str_uit@PAGE
    add     x3, x3, _str_uit@PAGEOFF
    mov     w4, #255
    mov     w5, #255
    mov     w6, #255
    bl      _draw_text

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
