# Comparativa de lenguajes para Spectrumify

Analisis teorico y especulativo de como seria reimplementar Spectrumify
en cuatro lenguajes alternativos, comparados con la implementacion actual
en Python. Las estimaciones numericas son aproximaciones basadas en las
caracteristicas conocidas de cada lenguaje y su ecosistema.

---

## 1. Python (implementacion actual)

### Descripcion

Spectrumify esta escrito en Python 3.10 con pygame (GUI) y Pillow (imagen).
Es un lenguaje interpretado con tipado dinamico, garbage collector, y un
ecosistema enorme de bibliotecas.

### Caracteristicas actuales

- **Lineas de codigo**: ~600 (src/) + ~500 (scripts/)
- **Dependencias**: pygame 2.6 (~12 MB), Pillow 12.x (~5 MB), Python 3.10 (~30 MB)
- **Tamano total instalado**: ~50 MB (venv completo)
- **RAM en ejecucion**: ~50-80 MB (Python + pygame + imagen cargada)
- **Tiempo de conversion** (foto 1016 KB, 153x102 celdas): ~0.5 segundos
- **Tiempo de compresion HTML**: ~0.1 segundos

### Fortalezas

- Desarrollo rapido: las bibliotecas hacen el trabajo pesado
- Codigo legible: cualquier programador lo entiende
- Cross-platform sin esfuerzo adicional
- Prototipado instantaneo: cambiar algo y probar es inmediato

### Debilidades

- Tamano del entorno: 50 MB para una app de conversion de imagenes
- Velocidad: el bucle de cuantizacion pixel a pixel es puro Python (lento)
- Distribucion: el usuario necesita Python + pip + venv
- GIL: no se puede paralelizar la cuantizacion en multiples nucleos

---

## 2. C + SDL2

### Descripcion

C (1972) con SDL2 para GUI y stb_image/stb_image_write para carga/guardado
de imagenes. Todo compilado a codigo maquina nativo. Sin runtime, sin
garbage collector, sin interprete.

### Como seria la implementacion

```
spectrumify.c          // main + loop SDL2 (~300 lineas)
converter.c            // cuantizacion + nearest_color (~150 lineas)
compressor.c           // RLE + compresion HTML (~200 lineas)
exporter.c             // generacion HTML/GIF/SCR (~150 lineas)
palette.h              // 16 colores como constantes
stb_image.h            // header-only, 0 dependencias externas
stb_image_write.h      // idem
```

La cuantizacion de nearest_color seria un bucle tight con aritmetica de
enteros, probablemente auto-vectorizado por el compilador con -O2.

SDL2 proporciona ventana, eventos, y renderizado — lo mismo que pygame
pero sin la capa de Python por encima.

### Estimaciones

- **Lineas de codigo**: ~800-1000 (mas que Python por gestion manual de memoria)
- **Tamano del binario**: 200-500 KB (con SDL2 linkeado estaticamente: ~2 MB)
- **Dependencias en runtime**: ninguna (todo estatico) o SDL2.dylib (~2 MB)
- **RAM en ejecucion**: 5-10 MB (imagen + framebuffer SDL2)
- **Tiempo de conversion**: ~5-10 ms (50-100x mas rapido que Python)
- **Tiempo de compresion HTML**: ~2-5 ms
- **Distribucion**: un unico binario ejecutable

### Fortalezas

- Tamano minimo: 200 KB vs 50 MB de Python
- Velocidad maxima: acceso directo a memoria, sin overhead de interprete
- Control total: cada byte de RAM esta bajo tu control
- Distribucion trivial: un archivo ejecutable y listo
- stb_image es header-only: copias un .h y ya tienes soporte PNG/JPEG/GIF

### Debilidades

- Gestion manual de memoria: malloc/free, riesgo de leaks y buffer overflows
- Desarrollo lento: lo que en Python es una linea, en C son 10-15
- Strings: manipular HTML en C es tedioso (sprintf, strcat, realloc)
- Sin regex: la compresion HTML habria que reescribirla con parser manual
- Errores silenciosos: un puntero mal y el programa crashea sin explicacion

### Ejemplo: nearest_color en C

```c
typedef struct { uint8_t r, g, b; } Color;

static const Color PALETTE[16] = {
    {0,0,0}, {0,0,170}, {170,0,0}, /* ... */
};

Color nearest_color(uint8_t r, uint8_t g, uint8_t b) {
    int best = 0, best_dist = INT_MAX;
    for (int i = 0; i < 16; i++) {
        int dr = r - PALETTE[i].r;
        int dg = g - PALETTE[i].g;
        int db = b - PALETTE[i].b;
        int d = dr*dr + dg*dg + db*db;
        if (d < best_dist) { best_dist = d; best = i; }
    }
    return PALETTE[best];
}
```

Esto compilado con -O2 ejecuta en nanosegundos por pixel. El compilador
probablemente desenrolla el bucle y usa registros SIMD automaticamente
en ARM (Apple Silicon).

---

## 3. Pascal (Free Pascal + Lazarus)

### Descripcion

Free Pascal (FPC) es un compilador Pascal open source que genera binarios
nativos para macOS, Windows y Linux. Lazarus es su IDE con diseñador de
formularios visual, comparable a Delphi.

Pascal (1970) fue diseñado por Niklaus Wirth para enseñar programacion
estructurada. Free Pascal lo extiende con orientacion a objetos (Object
Pascal), similar a lo que Delphi popularizo en los 90.

### Como seria la implementacion

```
spectrumify.lpr        // proyecto Lazarus
mainform.pas           // formulario principal con TImage, TPanel
converter.pas          // cuantizacion con TBitmap
compressor.pas         // compresion HTML con strings Pascal
exporter.pas           // generacion de archivos
palette.pas            // constantes de paleta
```

Lazarus tiene componentes nativos: TImage para mostrar imagenes,
TFileDialog para abrir/guardar, TPanel para layout. La GUI seria
nativa del OS (Cocoa en Mac, GTK en Linux, Win32 en Windows) en vez
de una ventana SDL.

### Estimaciones

- **Lineas de codigo**: ~700-900 (similar a Python, Pascal es verboso pero estructurado)
- **Tamano del binario**: 3-5 MB (Lazarus incluye la LCL, mas pesada que SDL)
- **Dependencias en runtime**: ninguna (todo estatico en el binario)
- **RAM en ejecucion**: 10-15 MB
- **Tiempo de conversion**: ~10-20 ms (compilado nativo, pero sin auto-vectorizacion tan agresiva como C/clang)
- **Tiempo de compresion HTML**: ~5-10 ms
- **Distribucion**: un binario + posiblemente frameworks del OS

### Fortalezas

- GUI nativa del OS: menus, dialogos, look & feel nativo sin SDL
- Compilacion rapida: FPC compila mas rapido que gcc/clang
- Strings nativas: Pascal maneja strings mucho mejor que C
- Lazarus IDE: diseñador visual de formularios, depurador integrado
- Nostalgia util: Turbo Pascal y Delphi formaron a generaciones de programadores
- Seguridad: range checking, strong typing, sin punteros colgantes (en modo seguro)

### Debilidades

- Comunidad pequeña: menos bibliotecas que Python/C/Rust
- Carga de imagenes: hay unidades (fpimage, BGRABitmap) pero menos maduras que Pillow o stb
- Verbosidad: `begin...end` en vez de llaves, `procedure` en vez de `def`
- Ecosistema retro: la documentacion y los tutoriales suelen ser de otra epoca
- macOS: Lazarus funciona pero la integracion con Cocoa no es perfecta

### Ejemplo: nearest_color en Pascal

```pascal
type
  TColor = record R, G, B: Byte; end;

const
  Palette: array[0..15] of TColor = (
    (R:0; G:0; B:0), (R:0; G:0; B:170), { ... }
  );

function NearestColor(R, G, B: Byte): TColor;
var
  I, Best, Dist, BestDist: Integer;
begin
  BestDist := MaxInt;
  Best := 0;
  for I := 0 to 15 do begin
    Dist := Sqr(R - Palette[I].R) +
            Sqr(G - Palette[I].G) +
            Sqr(B - Palette[I].B);
    if Dist < BestDist then begin
      BestDist := Dist;
      Best := I;
    end;
  end;
  Result := Palette[Best];
end;
```

Legible, seguro, casi tan rapido como C. El compilador genera buen
codigo nativo aunque no tan agresivamente optimizado como clang.

---

## 4. Ensamblador x86-64 (macOS, Apple Silicon via Rosetta o nativo ARM64)

### Descripcion

Programar directamente en ensamblador del procesador moderno. En el caso
de un Mac con Apple Silicon, seria ensamblador ARM64 (AArch64). En un Mac
Intel, seria x86-64.

### Como seria la implementacion

No seria una app completa con GUI. Seria inviable. Lo realista seria:

1. Rutinas criticas en ensamblador (nearest_color, cuantizacion)
2. Llamadas desde C o Python via FFI
3. La GUI y el I/O se harian en un lenguaje de alto nivel

Una implementacion 100% en ensamblador de la app completa requeriria
decenas de miles de lineas para cosas que Python hace en una (abrir un
PNG, renderizar texto, mostrar una ventana).

### Estimaciones (solo las rutinas criticas)

- **Lineas de codigo**: ~200-500 para cuantizacion + compresion
- **Tamano del binario**: ~1-5 KB (solo las rutinas)
- **Ganancia sobre C -O2**: 0-15% (el compilador ya optimiza muy bien)
- **Ganancia sobre Python**: 100-200x (misma que C, no mas)
- **Tiempo de desarrollo**: 10-50x mas que C para el mismo resultado

### La realidad del ensamblador moderno

En los años 80 (Z80, 6502), el ensamblador era necesario porque:
- Los compiladores generaban codigo malo
- Cada ciclo de reloj contaba (3.5 MHz)
- La memoria era escasa (48 KB)

En 2026 con Apple Silicon (M1+):
- clang con -O2 genera codigo ARM64 mejor que la mayoria de humanos
- El procesador tiene ejecucion fuera de orden, prediccion de saltos,
  caches multinivel — optimizar a mano es casi imposible
- La unica ventaja real: instrucciones SIMD (NEON en ARM) para
  procesar multiples pixeles en paralelo

Un bucle NEON para nearest_color procesando 4 pixeles simultaneamente
seria ~4x mas rapido que el C escalar, pero clang con -O2 -fvectorize
probablemente ya lo hace automaticamente.

### Fortalezas

- Tamano absoluto minimo del binario
- Control total sobre cada instruccion
- Util para aprender como funciona el procesador
- SIMD manual puede superar al compilador en casos muy especificos

### Debilidades

- Ganancia marginal sobre C compilado: 0-15% a costa de 10-50x mas tiempo
- No portable: ARM64 no corre en Intel, x86-64 no corre en ARM
- Sin bibliotecas: todo hay que hacerlo a mano o llamar a C
- Imposible mantener: un cambio trivial puede requerir reescribir bloques enteros
- GUI en ensamblador es demencial: no merece la pena ni plantearlo
- Debugging: sin source-level debugging, solo registros y volcados de memoria

### Ejemplo: nearest_color en ARM64

```asm
// X0 = puntero a pixel RGB, X1 = puntero a paleta
// Devuelve indice del color mas cercano en W0
nearest_color:
    mov w2, #0x7FFFFFFF     // best_dist = MAX
    mov w3, #0              // best_idx = 0
    mov w4, #0              // i = 0
.loop:
    ldrb w5, [x0]           // R del pixel
    ldrb w6, [x0, #1]       // G
    ldrb w7, [x0, #2]       // B
    ldrb w8, [x1, x4, lsl #2]      // R de paleta[i]
    ldrb w9, [x1, x4, lsl #2 + 1]  // G
    ldrb w10, [x1, x4, lsl #2 + 2] // B
    sub w5, w5, w8
    sub w6, w6, w9
    sub w7, w7, w10
    mul w5, w5, w5          // dr*dr
    madd w5, w6, w6, w5     // + dg*dg
    madd w5, w7, w7, w5     // + db*db
    cmp w5, w2
    csel w2, w5, w2, lo     // if d < best: best_dist = d
    csel w3, w4, w3, lo     // if d < best: best_idx = i
    add w4, w4, #1
    cmp w4, #16
    b.lt .loop
    mov w0, w3
    ret
```

16 instrucciones por iteracion, 16 iteraciones = 256 instrucciones.
A 3.2 GHz del M1, eso es ~80 nanosegundos por pixel.

Pero clang genera algo casi identico desde el C de la seccion anterior.

---

## 5. LISP (SBCL — Steel Bank Common Lisp)

### Descripcion

Common Lisp (1984) con SBCL, el compilador/runtime mas rapido disponible.
SBCL compila a codigo nativo y tiene un optimizador sofisticado.

LISP es el segundo lenguaje de programacion mas antiguo (1958, despues de
Fortran). Su modelo de computacion basado en listas y funciones es
radicalmente distinto a los lenguajes imperativos.

### Como seria la implementacion

```lisp
spectrumify.lisp       ;; main + loop con alguna GUI
palette.lisp           ;; paleta como lista de listas
converter.lisp         ;; nearest-color como funcion pura
compressor.lisp        ;; RLE como operacion sobre listas
exporter.lisp          ;; generacion de HTML con format
```

La cuantizacion se expresaria como una operacion funcional pura:
mapear una funcion sobre cada pixel de la imagen. Elegante en teoria.

El problema es el I/O: cargar un PNG, mostrar una ventana, manejar
eventos. LISP no tiene nada de esto en su estandar. Necesitarias:
- cl-sdl2 (bindings SDL2, calidad variable)
- opticl o zpng (carga de imagenes, limitados)
- ltk (bindings Tk, funcional pero feo)

### Estimaciones

- **Lineas de codigo**: ~400-600 (LISP es conciso para algoritmos)
- **Tamano del ejecutable**: 40-60 MB (SBCL incluye el compilador+runtime en el binario)
- **Dependencias**: SBCL runtime (~50 MB), Quicklisp (gestor de paquetes)
- **RAM en ejecucion**: 80-120 MB (SBCL reserva heap grande por defecto)
- **Tiempo de conversion**: ~50-100 ms (SBCL compila a nativo, pero con overhead de boxeo de numeros y GC)
- **Tiempo de compresion HTML**: ~20-50 ms (strings inmutables = muchas copias)
- **Distribucion**: un ejecutable de 50+ MB o SBCL instalado + fuentes

### Fortalezas

- Expresividad: nearest-color se escribe en 5 lineas elegantes
- REPL: desarrollo interactivo, modificar funciones en caliente
- Macros: metaprogramacion real (no decoradores, macros de verdad)
- Algoritmicamente potente: la compresion RLE como operacion sobre listas es natural
- Madurez: SBCL tiene 20+ anos de optimizaciones
- Funciones de primera clase: mapcar sobre pixeles es idiomatico

### Debilidades

- Runtime enorme: 50 MB de SBCL para una app de 200 KB de logica
- RAM excesiva: 80+ MB para manipular una imagen de 1 MB
- GUI: no hay solucion buena. cl-sdl2 es un wrapper fragil, ltk es de otra epoca
- Imagenes: opticl existe pero no se compara con Pillow o stb_image
- Manipulacion de pixeles: acceder a pixel[x,y] en un array LISP tiene overhead
  de bounds checking y potencial boxeo de enteros
- Comunidad: muy pequeña, documentacion escasa para cosas practicas
- Distribucion: el usuario necesita SBCL o un binario de 50 MB
- Curva de aprendizaje: la sintaxis de parentesis es una barrera real

### Ejemplo: nearest_color en Common Lisp

```lisp
(defparameter *palette*
  '((0 0 0) (0 0 170) (170 0 0) (170 0 170)
    (0 170 0) (0 170 170) (170 85 0) (170 170 170)
    (85 85 85) (85 85 255) (255 85 85) (255 85 255)
    (85 255 85) (85 255 255) (255 255 85) (255 255 255)))

(defun color-distance (c1 c2)
  (reduce #'+ (mapcar (lambda (a b) (expt (- a b) 2)) c1 c2)))

(defun nearest-color (pixel)
  (first (sort (copy-list *palette*)
               #'< :key (lambda (c) (color-distance pixel c)))))
```

Elegante: 5 lineas. Pero sort sobre 16 elementos por cada pixel es O(n log n)
cuando un bucle simple es O(n). La version idiomatica sacrifica rendimiento
por expresividad. Un LISPer experimentado escribiria una version imperativa
con loop para el hot path.

---

## Resumen comparativo

### Tabla numerica (especulativa, basada en la implementacion de Spectrumify)

| Metrica | Python | C + SDL2 | Pascal/Lazarus | x86-64 ASM | LISP (SBCL) |
|---------|--------|----------|----------------|------------|-------------|
| **Lineas de codigo** | 600 | 900 | 800 | 500* | 500 |
| **Tamano entregable** | 50 MB | 500 KB | 4 MB | 5 KB* | 55 MB |
| **RAM en ejecucion** | 60 MB | 8 MB | 12 MB | 2 MB* | 90 MB |
| **Conversion 153x102** | 500 ms | 8 ms | 15 ms | 7 ms | 80 ms |
| **Compresion HTML** | 100 ms | 3 ms | 8 ms | 2 ms | 30 ms |
| **Startup de la app** | 2 s | 0.05 s | 0.1 s | 0.01 s* | 3 s |
| **Tiempo de desarrollo** | 1x | 4x | 2x | 20x | 3x |
| **Mantenibilidad** | Alta | Media | Media | Nula | Baja |
| **Cross-platform** | Si | Si | Si | No | Si |
| **GUI nativa** | No (SDL) | No (SDL) | Si (Cocoa/GTK) | No | No |

(*) Solo rutinas criticas, sin GUI. Una app completa en ASM es inviable.

### Velocidad de conversion comparada (factor sobre Python)

```
Python      |========================================| 500 ms (1x)
LISP (SBCL) |======|                                   80 ms (6x)
Pascal      |==|                                        15 ms (33x)
C + SDL2    |=|                                          8 ms (62x)
x86-64 ASM  |=|                                          7 ms (71x)
```

### Tamano del entregable comparado

```
x86-64 ASM  |                                            5 KB*
C + SDL2    |=|                                        500 KB
Pascal      |====|                                       4 MB
Python      |==========================================| 50 MB
LISP (SBCL) |=============================================| 55 MB
```

### Sintesis final

**C + SDL2** es la opcion ganadora en eficiencia pura. 62x mas rapido que
Python, 100x mas pequeno, sin dependencias. El coste es el tiempo de
desarrollo (4x) y la gestion manual de memoria. Para una herramienta que
se distribuye como binario unico, es imbatible.

**Pascal/Lazarus** es el equilibrio sorprendente. GUI nativa del OS, binario
autocontenido de 4 MB, 33x mas rapido que Python, y un lenguaje que se
lee casi como pseudocodigo. El ecosistema limitado de bibliotecas de imagen
es su unico punto debil serio. Ideal si quieres una app de escritorio con
aspecto profesional sin pelear con SDL.

**Ensamblador x86-64/ARM64** no tiene sentido practico. Solo 15% mas rapido
que C compilado con -O2, a un coste de 20x mas tiempo de desarrollo, cero
portabilidad, y mantenimiento imposible. Su unica utilidad real en 2026 es
didactica: entender como funciona el procesador por dentro. Para Spectrumify,
el ensamblador Z80 del Spectrum tiene mas valor (es autentico y funcional en
su plataforma) que el ARM64 de un Mac moderno.

**LISP (SBCL)** es la opcion intelectualmente mas interesante y practicamente
la menos viable. La cuantizacion de color se expresa en 5 lineas puras y
elegantes, pero el runtime de 55 MB, los 90 MB de RAM, y la falta de
bibliotecas de imagen y GUI la hacen la peor eleccion para una app de
escritorio. Donde LISP brilla es en problemas que son inherentemente
recursivos o simbolicos — la manipulacion de pixeles no es uno de ellos.

**Python** sigue siendo la eleccion correcta para este proyecto: desarrollo
rapido, ecosistema maduro, facil de contribuir. Los 500 ms de conversion
son imperceptibles para el usuario. El exceso de 50 MB de tamano es el
precio de la productividad del desarrollador.
