   10 REM ================================
   20 REM  SPECTRUMIFY - SINCLAIR BASIC
   30 REM ================================
   40 REM
   50 REM Estos programas son el equivalente
   60 REM de Spectrumify para un ZX Spectrum
   70 REM real con 48K de RAM.
   80 REM
   90 REM En un Spectrum real no necesitas
  100 REM "convertir" a la paleta ZX porque
  110 REM YA ESTAS en el hardware. Lo que
  120 REM haces es manipular la pantalla
  130 REM directamente via PEEK y POKE.
  140 REM
  150 REM ARCHIVOS:
  160 REM
  170 REM main.bas    - Menu principal
  180 REM              (paleta, cargar, B&W,
  190 REM              grises, guardar, dibujar)
  200 REM
  210 REM gray.bas    - Conversor a 4 grises
  220 REM              Manipula los 768 bytes
  230 REM              de atributos (22528-23295)
  240 REM
  250 REM viewer.bas  - Visor de SCREEN$
  260 REM              con colores secretos
  270 REM              magenta/verde/rojo
  280 REM
  290 REM COMO FUNCIONA:
  300 REM
  310 REM La pantalla del Spectrum ocupa
  320 REM 6912 bytes de RAM:
  330 REM - 6144 bytes de bitmap (16384-22527)
  340 REM - 768 bytes de atributos (22528-23295)
  350 REM
  360 REM Cada atributo controla un bloque
  370 REM de 8x8 pixeles:
  380 REM - Bits 0-2: color INK (0-7)
  390 REM - Bits 3-5: color PAPER (0-7)
  400 REM - Bit 6:    BRIGHT (0 o 1)
  410 REM - Bit 7:    FLASH (0 o 1)
  420 REM
  430 REM Para "convertir" a B&W o grises,
  440 REM basta con POKE-ar nuevos valores
  450 REM en los atributos. El bitmap
  460 REM (los pixeles) no cambia.
  470 REM
  480 REM Eso es lo bonito del Spectrum:
  490 REM el color esta SEPARADO de la forma.
