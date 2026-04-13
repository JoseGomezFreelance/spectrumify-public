// ================================================================
// Spectrumify — Paleta ZX Spectrum + nearest_color + rgb_to_hex
// ARM64 AArch64 — macOS
// (c) 2026 JGF
// ================================================================

// ----------------------------------------------------------------
// Datos: paletas de colores (R, G, B por color, padding a 4 bytes)
// ----------------------------------------------------------------

.section __DATA,__const
.globl _palette_16
.globl _palette_gray
.globl _palette_bw
.globl _palette_16_len
.globl _palette_gray_len
.globl _palette_bw_len

.p2align 2
_palette_16:
    .byte 0,0,0,0           // 0: black
    .byte 0,0,170,0         // 1: blue dark
    .byte 170,0,0,0         // 2: red dark
    .byte 170,0,170,0       // 3: magenta dark
    .byte 0,170,0,0         // 4: green dark
    .byte 0,170,170,0       // 5: cyan
    .byte 170,85,0,0        // 6: brown
    .byte 170,170,170,0     // 7: gray light
    .byte 85,85,85,0        // 8: gray dark
    .byte 85,85,255,0       // 9: blue bright
    .byte 255,85,85,0       // 10: red bright
    .byte 255,85,255,0      // 11: magenta bright
    .byte 85,255,85,0       // 12: green bright
    .byte 85,255,255,0      // 13: cyan bright
    .byte 255,255,85,0      // 14: yellow
    .byte 255,255,255,0     // 15: white

_palette_gray:
    .byte 0,0,0,0
    .byte 85,85,85,0
    .byte 170,170,170,0
    .byte 255,255,255,0

_palette_bw:
    .byte 0,0,0,0
    .byte 255,255,255,0

_palette_16_len:   .word 16
_palette_gray_len: .word 4
_palette_bw_len:   .word 2

// Hex digits lookup
.globl _hex_digits
_hex_digits:
    .ascii "0123456789ABCDEF"

// ----------------------------------------------------------------
// nearest_color: busca el color mas cercano en la paleta
// ----------------------------------------------------------------
// X0 = R, X1 = G, X2 = B
// X3 = puntero a paleta (array de {R,G,B,pad} x 4 bytes por color)
// X4 = numero de colores en la paleta
// Retorna: X0 = R, X1 = G, X2 = B del color mas cercano
// ----------------------------------------------------------------

.text
.globl _nearest_color
.p2align 2

_nearest_color:
    // Guardar callee-saved
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    mov     w8, #0x7FFFFFFF     // best_dist = MAX_INT
    mov     w9, #0              // best_index = 0
    mov     w10, #0             // i = 0

.Lnc_loop:
    cmp     w10, w4
    b.ge    .Lnc_done

    // Cargar color de paleta[i]
    lsl     w11, w10, #2        // offset = i * 4
    add     x12, x3, x11       // ptr = palette + offset
    ldrb    w13, [x12]          // cr = palette[i].R
    ldrb    w14, [x12, #1]      // cg = palette[i].G
    ldrb    w15, [x12, #2]      // cb = palette[i].B

    // dr = R - cr
    sub     w16, w0, w13
    mul     w16, w16, w16       // dr*dr

    // dg = G - cg
    sub     w17, w1, w14
    madd    w16, w17, w17, w16  // + dg*dg

    // db = B - cb
    sub     w17, w2, w15
    madd    w16, w17, w17, w16  // + db*db

    // if d < best_dist
    cmp     w16, w8
    b.ge    .Lnc_next
    mov     w8, w16             // best_dist = d
    mov     w9, w10             // best_index = i

.Lnc_next:
    add     w10, w10, #1
    b       .Lnc_loop

.Lnc_done:
    // Cargar el color ganador
    lsl     w9, w9, #2
    add     x9, x3, x9
    ldrb    w0, [x9]            // R
    ldrb    w1, [x9, #1]        // G
    ldrb    w2, [x9, #2]        // B

    ldp     x29, x30, [sp], #16
    ret

// ----------------------------------------------------------------
// rgb_to_hex: convierte RGB a string "#RGB" o "#RRGGBB"
// ----------------------------------------------------------------
// X0 = R, X1 = G, X2 = B
// X3 = buffer ptr (debe tener al menos 8 bytes)
// Retorna: X0 = longitud del string (4 o 7)
// ----------------------------------------------------------------

.globl _rgb_to_hex
.p2align 2

_rgb_to_hex:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Calcular nibbles
    lsr     w8, w0, #4          // rh = R >> 4
    and     w9, w0, #0xF        // rl = R & 0xF
    lsr     w10, w1, #4         // gh = G >> 4
    and     w11, w1, #0xF       // gl = G & 0xF
    lsr     w12, w2, #4         // bh = B >> 4
    and     w13, w2, #0xF       // bl = B & 0xF

    // Comprobar si se puede abreviar
    cmp     w8, w9
    b.ne    .Lhex_long
    cmp     w10, w11
    b.ne    .Lhex_long
    cmp     w12, w13
    b.ne    .Lhex_long

    // Formato corto: #RGB
    adrp    x14, _hex_digits@PAGE
    add     x14, x14, _hex_digits@PAGEOFF

    mov     w15, #'#'
    strb    w15, [x3]
    ldrb    w15, [x14, x8]
    strb    w15, [x3, #1]
    ldrb    w15, [x14, x10]
    strb    w15, [x3, #2]
    ldrb    w15, [x14, x12]
    strb    w15, [x3, #3]
    strb    wzr, [x3, #4]       // null terminator
    mov     x0, #4

    ldp     x29, x30, [sp], #16
    ret

.Lhex_long:
    // Formato largo: #RRGGBB
    adrp    x14, _hex_digits@PAGE
    add     x14, x14, _hex_digits@PAGEOFF

    mov     w15, #'#'
    strb    w15, [x3]
    ldrb    w15, [x14, x8]
    strb    w15, [x3, #1]
    ldrb    w15, [x14, x9]
    strb    w15, [x3, #2]
    ldrb    w15, [x14, x10]
    strb    w15, [x3, #3]
    ldrb    w15, [x14, x11]
    strb    w15, [x3, #4]
    ldrb    w15, [x14, x12]
    strb    w15, [x3, #5]
    ldrb    w15, [x14, x13]
    strb    w15, [x3, #6]
    strb    wzr, [x3, #7]       // null terminator
    mov     x0, #7

    ldp     x29, x30, [sp], #16
    ret
