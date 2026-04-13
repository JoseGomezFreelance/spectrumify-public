// ================================================================
// Spectrumify — Conversion de imagenes
// ARM64 AArch64 — macOS
// calculate_dimensions, resize_image, quantize_image
// ================================================================

.text

// ----------------------------------------------------------------
// calculate_dimensions(orig_w, orig_h, target_w, out_w_ptr, out_h_ptr)
// X0=orig_w, X1=orig_h, X2=target_w, X3=out_w_ptr, X4=out_h_ptr
// ----------------------------------------------------------------
.globl _calculate_dimensions
.p2align 2

_calculate_dimensions:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    cmp     w2, #0
    b.le    .Lcd_orig           // target_w <= 0: use original

    // out_w = target_w
    str     w2, [x3]

    // out_h = round(target_w / ratio) = round(target_w * orig_h / orig_w)
    mul     w5, w2, w1          // target_w * orig_h
    udiv    w6, w5, w0          // / orig_w
    // Rounding: check remainder
    msub    w7, w6, w0, w5      // remainder = target_w*orig_h - quot*orig_w
    lsl     w7, w7, #1          // remainder * 2
    cmp     w7, w0              // if remainder*2 >= orig_w, round up
    b.lt    .Lcd_no_round
    add     w6, w6, #1
.Lcd_no_round:
    cmp     w6, #1
    csel    w6, w6, w6, ge      // max(1, result)
    mov     w7, #1
    cmp     w6, #0
    csel    w6, w7, w6, le
    str     w6, [x4]

    ldp     x29, x30, [sp], #16
    ret

.Lcd_orig:
    str     w0, [x3]
    str     w1, [x4]
    ldp     x29, x30, [sp], #16
    ret

// ----------------------------------------------------------------
// resize_image(src, sw, sh, dw, dh) -> ptr (malloc'd)
// X0=src_ptr, X1=sw, X2=sh, X3=dw, X4=dh
// Retorna X0=dst_ptr (caller debe free)
// Resize nearest-neighbor (mas simple, suficiente para pixel-art)
// ----------------------------------------------------------------
.globl _resize_image
.p2align 2

_resize_image:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]

    mov     x19, x0             // src
    mov     w20, w1             // sw
    mov     w21, w2             // sh
    mov     w22, w3             // dw
    mov     w23, w4             // dh

    // malloc(dw * dh * 3)
    mul     w0, w22, w23
    mov     w1, #3
    mul     w0, w0, w1
    sxtw    x0, w0
    bl      _malloc
    mov     x24, x0             // dst

    cbz     x24, .Lrs_done

    // Nearest-neighbor resize
    mov     w5, #0              // y = 0
.Lrs_yloop:
    cmp     w5, w23
    b.ge    .Lrs_done

    // sy = y * sh / dh
    mul     w6, w5, w21
    udiv    w6, w6, w23         // sy

    mov     w7, #0              // x = 0
.Lrs_xloop:
    cmp     w7, w22
    b.ge    .Lrs_xnext

    // sx = x * sw / dw
    mul     w8, w7, w20
    udiv    w8, w8, w22         // sx

    // src_idx = (sy * sw + sx) * 3
    mul     w9, w6, w20
    add     w9, w9, w8
    mov     w10, #3
    mul     w9, w9, w10
    sxtw    x9, w9

    // dst_idx = (y * dw + x) * 3
    mul     w11, w5, w22
    add     w11, w11, w7
    mul     w11, w11, w10
    sxtw    x11, w11

    // Copy 3 bytes
    ldrb    w12, [x19, x9]
    strb    w12, [x24, x11]
    add     x9, x9, #1
    add     x11, x11, #1
    ldrb    w12, [x19, x9]
    strb    w12, [x24, x11]
    add     x9, x9, #1
    add     x11, x11, #1
    ldrb    w12, [x19, x9]
    strb    w12, [x24, x11]

    add     w7, w7, #1
    b       .Lrs_xloop

.Lrs_xnext:
    add     w5, w5, #1
    b       .Lrs_yloop

.Lrs_done:
    mov     x0, x24             // return dst

    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// ----------------------------------------------------------------
// quantize_image(pixels, w, h, mode)
// X0=pixels_ptr, X1=w, X2=h, X3=mode
// Cuantiza in-place. mode: 0=16col, 1=gray, 2=bw
// ----------------------------------------------------------------
.globl _quantize_image
.p2align 2

_quantize_image:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    mov     x19, x0             // pixels
    mul     w20, w1, w2         // total = w * h
    mov     w21, w3             // mode

    // Seleccionar paleta segun modo
    cmp     w21, #1
    b.eq    .Lq_gray
    cmp     w21, #2
    b.eq    .Lq_bw

    // mode 0: 16 colores
    adrp    x22, _palette_16@PAGE
    add     x22, x22, _palette_16@PAGEOFF
    mov     w23, #16
    b       .Lq_loop

.Lq_gray:
    adrp    x22, _palette_gray@PAGE
    add     x22, x22, _palette_gray@PAGEOFF
    mov     w23, #4
    b       .Lq_loop

.Lq_bw:
    adrp    x22, _palette_bw@PAGE
    add     x22, x22, _palette_bw@PAGEOFF
    mov     w23, #2

.Lq_loop:
    mov     w5, #0              // i = 0

.Lq_pixel:
    cmp     w5, w20
    b.ge    .Lq_done

    // Cargar pixel
    mov     w6, #3
    mul     w7, w5, w6          // offset = i * 3
    sxtw    x7, w7
    ldrb    w0, [x19, x7]      // R
    add     x8, x19, x7
    ldrb    w1, [x8, #1]       // G
    ldrb    w2, [x8, #2]       // B

    // Llamar nearest_color(R, G, B, palette, n)
    mov     x3, x22            // palette ptr
    mov     w4, w23             // palette len

    // Guardar en stack antes de call
    stp     x5, x19, [sp, #-16]!
    stp     x20, x22, [sp, #-16]!
    str     x23, [sp, #-16]!

    bl      _nearest_color

    // Restaurar
    ldr     x23, [sp], #16
    ldp     x20, x22, [sp], #16
    ldp     x5, x19, [sp], #16

    // Guardar resultado
    mov     w6, #3
    mul     w7, w5, w6
    sxtw    x7, w7
    strb    w0, [x19, x7]      // R
    add     x8, x19, x7
    strb    w1, [x8, #1]       // G
    strb    w2, [x8, #2]       // B

    add     w5, w5, #1
    b       .Lq_pixel

.Lq_done:
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret
