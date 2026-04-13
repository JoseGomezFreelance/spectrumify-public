// ================================================================
// Spectrumify — Export HTML y SCR
// ARM64 AArch64 — macOS
// ================================================================

.text

// ----------------------------------------------------------------
// Strings constantes
// ----------------------------------------------------------------
.section __TEXT,__cstring
.p2align 2
_str_table_open:    .asciz "<table cellpadding=\"0\" cellspacing=\"0\">\n"
_str_table_close:   .asciz "</table>\n"
_str_tr_open:       .asciz "<tr>"
_str_tr_close:      .asciz "</tr>\n"
_str_td_fmt:        .asciz "<td width=\"%d\" height=\"%d\" bgcolor=\"%s\"></td>"
_str_wb:            .asciz "wb"
_str_w:             .asciz "w"

// ----------------------------------------------------------------
// export_html(pixels, w, h, cell_size, path)
// X0=pixels, X1=w, X2=h, X3=cell_size, X4=path
// ----------------------------------------------------------------
.text
.globl _export_html
.p2align 2

_export_html:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    mov     x19, x0             // pixels
    mov     w20, w1             // w
    mov     w21, w2             // h
    mov     w22, w3             // cell_size
    mov     x23, x4             // path

    // fopen(path, "w")
    mov     x0, x23
    adrp    x1, _str_w@PAGE
    add     x1, x1, _str_w@PAGEOFF
    bl      _fopen
    mov     x24, x0             // FILE *f
    cbz     x24, .Leh_done

    // fprintf(f, "<table ...>\n")
    mov     x0, x24
    adrp    x1, _str_table_open@PAGE
    add     x1, x1, _str_table_open@PAGEOFF
    bl      _fprintf

    // for y = 0 to h-1
    mov     w25, #0             // y = 0
.Leh_yloop:
    cmp     w25, w21
    b.ge    .Leh_close

    // fprintf(f, "<tr>")
    mov     x0, x24
    adrp    x1, _str_tr_open@PAGE
    add     x1, x1, _str_tr_open@PAGEOFF
    bl      _fprintf

    // for x = 0 to w-1
    mov     w26, #0             // x = 0
.Leh_xloop:
    cmp     w26, w20
    b.ge    .Leh_xdone

    // idx = (y * w + x) * 3
    mul     w5, w25, w20
    add     w5, w5, w26
    mov     w6, #3
    mul     w5, w5, w6
    sxtw    x5, w5

    // Cargar pixel RGB
    ldrb    w0, [x19, x5]      // R
    add     x7, x19, x5
    ldrb    w1, [x7, #1]       // G
    ldrb    w2, [x7, #2]       // B

    // rgb_to_hex(R, G, B, buf) — buf en stack
    sub     sp, sp, #16
    mov     x3, sp
    bl      _rgb_to_hex
    // buf en sp

    // fprintf(f, "<td ...>")
    mov     x0, x24
    adrp    x1, _str_td_fmt@PAGE
    add     x1, x1, _str_td_fmt@PAGEOFF
    mov     w2, w22             // cell_size
    mov     w3, w22             // cell_size
    mov     x4, sp              // hex string
    bl      _fprintf

    add     sp, sp, #16

    add     w26, w26, #1
    b       .Leh_xloop

.Leh_xdone:
    // fprintf(f, "</tr>\n")
    mov     x0, x24
    adrp    x1, _str_tr_close@PAGE
    add     x1, x1, _str_tr_close@PAGEOFF
    bl      _fprintf

    add     w25, w25, #1
    b       .Leh_yloop

.Leh_close:
    // fprintf(f, "</table>\n")
    mov     x0, x24
    adrp    x1, _str_table_close@PAGE
    add     x1, x1, _str_table_close@PAGEOFF
    bl      _fprintf

    // fclose(f)
    mov     x0, x24
    bl      _fclose

.Leh_done:
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

// ----------------------------------------------------------------
// export_scr(pixels, w, h, path)
// X0=pixels (debe ser 256x192), X1=w, X2=h, X3=path
// Genera archivo .scr de 6912 bytes
// ----------------------------------------------------------------
.globl _export_scr
.p2align 2

_export_scr:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    str     x23, [sp, #48]

    mov     x19, x0             // pixels
    mov     x23, x3             // path

    // Verificar 256x192
    cmp     w1, #256
    b.ne    .Les_done
    cmp     w2, #192
    b.ne    .Les_done

    // Allocar bitmap(6144) + attrs(768) = 6912 en heap
    mov     x0, #6912
    bl      _calloc_wrapper
    mov     x20, x0             // buffer
    cbz     x20, .Les_done

    // Procesar bloques 8x8
    // Para simplificar, usamos ink=blanco, paper=negro + BRIGHT
    // (version simplificada del SCR export)
    mov     w5, #0              // by = 0
.Les_by:
    cmp     w5, #24
    b.ge    .Les_write

    mov     w6, #0              // bx = 0
.Les_bx:
    cmp     w6, #32
    b.ge    .Les_by_next

    // Para cada bloque 8x8: contar pixel mas comun (paper)
    // y segundo mas comun (ink), generar bitmap
    // Simplificacion: paper = color del pixel (0,0), ink = primer color distinto

    // Leer pixel (by*8, bx*8) como paper
    lsl     w7, w5, #3          // by*8
    lsl     w8, w6, #3          // bx*8
    mov     w9, #256
    mul     w10, w7, w9
    add     w10, w10, w8        // (by*8)*256 + bx*8
    mov     w11, #3
    mul     w10, w10, w11
    sxtw    x10, w10

    ldrb    w12, [x19, x10]     // paper R
    add     x13, x19, x10
    ldrb    w13, [x13, #1]      // paper G
    add     x14, x19, x10
    ldrb    w14, [x14, #2]      // paper B

    // Attr = BRIGHT | paper=0 | ink=7 (simplificado)
    mov     w15, #0x47          // bright=1, paper=0, ink=7
    mov     w9, #32
    mul     w10, w5, w9
    add     w10, w10, w6
    mov     w9, #6144
    add     w10, w10, w9        // attrs offset
    sxtw    x10, w10
    strb    w15, [x20, x10]

    // Generar bitmap para cada linea del bloque
    mov     w16, #0             // dy = 0
.Les_dy:
    cmp     w16, #8
    b.ge    .Les_bx_next

    mov     w17, #0             // byte_val = 0
    mov     w9, #0              // dx = 0
.Les_dx:
    cmp     w9, #8
    b.ge    .Les_store_byte

    // pixel_y = by*8 + dy, pixel_x = bx*8 + dx
    lsl     w10, w5, #3
    add     w10, w10, w16       // py
    lsl     w11, w6, #3
    add     w11, w11, w9        // px
    mov     w13, #256
    mul     w10, w10, w13
    add     w10, w10, w11       // py*256+px
    mov     w13, #3
    mul     w10, w10, w13       // *3
    sxtw    x10, w10

    // Brillo del pixel: si > 384 (128*3) es "claro" (ink)
    ldrb    w13, [x19, x10]
    add     x14, x19, x10
    ldrb    w14, [x14, #1]
    add     x15, x19, x10
    ldrb    w15, [x15, #2]
    add     w13, w13, w14
    add     w13, w13, w15       // R+G+B

    cmp     w13, #384
    b.lt    .Les_dx_next

    // Es ink (claro): set bit
    mov     w14, #0x80
    lsr     w14, w14, w9        // 0x80 >> dx
    orr     w17, w17, w14

.Les_dx_next:
    add     w9, w9, #1
    b       .Les_dx

.Les_store_byte:
    // Calcular offset en bitmap (layout no-lineal del Spectrum)
    lsl     w10, w5, #3
    add     w10, w10, w16       // py = by*8 + dy

    // offset = ((py&0xC0)<<5) | ((py&0x07)<<8) | ((py&0x38)<<2) | bx
    and     w11, w10, #0xC0
    lsl     w11, w11, #5
    and     w13, w10, #0x07
    lsl     w13, w13, #8
    orr     w11, w11, w13
    and     w13, w10, #0x38
    lsl     w13, w13, #2
    orr     w11, w11, w13
    orr     w11, w11, w6        // | bx
    sxtw    x11, w11

    strb    w17, [x20, x11]

    add     w16, w16, #1
    b       .Les_dy

.Les_bx_next:
    add     w6, w6, #1
    b       .Les_bx

.Les_by_next:
    add     w5, w5, #1
    b       .Les_by

.Les_write:
    // fopen(path, "wb")
    mov     x0, x23
    adrp    x1, _str_wb@PAGE
    add     x1, x1, _str_wb@PAGEOFF
    bl      _fopen
    mov     x21, x0
    cbz     x21, .Les_free

    // fwrite(buffer, 1, 6912, f)
    mov     x0, x20
    mov     x1, #1
    mov     x2, #6912
    mov     x3, x21
    bl      _fwrite

    // fclose(f)
    mov     x0, x21
    bl      _fclose

.Les_free:
    mov     x0, x20
    bl      _free

.Les_done:
    ldr     x23, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// Wrapper para calloc(1, size)
.globl _calloc_wrapper
_calloc_wrapper:
    mov     x1, x0
    mov     x0, #1
    b       _calloc
