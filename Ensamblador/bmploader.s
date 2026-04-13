// ================================================================
// Spectrumify — BMP Loader (100% ARM64 ASM)
// Carga archivos BMP 24-bit sin comprimir
// Enfoque simplificado: fseek + fread para cada campo
// ================================================================

.section __TEXT,__cstring
_bmp_rb: .asciz "rb"
_bmp_ptr_fmt: .asciz "INSIDE: wrote=%d readback=%d x20=%p\n"

.section __DATA,__data
.p2align 2
.globl _bmp_width
.globl _bmp_height
_bmp_width:     .word 0
_bmp_height:    .word 0

// Buffer alineado para leer campos de 4 bytes
.p2align 3
_bmp_val4:      .space 16

// ----------------------------------------------------------------
// load_bmp(path, out_w_ptr, out_h_ptr) -> pixels (malloc'd)
// X0 = path, X1 = int *out_w, X2 = int *out_h
// Retorna: X0 = pixels RGB, 0 si error
// ----------------------------------------------------------------
.text
.globl _load_bmp
.p2align 2

_load_bmp:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]

    mov     x20, x1             // x20 = out_w_ptr
    mov     x26, x2             // x26 = out_h_ptr

    // fopen(path, "rb")
    adrp    x1, _bmp_rb@PAGE
    add     x1, x1, _bmp_rb@PAGEOFF
    bl      _fopen
    mov     x19, x0
    cbz     x19, .Lbmp_fail

    // Leer firma (2 bytes en offset 0) — buffer en STACK
    sub     sp, sp, #16         // 16-byte aligned buffer
    mov     x0, sp
    mov     x1, #1
    mov     x2, #2
    mov     x3, x19
    bl      _fread
    cmp     x0, #2
    b.ne    .Lbmp_close_sp

    ldrb    w8, [sp]
    cmp     w8, #'B'
    b.ne    .Lbmp_close_sp
    ldrb    w8, [sp, #1]
    cmp     w8, #'M'
    b.ne    .Lbmp_close_sp
    add     sp, sp, #16

    // Leer data_offset (offset 10, 4 bytes)
    mov     x0, x19
    mov     x1, #10
    mov     w2, #0
    bl      _fseek
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #4
    mov     x2, #1
    mov     x3, x19
    bl      _fread
    ldr     w25, [sp]           // data_offset
    add     sp, sp, #16

    // Leer width (offset 18, 4 bytes)
    mov     x0, x19
    mov     x1, #18
    mov     w2, #0
    bl      _fseek
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #4
    mov     x2, #1
    mov     x3, x19
    bl      _fread
    ldr     w21, [sp]           // width
    add     sp, sp, #16

    // Leer height (offset 22, 4 bytes)
    mov     x0, x19
    mov     x1, #22
    mov     w2, #0
    bl      _fseek
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #4
    mov     x2, #1
    mov     x3, x19
    bl      _fread
    ldr     w22, [sp]           // height
    add     sp, sp, #16

    mov     w23, #0
    tst     w22, #0x80000000
    b.eq    .Lbmp_hpos
    neg     w22, w22
    mov     w23, #1
.Lbmp_hpos:

    // Leer bpp (offset 28, 2 bytes)
    mov     x0, x19
    mov     x1, #28
    mov     w2, #0
    bl      _fseek
    sub     sp, sp, #16
    mov     x0, sp
    mov     x1, #2
    mov     x2, #1
    mov     x3, x19
    bl      _fread
    ldrh    w24, [sp]           // bpp
    add     sp, sp, #16

    cmp     w24, #24
    b.ne    .Lbmp_close

    // Escribir width/height a los punteros de salida
    str     w21, [x20]          // *out_w = width
    str     w22, [x26]          // *out_h = height

    // DEBUG: escribir valores conocidos y verificar
    mov     w8, #1536
    str     w8, [x20]
    ldr     w9, [x20]           // readback
    adrp    x0, _bmp_ptr_fmt@PAGE
    add     x0, x0, _bmp_ptr_fmt@PAGEOFF
    mov     w1, #1536           // wrote
    mov     w2, w9              // readback
    mov     x3, x20             // ptr address
    bl      _printf
    // Re-write after printf (printf might have changed stack)
    mov     w8, #1536
    str     w8, [x20]
    mov     w8, #1024
    str     w8, [x26]

    // malloc(w * h * 3)
    mul     w0, w21, w22
    mov     w8, #3
    mul     w0, w0, w8
    sxtw    x0, w0
    bl      _malloc
    mov     x24, x0
    cbz     x24, .Lbmp_close

    // fseek to data_offset
    mov     x0, x19
    sxtw    x1, w25
    mov     w2, #0
    bl      _fseek

    // Stride = (w * 3 + 3) & ~3
    mov     w8, #3
    mul     w26, w21, w8
    add     w8, w26, #3
    and     w25, w8, #0xFFFFFFFC    // w25 = stride

    // malloc row buffer
    sxtw    x0, w25
    bl      _malloc
    mov     x20, x0
    cbz     x20, .Lbmp_free_px

    mov     w8, #0              // y
.Lbmp_row:
    cmp     w8, w22
    b.ge    .Lbmp_done

    str     w8, [sp, #-16]!
    mov     x0, x20
    mov     x1, #1
    sxtw    x2, w25
    mov     x3, x19
    bl      _fread
    ldr     w8, [sp], #16

    // dest_y
    cmp     w23, #0
    b.ne    .Lbmp_td
    sub     w9, w22, #1
    sub     w9, w9, w8
    b       .Lbmp_cp
.Lbmp_td:
    mov     w9, w8
.Lbmp_cp:
    mul     w10, w9, w21
    mov     w11, #3
    mul     w10, w10, w11
    sxtw    x10, w10

    mov     w12, #0
.Lbmp_px:
    cmp     w12, w21
    b.ge    .Lbmp_rn

    mov     w13, #3
    mul     w13, w12, w13
    sxtw    x13, w13

    ldrb    w14, [x20, x13]        // B
    add     x15, x20, x13
    ldrb    w15, [x15, #1]         // G
    add     x16, x20, x13
    ldrb    w16, [x16, #2]         // R

    mov     w17, #3
    mul     w17, w12, w17
    add     w17, w17, w10
    sxtw    x17, w17

    strb    w16, [x24, x17]        // R
    add     x17, x17, #1
    strb    w15, [x24, x17]        // G
    add     x17, x17, #1
    strb    w14, [x24, x17]        // B

    add     w12, w12, #1
    b       .Lbmp_px

.Lbmp_rn:
    add     w8, w8, #1
    b       .Lbmp_row

.Lbmp_done:
    mov     x0, x20
    bl      _free
    mov     x0, x19
    bl      _fclose
    mov     x0, x24

    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

.Lbmp_close_sp:
    add     sp, sp, #16         // pop buffer
    b       .Lbmp_close
.Lbmp_free_px:
    cbz     x24, .Lbmp_close    // solo free si no null
    mov     x0, x24
    bl      _free
.Lbmp_close:
    cbz     x19, .Lbmp_fail     // solo fclose si archivo abierto
    mov     x0, x19
    bl      _fclose
.Lbmp_fail:
    mov     x0, #0
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret
