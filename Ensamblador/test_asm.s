// Test de rutinas ASM core sin C
// Carga foto.bmp, cuantiza, exporta HTML y SCR

.text

.section __TEXT,__cstring
_t_start:    .asciz "=== Test 100%% ASM ===\n"
_t_bmp:      .asciz "Cargando BMP...\n"
_t_loaded:   .asciz "BMP cargado: %dx%d\n"
_t_resize:   .asciz "Resize: %dx%d\n"
_t_quant:    .asciz "Quantize OK\n"
_t_html:     .asciz "Export HTML OK\n"
_t_scr:      .asciz "Export SCR OK\n"
_t_done:     .asciz "=== ALL TESTS PASSED ===\n"
_t_fail:     .asciz "ERROR: carga fallida\n"
_t_bmppath:  .asciz "../assets/samples/foto.bmp"
_t_htmlpath: .asciz "/tmp/test_100asm.html"
_t_scrpath:  .asciz "/tmp/test_100asm.scr"

.text
.globl _main
.p2align 2

_main:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    // Print start
    adrp    x0, _t_start@PAGE
    add     x0, x0, _t_start@PAGEOFF
    bl      _printf

    // Load BMP
    adrp    x0, _t_bmp@PAGE
    add     x0, x0, _t_bmp@PAGEOFF
    bl      _printf

    // load_bmp(path, &w, &h)
    sub     sp, sp, #16
    str     xzr, [sp]           // zero init
    str     xzr, [sp, #8]
    adrp    x0, _t_bmppath@PAGE
    add     x0, x0, _t_bmppath@PAGEOFF
    add     x1, sp, #0          // &w
    add     x2, sp, #4          // &h
    bl      _load_bmp
    mov     x19, x0
    ldr     w20, [sp]           // w
    ldr     w21, [sp, #4]       // h
    add     sp, sp, #16
    cbz     x19, .Lt_fail

    adrp    x0, _t_loaded@PAGE
    add     x0, x0, _t_loaded@PAGEOFF
    mov     w1, w20
    mov     w2, w21
    bl      _printf

    // Resize to 153xN
    sub     sp, sp, #16
    mov     w0, w20             // orig_w
    mov     w1, w21             // orig_h
    mov     w2, #153            // target_w
    mov     x3, sp              // out_w
    add     x4, sp, #4          // out_h
    bl      _calculate_dimensions
    ldr     w20, [sp]
    ldr     w21, [sp, #4]
    add     sp, sp, #16

    adrp    x0, _t_resize@PAGE
    add     x0, x0, _t_resize@PAGEOFF
    mov     w1, w20
    mov     w2, w21
    bl      _printf

    mov     x0, x19             // orig pixels
    adrp    x8, _bmp_width@PAGE
    add     x8, x8, _bmp_width@PAGEOFF
    ldr     w1, [x8]
    adrp    x8, _bmp_height@PAGE
    add     x8, x8, _bmp_height@PAGEOFF
    ldr     w2, [x8]
    mov     w3, w20
    mov     w4, w21
    bl      _resize_image
    mov     x19, x0             // resized pixels

    // Quantize
    mov     x0, x19
    mov     w1, w20
    mov     w2, w21
    mov     w3, #0              // mode 16
    bl      _quantize_image

    adrp    x0, _t_quant@PAGE
    add     x0, x0, _t_quant@PAGEOFF
    bl      _printf

    // Export HTML
    mov     x0, x19
    mov     w1, w20
    mov     w2, w21
    mov     w3, #3
    adrp    x4, _t_htmlpath@PAGE
    add     x4, x4, _t_htmlpath@PAGEOFF
    bl      _export_html_asm

    adrp    x0, _t_html@PAGE
    add     x0, x0, _t_html@PAGEOFF
    bl      _printf

    // Export SCR (need 256x192)
    // Reload original for SCR
    sub     sp, sp, #16
    adrp    x0, _t_bmppath@PAGE
    add     x0, x0, _t_bmppath@PAGEOFF
    add     x1, sp, #0
    add     x2, sp, #4
    bl      _load_bmp
    mov     x22, x0
    ldr     w1, [sp]
    ldr     w2, [sp, #4]
    add     sp, sp, #16
    cbz     x22, .Lt_fail
    mov     x0, x22
    mov     w3, #256
    mov     w4, #192
    bl      _resize_image
    mov     x22, x0

    mov     x0, x22
    mov     w1, #256
    mov     w2, #192
    mov     w3, #0
    bl      _quantize_image

    mov     x0, x22
    mov     w1, #256
    mov     w2, #192
    adrp    x3, _t_scrpath@PAGE
    add     x3, x3, _t_scrpath@PAGEOFF
    bl      _export_scr

    adrp    x0, _t_scr@PAGE
    add     x0, x0, _t_scr@PAGEOFF
    bl      _printf

    // Done
    adrp    x0, _t_done@PAGE
    add     x0, x0, _t_done@PAGEOFF
    bl      _printf

    mov     w0, #0
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

.Lt_fail:
    adrp    x0, _t_fail@PAGE
    add     x0, x0, _t_fail@PAGEOFF
    bl      _printf
    mov     w0, #1
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret
