   10 REM ================================
   20 REM  SPECTRUMIFY - SCR VIEWER
   30 REM  Visor de archivos SCREEN$
   40 REM  con colores secretos
   50 REM ================================
  100 BORDER 0: PAPER 0: INK 3: BRIGHT 1: CLS
  110 PRINT AT 3,9; INK 2; BRIGHT 1;"SCR VIEWER"
  120 PRINT AT 5,7; INK 3; BRIGHT 0;"ZX Spectrum 48K"
  130 PRINT AT 9,3; INK 4; BRIGHT 1;"L";
  140 PRINT INK 4; BRIGHT 0;" - Cargar SCREEN$"
  150 PRINT AT 11,3; INK 4; BRIGHT 1;"S";
  160 PRINT INK 4; BRIGHT 0;" - Guardar SCREEN$"
  170 PRINT AT 13,3; INK 4; BRIGHT 1;"B";
  180 PRINT INK 4; BRIGHT 0;" - Convertir a B&W"
  190 PRINT AT 15,3; INK 4; BRIGHT 1;"G";
  200 PRINT INK 4; BRIGHT 0;" - Convertir a grises"
  210 PRINT AT 17,3; INK 4; BRIGHT 1;"I";
  220 PRINT INK 4; BRIGHT 0;" - Info de pantalla"
  230 PRINT AT 21,4; INK 3; BRIGHT 1;"Pulsa una opcion..."
  240 LET k$=INKEY$
  250 IF k$="" THEN GO TO 240
  260 IF k$="l" THEN GO TO 1000
  270 IF k$="s" THEN GO TO 2000
  280 IF k$="b" THEN GO TO 3000
  290 IF k$="g" THEN GO TO 4000
  300 IF k$="i" THEN GO TO 5000
  310 GO TO 240
 1000 REM ==============================
 1010 REM  CARGAR SCREEN$
 1020 REM ==============================
 1030 BORDER 3: CLS
 1040 PRINT AT 10,3; INK 3;"PLAY en el cassette..."
 1050 LOAD "" SCREEN$
 1060 BORDER 0
 1070 PAUSE 0
 1080 GO TO 100
 2000 REM ==============================
 2010 REM  GUARDAR SCREEN$
 2020 REM ==============================
 2030 SAVE "spectrumify" SCREEN$
 2040 PRINT AT 21,5; INK 6;"Guardado!"
 2050 PAUSE 100
 2060 GO TO 100
 3000 REM ==============================
 3010 REM  CONVERTIR A B&W
 3020 REM ==============================
 3030 FOR a=22528 TO 23295
 3040 LET v=PEEK a
 3050 LET i=v-8*INT (v/8)
 3060 LET p=INT (v/8)-8*INT (v/64)
 3070 LET b=INT (v/64)-2*INT (v/128)
 3080 LET bi=i: IF i=6 THEN LET bi=5
 3090 IF b=1 AND i>0 THEN LET bi=bi+1
 3100 LET bp=p: IF p=6 THEN LET bp=5
 3110 IF b=1 AND p>0 THEN LET bp=bp+1
 3120 LET ni=0: IF bi>3 THEN LET ni=7
 3130 LET np=0: IF bp>3 THEN LET np=7
 3140 POKE a,ni+np*8+64
 3150 NEXT a
 3160 PAUSE 0
 3170 GO TO 100
 4000 REM ==============================
 4010 REM  CONVERTIR A GRISES
 4020 REM ==============================
 4030 DIM l(8)
 4040 LET l(1)=0: LET l(2)=1: LET l(3)=2
 4050 LET l(4)=3: LET l(5)=3: LET l(6)=4
 4060 LET l(7)=5: LET l(8)=6
 4070 FOR a=22528 TO 23295
 4080 LET v=PEEK a
 4090 LET i=v-8*INT (v/8)
 4100 LET p=INT (v/8)-8*INT (v/64)
 4110 LET b=INT (v/64)-2*INT (v/128)
 4120 LET bi=l(i+1)
 4130 IF b=1 AND i>0 THEN LET bi=bi+1
 4140 LET bp=l(p+1)
 4150 IF b=1 AND p>0 THEN LET bp=bp+1
 4160 LET ni=0: LET gi=0
 4170 IF bi>=2 AND bi<=3 THEN LET ni=0: LET gi=1
 4180 IF bi>=4 AND bi<=5 THEN LET ni=7: LET gi=0
 4190 IF bi>=6 THEN LET ni=7: LET gi=1
 4200 LET np=0: LET gp=0
 4210 IF bp>=2 AND bp<=3 THEN LET np=0: LET gp=1
 4220 IF bp>=4 AND bp<=5 THEN LET np=7: LET gp=0
 4230 IF bp>=6 THEN LET np=7: LET gp=1
 4240 LET nb=gi: IF gp>gi THEN LET nb=gp
 4250 POKE a,ni+np*8+nb*64
 4260 NEXT a
 4270 PAUSE 0
 4280 GO TO 100
 5000 REM ==============================
 5010 REM  INFO DE PANTALLA
 5020 REM  Cuenta colores ink unicos
 5030 REM ==============================
 5040 DIM u(16)
 5050 LET t=0
 5060 FOR a=22528 TO 23295
 5070 LET v=PEEK a
 5080 LET i=v-8*INT (v/8)
 5090 LET b=INT (v/64)-2*INT (v/128)
 5100 LET x=i+1+b*8
 5110 IF u(x)=0 THEN LET t=t+1
 5120 LET u(x)=u(x)+1
 5130 NEXT a
 5140 PRINT AT 21,0; INK 6;"Colores ink: ";t;"  (768 bloques)"
 5150 PAUSE 0
 5160 GO TO 100
