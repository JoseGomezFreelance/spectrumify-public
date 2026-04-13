   10 REM ================================
   20 REM  SPECTRUMIFY v0.1
   30 REM  (c) 2026 JGF
   40 REM  Sinclair BASIC edition
   50 REM ================================
  100 BORDER 0: PAPER 0: INK 5: BRIGHT 1: CLS
  110 PRINT AT 1,6; INK 5;"SPECTRUMIFY v0.1"
  120 PRINT AT 2,6; INK 5;"================"
  130 PRINT AT 3,7; INK 7; BRIGHT 0;"(c) 2026 JGF"
  140 PRINT AT 6,4; INK 4;"1"; INK 7;" - Ver paleta ZX"
  150 PRINT AT 8,4; INK 4;"2"; INK 7;" - Cargar SCREEN$"
  160 PRINT AT 10,4; INK 4;"3"; INK 7;" - Convertir a B&W"
  170 PRINT AT 12,4; INK 4;"4"; INK 7;" - Convertir a grises"
  180 PRINT AT 14,4; INK 4;"5"; INK 7;" - Guardar SCREEN$"
  190 PRINT AT 16,4; INK 4;"6"; INK 7;" - Dibujar pixel-art"
  200 PRINT AT 20,3; INK 6;"Pulsa 1-6 para elegir"
  210 LET k$=INKEY$
  220 IF k$="" THEN GO TO 210
  230 IF k$="1" THEN GO TO 1000
  240 IF k$="2" THEN GO TO 2000
  250 IF k$="3" THEN GO TO 3000
  260 IF k$="4" THEN GO TO 4000
  270 IF k$="5" THEN GO TO 5000
  280 IF k$="6" THEN GO TO 6000
  290 GO TO 210
 1000 REM ==============================
 1010 REM  OPCION 1: PALETA DE COLORES
 1020 REM ==============================
 1030 BORDER 0: PAPER 0: INK 7: CLS
 1040 PRINT AT 0,8; INK 5; BRIGHT 1;"PALETA ZX SPECTRUM"
 1050 FOR n=0 TO 7
 1060 PRINT AT n+3,2; PAPER n; BRIGHT 0;"        ";
 1070 PRINT INK 7; PAPER 0;" ";n;" Normal"
 1080 PRINT AT n+3,18; PAPER n; BRIGHT 1;"        ";
 1090 PRINT INK 7; PAPER 0;" ";n;" Bright"
 1100 NEXT n
 1110 PRINT AT 14,1; INK 6;"0 Negro    4 Verde"
 1120 PRINT AT 15,1; INK 6;"1 Azul     5 Cyan"
 1130 PRINT AT 16,1; INK 6;"2 Rojo     6 Amarillo"
 1140 PRINT AT 17,1; INK 6;"3 Magenta  7 Blanco"
 1150 PRINT AT 20,4; INK 5;"Pulsa una tecla..."
 1160 PAUSE 0
 1170 GO TO 100
 2000 REM ==============================
 2010 REM  OPCION 2: CARGAR SCREEN$
 2020 REM ==============================
 2030 BORDER 0: PAPER 0: INK 5: CLS
 2040 PRINT AT 10,3; INK 6;"Cargando SCREEN$..."
 2050 PRINT AT 12,3; INK 7;"Pulsa PLAY en el cassette"
 2060 LOAD "" SCREEN$
 2070 PAUSE 0
 2080 GO TO 100
 3000 REM ==============================
 3010 REM  OPCION 3: CONVERTIR A B&W
 3020 REM  Recorre 768 atributos y pone
 3030 REM  cada bloque en blanco o negro
 3040 REM  segun el brillo del color
 3050 REM ==============================
 3060 FOR a=22528 TO 23295
 3070 LET v=PEEK a
 3080 LET i=v-8*INT (v/8)
 3090 LET p=INT (v/8)-8*INT (v/64)
 3100 LET b=INT (v/64)-2*INT (v/128)
 3110 REM Brillo del ink (0=oscuro, 7=claro)
 3120 LET bi=i: IF i=6 THEN LET bi=5
 3130 IF b=1 AND i>0 THEN LET bi=bi+1
 3140 REM Brillo del paper
 3150 LET bp=p: IF p=6 THEN LET bp=5
 3160 IF b=1 AND p>0 THEN LET bp=bp+1
 3170 REM Nuevo atributo B&W con BRIGHT
 3180 LET ni=0: IF bi>3 THEN LET ni=7
 3190 LET np=0: IF bp>3 THEN LET np=7
 3200 POKE a,ni+np*8+64
 3210 NEXT a
 3220 PAUSE 0
 3230 GO TO 100
 4000 REM ==============================
 4010 REM  OPCION 4: CONVERTIR A GRISES
 4020 REM  4 tonos: negro, gris oscuro,
 4030 REM  gris claro, blanco
 4040 REM  (usando INK 0/7 + BRIGHT 0/1)
 4050 REM ==============================
 4060 REM Tabla de brillo por color 0-7
 4070 DIM l(8)
 4080 LET l(1)=0: LET l(2)=1: LET l(3)=2
 4090 LET l(4)=3: LET l(5)=3: LET l(6)=4
 4100 LET l(7)=5: LET l(8)=6
 4110 FOR a=22528 TO 23295
 4120 LET v=PEEK a
 4130 LET i=v-8*INT (v/8)
 4140 LET p=INT (v/8)-8*INT (v/64)
 4150 LET b=INT (v/64)-2*INT (v/128)
 4160 REM Brillo del ink
 4170 LET bi=l(i+1)
 4180 IF b=1 AND i>0 THEN LET bi=bi+1
 4190 REM Brillo del paper
 4200 LET bp=l(p+1)
 4210 IF b=1 AND p>0 THEN LET bp=bp+1
 4220 REM Mapear a 4 grises
 4230 REM 0-1=negro 2-3=gris osc 4-5=gris cla 6-7=blanco
 4240 LET ni=0: LET gi=0
 4250 IF bi>=2 AND bi<=3 THEN LET ni=0: LET gi=1
 4260 IF bi>=4 AND bi<=5 THEN LET ni=7: LET gi=0
 4270 IF bi>=6 THEN LET ni=7: LET gi=1
 4280 LET np=0: LET gp=0
 4290 IF bp>=2 AND bp<=3 THEN LET np=0: LET gp=1
 4300 IF bp>=4 AND bp<=5 THEN LET np=7: LET gp=0
 4310 IF bp>=6 THEN LET np=7: LET gp=1
 4320 REM BRIGHT compartido: mayoria gana
 4330 LET nb=gi: IF gp>gi THEN LET nb=gp
 4340 POKE a,ni+np*8+nb*64
 4350 NEXT a
 4360 PAUSE 0
 4370 GO TO 100
 5000 REM ==============================
 5010 REM  OPCION 5: GUARDAR SCREEN$
 5020 REM ==============================
 5030 SAVE "spectrumify" SCREEN$
 5040 PRINT AT 21,5; INK 6;"Guardado!"
 5050 PAUSE 100
 5060 GO TO 100
 6000 REM ==============================
 6010 REM  OPCION 6: DIBUJAR PIXEL-ART
 6020 REM ==============================
 6030 BORDER 0: PAPER 0: INK 7: CLS
 6040 LET px=128: LET py=96
 6050 LET c=7: LET b=1
 6060 PRINT AT 0,0; INK 6; PAPER 0;"WASD=mover SPACE=pintar C=color Q=menu"
 6070 INK c: BRIGHT b: PLOT px,py
 6080 LET k$=INKEY$
 6090 IF k$="" THEN GO TO 6080
 6100 IF k$="w" AND py<175 THEN LET py=py+1
 6110 IF k$="s" AND py>0 THEN LET py=py-1
 6120 IF k$="a" AND px>0 THEN LET px=px-1
 6130 IF k$="d" AND px<255 THEN LET px=px+1
 6140 IF k$=" " THEN PLOT INK c; BRIGHT b;px,py
 6150 IF k$="c" THEN LET c=c+1: IF c>7 THEN LET c=0
 6160 IF k$="b" THEN LET b=1-b
 6170 IF k$="q" THEN GO TO 100
 6180 GO TO 6070
