; ========================================
; SPECTRUMIFY - Convertir pantalla a B&W
; ZX Spectrum - Ensamblador Z80
; (c) 2026 JGF
; ========================================
;
; Convierte los atributos de la pantalla
; actual a blanco y negro. Instantaneo
; (vs segundos en BASIC).
;
; Uso desde BASIC:
;   RANDOMIZE USR 32768
;
; Ensamblar con pasmo:
;   pasmo --tapbas bw.asm bw.tap
;

ATTRS   equ 22528       ; inicio de atributos
NATTRS  equ 768         ; 32 x 24 bloques

        org 32768

; ---------------------------------------
; Tabla de brillo por color (0-7)
; Negro=0, Azul=1, Rojo=2, Magenta=3,
; Verde=3, Cyan=4, Amarillo=5, Blanco=6
; ---------------------------------------
bright_table:
        db 0, 1, 2, 3, 3, 4, 5, 6

start:
        ld hl, ATTRS
        ld bc, NATTRS

.loop:
        ld a, (hl)       ; leer atributo

        ; --- Extraer ink (bits 0-2) ---
        push af
        and 00000111b
        ld e, a           ; E = ink color (0-7)

        ; Buscar brillo del ink en tabla
        push hl
        ld hl, bright_table
        ld d, 0
        add hl, de
        ld a, (hl)        ; A = brillo base del ink
        pop hl

        ; Si BRIGHT estaba activo y no es negro, +1
        pop af
        push af
        bit 6, a           ; bit BRIGHT
        jr z, .no_bright_ink
        ld a, e            ; recuperar color ink
        or a               ; es negro?
        jr z, .no_bright_ink
        ; Recalcular con +1
        push hl
        ld hl, bright_table
        ld d, 0
        add hl, de
        ld a, (hl)
        pop hl
        inc a              ; bright: +1
.no_bright_ink:
        ; A = brillo final del ink
        cp 4               ; > 3 = blanco
        ld e, 0             ; E = nuevo ink (negro)
        jr c, .ink_done
        ld e, 7             ; E = nuevo ink (blanco)
.ink_done:

        ; --- Extraer paper (bits 3-5) ---
        pop af
        push af
        rrca
        rrca
        rrca
        and 00000111b
        ld d, a            ; D = paper color (0-7)

        ; Buscar brillo del paper en tabla
        push hl
        ld hl, bright_table
        push de
        ld a, d
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)         ; A = brillo base del paper
        pop de
        pop hl

        ; Si BRIGHT y no es negro, +1
        pop af
        bit 6, a
        jr z, .no_bright_paper
        ld a, d
        or a
        jr z, .no_bright_paper
        push hl
        ld hl, bright_table
        push de
        ld a, d
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)
        pop de
        pop hl
        inc a
.no_bright_paper:
        ; A = brillo final del paper
        cp 4
        ld d, 0            ; D = nuevo paper (negro)
        jr c, .paper_done
        ld d, 7            ; D = nuevo paper (blanco)
.paper_done:

        ; --- Construir nuevo atributo ---
        ; ink=E, paper=D, BRIGHT=1 (bit 6)
        ld a, d
        rlca
        rlca
        rlca               ; paper a bits 3-5
        or e               ; sumar ink en bits 0-2
        or 01000000b        ; BRIGHT siempre activo
        ld (hl), a          ; escribir atributo

        inc hl
        dec bc
        ld a, b
        or c
        jr nz, .loop

        ret
