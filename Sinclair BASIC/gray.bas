   10 REM ================================
   20 REM  SPECTRUMIFY - MODO GRISES
   30 REM  Convierte la pantalla actual
   40 REM  a 4 tonos de gris del Spectrum
   50 REM ================================
   60 REM
   70 REM Los 4 grises del ZX Spectrum:
   80 REM   Negro       = INK 0, BRIGHT 0
   90 REM   Gris oscuro = INK 0, BRIGHT 1
  100 REM   Gris claro  = INK 7, BRIGHT 0
  110 REM   Blanco      = INK 7, BRIGHT 1
  120 REM
  130 REM Tabla de brillo por color (0-7):
  140 REM   0=0  1=1  2=2  3=3
  150 REM   4=3  5=4  6=5  7=6
  160 REM
  170 REM Preparar tabla ANTES del bucle
  180 DIM l(8)
  190 LET l(1)=0: LET l(2)=1: LET l(3)=2
  200 LET l(4)=3: LET l(5)=3: LET l(6)=4
  210 LET l(7)=5: LET l(8)=6
  220 REM Recorrer los 768 atributos
  230 FOR a=22528 TO 23295
  240 LET v=PEEK a
  250 LET i=v-8*INT (v/8)
  260 LET p=INT (v/8)-8*INT (v/64)
  270 LET b=INT (v/64)-2*INT (v/128)
  280 REM Brillo del ink
  290 LET bi=l(i+1)
  300 IF b=1 AND i>0 THEN LET bi=bi+1
  310 REM Brillo del paper
  320 LET bp=l(p+1)
  330 IF b=1 AND p>0 THEN LET bp=bp+1
  340 REM Mapear a 4 grises
  350 REM 0-1=negro 2-3=gris osc 4-5=gris cla 6+=blanco
  360 LET ni=0: LET gi=0
  370 IF bi>=2 AND bi<=3 THEN LET ni=0: LET gi=1
  380 IF bi>=4 AND bi<=5 THEN LET ni=7: LET gi=0
  390 IF bi>=6 THEN LET ni=7: LET gi=1
  400 LET np=0: LET gp=0
  410 IF bp>=2 AND bp<=3 THEN LET np=0: LET gp=1
  420 IF bp>=4 AND bp<=5 THEN LET np=7: LET gp=0
  430 IF bp>=6 THEN LET np=7: LET gp=1
  440 REM BRIGHT compartido: mayoria gana
  450 LET nb=gi: IF gp>gi THEN LET nb=gp
  460 POKE a,ni+np*8+nb*64
  470 NEXT a
