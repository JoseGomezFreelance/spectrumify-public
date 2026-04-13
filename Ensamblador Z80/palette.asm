; ========================================
; SPECTRUMIFY - Mostrar paleta ZX
; ZX Spectrum - Ensamblador Z80
; (c) 2026 JGF
; ========================================
;
; Muestra los 16 colores del Spectrum
; pintando bloques en pantalla.
;
; Uso desde BASIC:
;   RANDOMIZE USR 32768
;
; Ensamblar con pasmo:
;   pasmo --tapbas palette.asm palette.tap
;

ATTRS   equ 22528
CLS     equ 0x0D6B        ; ROM: borrar pantalla

        org 32768

start:
        ; Borrar pantalla: PAPER 0, INK 7
        ld a, 00111000b    ; paper=7, ink=0... no,
        xor a              ; A=0 (PAPER 0, INK 0)
        ld (23693), a      ; ATTR_P (atributo permanente)
        call CLS

        ; --- Fila superior: 8 colores normales ---
        ; Poner atributos en fila 4 (bloques 4*32+2 a 4*32+17)
        ; 2 columnas por color, 8 colores = 16 columnas
        ld hl, ATTRS + 4*32 + 2    ; fila 4, col 2
        ld b, 8            ; 8 colores
        xor a              ; color = 0
.norm_loop:
        ld c, a            ; guardar color
        ; Atributo: PAPER=color, INK=color, BRIGHT=0
        rlca
        rlca
        rlca               ; color a bits 3-5 (paper)
        or c               ; + ink
        ld (hl), a
        inc hl
        ld (hl), a         ; 2 columnas por color
        inc hl
        ld a, c
        inc a
        ld b, a
        cp 8
        ld a, b
        ld b, 8            ; restaurar contador (truco)
        jr nz, .norm_loop

        ; --- Fila inferior: 8 colores BRIGHT ---
        ld hl, ATTRS + 8*32 + 2
        xor a
.bright_loop:
        ld c, a
        rlca
        rlca
        rlca
        or c
        or 01000000b       ; BRIGHT
        ld (hl), a
        inc hl
        ld (hl), a
        inc hl
        ld a, c
        inc a
        cp 8
        jr nz, .bright_loop

        ; --- Etiquetas con ROM PRINT ---
        ; Imprimir "NORMAL" y "BRIGHT" usando
        ; la rutina RST 16 (PRINT char en A)
        ;
        ; Posicionar cursor: AT fila,col
        ; Control: 22, fila, col
        ld a, 22           ; AT
        rst 16
        ld a, 2            ; fila 2
        rst 16
        ld a, 8            ; col 8
        rst 16
        ld hl, txt_normal
        call print_str

        ld a, 22
        rst 16
        ld a, 6
        rst 16
        ld a, 8
        rst 16
        ld hl, txt_bright
        call print_str

        ; Titulo
        ld a, 22
        rst 16
        ld a, 0
        rst 16
        ld a, 6
        rst 16

        ; INK 5 (cyan)
        ld a, 16           ; control INK
        rst 16
        ld a, 5
        rst 16

        ld hl, txt_title
        call print_str

        ret

; --- Subrutina: imprimir cadena ---
; HL apunta a cadena terminada en 0
print_str:
        ld a, (hl)
        or a
        ret z
        rst 16
        inc hl
        jr print_str

txt_title:
        db "PALETA ZX SPECTRUM", 0
txt_normal:
        db "NORMAL", 0
txt_bright:
        db "BRIGHT", 0
