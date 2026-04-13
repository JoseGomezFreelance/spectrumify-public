; ========================================
; SPECTRUMIFY - Convertir pantalla a
;               4 grises del Spectrum
; ZX Spectrum - Ensamblador Z80
; (c) 2026 JGF
; ========================================
;
; Los 4 grises nativos del Spectrum:
;   Negro       = INK 0, BRIGHT 0
;   Gris oscuro = INK 0, BRIGHT 1
;   Gris claro  = INK 7, BRIGHT 0
;   Blanco      = INK 7, BRIGHT 1
;
; Uso desde BASIC:
;   RANDOMIZE USR 32768
;
; Ensamblar con pasmo:
;   pasmo --tapbas gray.asm gray.tap
;

ATTRS   equ 22528
NATTRS  equ 768

        org 32768

; Tabla de brillo por color (0-7)
bright_table:
        db 0, 1, 2, 3, 3, 4, 5, 6

; Tabla de mapeo brillo (0-7) -> gris
; Cada gris codificado como: bits 0-2 = color (0 o 7)
;                             bit 3   = bright (0 o 1)
; Brillo 0-1 = negro (0,0)
; Brillo 2-3 = gris oscuro (0,1)
; Brillo 4-5 = gris claro (7,0)
; Brillo 6-7 = blanco (7,1)
gray_table:
        db 0              ; brillo 0 -> ink 0, bright 0
        db 0              ; brillo 1 -> ink 0, bright 0
        db 8              ; brillo 2 -> ink 0, bright 1
        db 8              ; brillo 3 -> ink 0, bright 1
        db 7              ; brillo 4 -> ink 7, bright 0
        db 7              ; brillo 5 -> ink 7, bright 0
        db 15             ; brillo 6 -> ink 7, bright 1
        db 15             ; brillo 7 -> ink 7, bright 1

start:
        ld hl, ATTRS
        ld bc, NATTRS

.loop:
        ld a, (hl)
        push hl
        push bc

        ; --- Calcular brillo del ink ---
        ld c, a            ; guardar atributo en C
        and 00000111b      ; ink
        ld e, a
        ld d, 0
        ld hl, bright_table
        add hl, de
        ld a, (hl)         ; brillo base del ink
        ; Si BRIGHT y no negro, +1
        bit 6, c
        jr z, .no_bi
        ld a, e
        or a
        jr z, .no_bi
        ld hl, bright_table
        add hl, de
        ld a, (hl)
        inc a
.no_bi:
        ; A = brillo ink (0-7), buscar gris
        ld e, a
        ld d, 0
        ld hl, gray_table
        add hl, de
        ld b, (hl)         ; B = gris del ink (color+bright)

        ; --- Calcular brillo del paper ---
        ld a, c            ; recuperar atributo
        rrca
        rrca
        rrca
        and 00000111b      ; paper
        ld e, a
        ld d, 0
        ld hl, bright_table
        add hl, de
        ld a, (hl)
        ; Si BRIGHT y no negro, +1
        bit 6, c
        jr z, .no_bp
        ld a, e
        or a
        jr z, .no_bp
        ld hl, bright_table
        add hl, de
        ld a, (hl)
        inc a
.no_bp:
        ; A = brillo paper (0-7), buscar gris
        ld e, a
        ld d, 0
        ld hl, gray_table
        add hl, de
        ld a, (hl)         ; A = gris del paper

        ; --- Construir atributo ---
        ; B tiene ink (bits 0-2) + bright ink (bit 3)
        ; A tiene paper (bits 0-2) + bright paper (bit 3)
        ;
        ; BRIGHT es compartido por bloque:
        ; elegimos el del ink (podria ser mayoria)
        ld e, b
        ld d, a
        ; nuevo ink = E AND 7
        ld a, e
        and 00000111b
        ld e, a            ; E = nuevo ink (0 o 7)
        ; nuevo paper = D AND 7
        ld a, d
        and 00000111b
        rlca
        rlca
        rlca               ; paper a bits 3-5
        or e               ; + ink
        ; bright del ink
        bit 3, b
        jr z, .no_final_bright
        or 01000000b       ; set BRIGHT
.no_final_bright:

        pop bc
        pop hl
        ld (hl), a         ; escribir atributo
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, .loop

        ret
