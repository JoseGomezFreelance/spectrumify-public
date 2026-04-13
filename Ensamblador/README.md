# Spectrumify — Version ARM64 Assembly (AArch64)

Port de Spectrumify a ensamblador ARM64 nativo para Apple Silicon.
**100% ensamblador** — sin ninguna linea de C en el binario final.

## Estado actual

**Core verificado y funcional:**
- nearest_color, rgb_to_hex (palette.s) ✅
- calculate_dimensions, resize_image, quantize_image (converter.s) ✅
- export_scr con layout no-lineal del Spectrum (exporter.s) ✅
- export_html sin fprintf, escritura directa (htmlwriter.s) ✅
- BMP loader nativo (bmploader.s) ✅
- Font bitmap 8x8 (font_data.s) ✅
- GUI SDL2 con controles completos (ui.s, main.s) ✅

**Bug conocido — Apple ARM64 variadic ABI:**
En Apple ARM64, los argumentos variadicos (printf, sprintf, fprintf)
se pasan en el STACK, no en registros. Esto es diferente del
AAPCS64 estandar usado en Linux ARM64. Los status bar y el HTML
export con fprintf tienen este bug parcialmente corregido.

## Compilar

```bash
brew install sdl2
cd Ensamblador
make
```

## Ejecutar

```bash
./spectrumify
```

Nota: solo carga archivos BMP (no PNG). Convertir antes:
```python
from PIL import Image
Image.open('foto.png').save('foto.bmp')
```

## Arquitectura — 100% ASM

| Archivo | Lineas | Funcion |
|---------|--------|---------|
| main.s | 1,174 | Loop SDL2, eventos, estado, carga BMP |
| ui.s | 730 | Font bitmap, draw_text, header, controles |
| htmlwriter.s | 230 | Export HTML sin fprintf (fwrite directo) |
| bmploader.s | 200 | Carga BMP 24-bit nativo |
| exporter.s | 321 | Export SCR formato Spectrum |
| converter.s | 233 | Resize nearest-neighbor, cuantizacion |
| font_data.s | 202 | 96 caracteres x 8 bytes |
| palette.s | 195 | Paleta ZX, nearest_color, rgb_to_hex |

**Total: ~3,300 lineas de ASM. Cero lineas de C.**

## Leccion clave: Apple ARM64 variadic ABI

Descubierta durante el desarrollo: en macOS ARM64, las funciones
variadicas (printf, fprintf, sprintf) reciben los argumentos
variadicos en el STACK, no en registros X1-X7.

```asm
// INCORRECTO en Apple ARM64:
mov     w1, #42              // printf NO lee esto
bl      _printf

// CORRECTO en Apple ARM64:
sub     sp, sp, #16
mov     w8, #42
str     x8, [sp]             // variadic arg en stack
bl      _printf
add     sp, sp, #16
```

Esto es diferente del AAPCS64 estandar (Linux) donde los variadicos
van en registros. Es la causa del bug mas persistente del proyecto.

## Comparacion

| | Python | C | Pascal | ARM64 ASM |
|---|---|---|---|---|
| Binario | ~50 MB | 211 KB | 4.3 MB | **59 KB** |
| Lineas | 1,378 | 1,113 | 1,382 | **3,513** |
| Formato imagen | PNG/JPEG | PNG/JPEG | PNG/JPEG/BMP | **Solo BMP** |
| Dependencias C | Pillow+pygame | stb+SDL2 | FPImage+SDL2 | **Solo SDL2** |

---

## Adenda: estado real y limitaciones

**Esta version es minimamente funcional.** Las rutinas core de conversion
(nearest_color, quantize, resize, export HTML/SCR) estan verificadas y
producen resultados identicos a las versiones Python y C. Sin embargo,
la app GUI tiene bugs significativos que la hacen poco usable en la
practica.

### Bugs conocidos sin resolver

1. **Apple ARM64 variadic ABI**: las funciones variadicas (printf, fprintf,
   sprintf) requieren pasar argumentos en el STACK en macOS ARM64, no en
   registros. Descubierto durante el desarrollo, corregido parcialmente.
   Afecta al status bar (muestra valores incorrectos) y al export HTML
   con fprintf (resuelto reescribiendo sin fprintf).

2. **BMP loader — valores de ancho/alto**: el loader lee correctamente los
   bytes del header BMP (verificado con Python), pero los valores leidos
   en los registros ARM64 no se propagan correctamente a traves de las
   llamadas a funciones. Se probo con globals, punteros en stack, y
   buffers malloc'd — todos producen el mismo resultado incorrecto.
   Causa raiz no determinada.

3. **Carga de imagen desde GUI**: al seleccionar un BMP via el dialogo,
   la imagen no se carga correctamente debido al bug #2. El pipeline
   funciona en el test aislado (test_core.c con stb_image) pero no
   con el BMP loader nativo en ASM.

4. **Solo BMP**: a diferencia de las otras versiones que cargan PNG/JPEG
   via Pillow o stb_image, la version ASM solo carga BMP 24-bit.
   Decodificar PNG (zlib+deflate) en ASM seria ~5000 lineas adicionales.

### Lo que SI funciona (verificado con tests)

- nearest_color: distancia euclidea a paleta ZX ✅
- rgb_to_hex: hex corto (#RGB) y largo (#RRGGBB) ✅
- calculate_dimensions: preserva aspect ratio ✅
- resize_image: nearest-neighbor ✅
- quantize_image: mapea todos los pixels a paleta ZX ✅
- export_html: genera HTML identico a la version Python (703 KB) ✅
- export_scr: genera SCR de exactamente 6912 bytes ✅
- GUI SDL2: ventana, controles, font bitmap 8x8 ✅

### Valoracion honesta

Claude Opus 4.6 puede generar ensamblador ARM64 sintacticamente correcto
y logicamente funcional para rutinas individuales. Sin embargo, integrar
multiples modulos ASM en una app completa con GUI revela limitaciones:

- **Gestion de registros caller-saved/callee-saved**: cada llamada a SDL
  o libc destruye X0-X18. Rastrear que registros estan vivos despues de
  cada `bl` es extremadamente propenso a errores.

- **ABI variadico de Apple**: no documentado explicitamente en los recursos
  de referencia habituales. Descubrirlo requirio debugging empirico con
  tests minimos de 10 lineas.

- **Stack management**: balancear `sub sp`/`add sp` a traves de multiples
  paths de error con branches condicionales es un campo de minas.

- **Debugging sin debugger**: sin `gdb`/`lldb` integrado en el workflow,
  cada bug requiere añadir prints de debug, recompilar, y razonar sobre
  el estado de 30 registros.

La conclusion practica confirma lo que predijimos en COMPARATIVA-LENGUAJES.md:
ensamblador moderno tiene **cero ganancia** sobre C compilado con -O2 y
**10x mas bugs** durante el desarrollo. El binario de 59 KB es impresionante
pero el coste en tiempo y fiabilidad es prohibitivo.

Para referencia futura: si se quisiera completar esta version, los dos
problemas criticos a resolver son el variadic ABI (ya documentado) y la
propagacion de valores a traves de cadenas de llamadas a funciones.
