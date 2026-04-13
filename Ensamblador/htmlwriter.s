// ================================================================
// Spectrumify — Export HTML (100% ARM64 ASM)
// Escritura directa con fwrite, sin fprintf
// Reemplaza export_html_c de stb_wrapper.c
// ================================================================

.text

.section __TEXT,__cstring
_hw_w_mode:     .asciz "w"
_hw_table_open: .asciz "<table cellpadding=\"0\" cellspacing=\"0\">\n"
_hw_table_close:.asciz "</table>\n"
_hw_tr_open:    .asciz "<tr>"
_hw_tr_close:   .asciz "</tr>\n"
_hw_td_pre:     .asciz "<td width=\""
_hw_td_mid1:    .asciz "\" height=\""
_hw_td_mid2:    .asciz "\" bgcolor=\""
_hw_td_end:     .asciz "\"></td>"

// ----------------------------------------------------------------
// itoa_simple: convierte entero positivo a string decimal
// W0 = numero, X1 = buffer ptr
// Retorna: X0 = longitud
// ----------------------------------------------------------------
.text
.globl _itoa_simple
.p2align 2

_itoa_simple:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]

    mov     w8, w0              // numero
    mov     x9, x1              // buffer

    // Caso especial: 0
    cmp     w8, #0
    b.ne    .Litoa_nonzero
    mov     w10, #'0'
    strb    w10, [x9]
    strb    wzr, [x9, #1]
    mov     x0, #1
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.Litoa_nonzero:
    // Escribir digitos en orden inverso en stack temporal
    sub     sp, sp, #16
    mov     x10, sp             // temp buffer
    mov     w11, #0             // count

.Litoa_div:
    cbz     w8, .Litoa_reverse
    mov     w12, #10
    udiv    w13, w8, w12        // w13 = n / 10
    msub    w14, w13, w12, w8   // w14 = n % 10
    add     w14, w14, #'0'
    strb    w14, [x10, x11]
    add     w11, w11, #1
    mov     w8, w13
    b       .Litoa_div

.Litoa_reverse:
    // Copiar en orden correcto a buffer destino
    mov     w12, #0             // i = 0
.Litoa_rev_loop:
    cmp     w12, w11
    b.ge    .Litoa_done
    sub     w13, w11, w12
    sub     w13, w13, #1        // j = count - 1 - i
    sxtw    x13, w13
    ldrb    w14, [x10, x13]
    sxtw    x15, w12
    strb    w14, [x9, x15]
    add     w12, w12, #1
    b       .Litoa_rev_loop

.Litoa_done:
    sxtw    x12, w11
    strb    wzr, [x9, x12]     // null terminator
    mov     x0, x11             // return length
    sxtw    x0, w11
    add     sp, sp, #16

    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ----------------------------------------------------------------
// strlen_simple: calcula longitud de un string
// X0 = string ptr
// Retorna: X0 = longitud
// ----------------------------------------------------------------
.globl _strlen_simple
.p2align 2

_strlen_simple:
    mov     x1, x0
.Lsl_loop:
    ldrb    w2, [x1]
    cbz     w2, .Lsl_done
    add     x1, x1, #1
    b       .Lsl_loop
.Lsl_done:
    sub     x0, x1, x0
    ret

// ----------------------------------------------------------------
// fwrite_str: escribe un string completo a un FILE*
// X0 = string ptr, X1 = FILE*
// ----------------------------------------------------------------
.globl _fwrite_str
.p2align 2

_fwrite_str:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]

    mov     x19, x0             // string
    mov     x20, x1             // FILE*

    // strlen
    mov     x0, x19
    bl      _strlen_simple
    mov     x2, x0              // len

    // fwrite(str, 1, len, f)
    mov     x0, x19
    mov     x1, #1
    // x2 = len (ya)
    mov     x3, x20
    bl      _fwrite

    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// ----------------------------------------------------------------
// export_html_asm(pixels, w, h, cell_size, path)
// X0=pixels, X1=w, X2=h, X3=cell_size, X4=path
// 100% ASM: sin fprintf, usa fwrite_str + itoa_simple
// ----------------------------------------------------------------
.globl _export_html_asm
.p2align 2

_export_html_asm:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]

    mov     x19, x0             // pixels
    mov     w20, w1             // w
    mov     w21, w2             // h
    mov     w22, w3             // cell_size
    mov     x23, x4             // path

    // fopen(path, "w")
    mov     x0, x23
    adrp    x1, _hw_w_mode@PAGE
    add     x1, x1, _hw_w_mode@PAGEOFF
    bl      _fopen
    mov     x24, x0
    cbz     x24, .Leha_done

    // Pre-convertir cell_size a string (no cambia en el loop)
    sub     sp, sp, #16
    mov     w0, w22
    mov     x1, sp
    bl      _itoa_simple
    // cell_size string en stack, lo copiamos a un sitio seguro
    // Usamos x25 para apuntar al string del cell_size
    mov     x25, sp             // cell_size_str ptr

    // "<table ...>\n"
    adrp    x0, _hw_table_open@PAGE
    add     x0, x0, _hw_table_open@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    mov     w26, #0             // y = 0
.Leha_yloop:
    cmp     w26, w21
    b.ge    .Leha_close

    // "<tr>"
    adrp    x0, _hw_tr_open@PAGE
    add     x0, x0, _hw_tr_open@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    mov     w27, #0             // x = 0
.Leha_xloop:
    cmp     w27, w20
    b.ge    .Leha_xdone

    // idx = (y * w + x) * 3
    mul     w8, w26, w20
    add     w8, w8, w27
    mov     w9, #3
    mul     w8, w8, w9
    sxtw    x8, w8

    // rgb_to_hex(R, G, B, buf)
    ldrb    w0, [x19, x8]
    add     x9, x19, x8
    ldrb    w1, [x9, #1]
    ldrb    w2, [x9, #2]
    sub     sp, sp, #16
    add     x3, sp, #0          // hex buf en stack
    bl      _rgb_to_hex
    // hex string en sp

    // Escribir: <td width="N" height="N" bgcolor="HEX"></td>
    // Pieza por pieza

    // "<td width=\""
    adrp    x0, _hw_td_pre@PAGE
    add     x0, x0, _hw_td_pre@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    // cell_size string
    mov     x0, x25             // cell_size_str (en stack frame anterior)
    mov     x1, x24
    bl      _fwrite_str

    // "\" height=\""
    adrp    x0, _hw_td_mid1@PAGE
    add     x0, x0, _hw_td_mid1@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    // cell_size string
    mov     x0, x25
    mov     x1, x24
    bl      _fwrite_str

    // "\" bgcolor=\""
    adrp    x0, _hw_td_mid2@PAGE
    add     x0, x0, _hw_td_mid2@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    // hex color string (en sp)
    mov     x0, sp
    mov     x1, x24
    bl      _fwrite_str

    // "\"></td>"
    adrp    x0, _hw_td_end@PAGE
    add     x0, x0, _hw_td_end@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    add     sp, sp, #16         // pop hex buf

    add     w27, w27, #1
    b       .Leha_xloop

.Leha_xdone:
    // "</tr>\n"
    adrp    x0, _hw_tr_close@PAGE
    add     x0, x0, _hw_tr_close@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    add     w26, w26, #1
    b       .Leha_yloop

.Leha_close:
    // "</table>\n"
    adrp    x0, _hw_table_close@PAGE
    add     x0, x0, _hw_table_close@PAGEOFF
    mov     x1, x24
    bl      _fwrite_str

    add     sp, sp, #16         // pop cell_size_str

    // fclose
    mov     x0, x24
    bl      _fclose

.Leha_done:
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret
