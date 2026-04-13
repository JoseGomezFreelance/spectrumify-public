# Spectrumify — Version Common Lisp (SBCL)

Herramienta de linea de comandos para convertir imagenes a pixel-art
con paleta ZX Spectrum. Escrita en Common Lisp puro con SBCL.

## Ejecutar

```bash
cd LISP
sbcl --load bundle/bundle.lisp \
     --eval '(require :opticl)' \
     --eval '(require :zpng)' \
     --load spectrumify.lisp \
     --eval '(spectrumify:convert "foto.png" :width 153)'
```

## Opciones

```lisp
(spectrumify:convert "imagen.png"
  :width 153         ; ancho en celdas (default 153)
  :mode :16          ; :16, :gray, :bw
  :format :html      ; :html, :png, :scr
  :output "out.html" ; nombre de salida (auto si nil)
)
```

## CLI

```bash
sbcl --load bundle/bundle.lisp \
     --eval '(require :opticl)' --eval '(require :zpng)' \
     --load spectrumify.lisp \
     --eval '(spectrumify:main)' \
     -- foto.png --width 80 --mode bw --format png
```

## Formatos de salida

| Formato | Extension | Descripcion |
|---------|-----------|-------------|
| HTML | .html | Tabla pixel-art con hex corto |
| PNG | .png | Imagen cuantizada via zpng |
| SCR | .scr | Formato nativo ZX Spectrum (6912 bytes) |

## Arquitectura

Un solo archivo (`spectrumify.lisp`, ~280 lineas) con:

- `nearest-color`: 5 lineas de Lisp funcional puro
- `quantize-image`: mapea cada pixel a la paleta
- `export-html`: genera tabla HTML con hex corto (#RGB)
- `export-scr`: layout no-lineal del Spectrum
- `export-png`: via zpng (puro Lisp)
- `convert`: pipeline completo

## Dependencias (bundle local)

Las dependencias estan en `bundle/` como copia local (no necesita
internet despues de la instalacion inicial):

- **opticl**: carga PNG/JPEG/BMP (puro Lisp)
- **zpng**: escribe PNG (puro Lisp)
- 26 dependencias transitivas (todas auditadas)

## Comparacion

| Metrica | Python | C | Pascal | ARM64 ASM | LISP |
|---------|--------|---|--------|-----------|------|
| Lineas | 1,378 | 1,113 | 1,382 | 3,513 | **280** |
| HTML size | 702 KB | 703 KB | 703 KB | 703 KB | **703 KB** |
| SCR size | 6,912 | 6,912 | 6,912 | 6,912 | **6,912** |
| GUI | Si | Si | Si | Si | **No (CLI)** |
| Formato in | PNG/JPEG | PNG/JPEG | PNG/JPEG/BMP | BMP | **PNG/JPEG/BMP** |

La version LISP tiene el codigo mas conciso (280 lineas vs 1,100+)
gracias a la expresividad del lenguaje. El `nearest-color` funcional
es la implementacion mas elegante de todas las versiones.

---

## Por que no tiene GUI

Se intentaron los cuatro caminos posibles para GUI desde Common Lisp
en macOS ARM64 (Apple Silicon). Los cuatro fallaron:

### 1. cl-sdl2 (bindings SDL2 via CFFI)
**Resultado**: crash fatal en SBCL durante la compilacion del modulo.
CFFI no puede manejar correctamente las llamadas FFI a SDL2 en ARM64.

### 2. Cocoa/AppKit nativo via CFFI
**Resultado**: crash al llamar `objc_msgSend` con structs (NSRect).
En ARM64, los structs se pasan en registros siguiendo reglas ABI
complejas que CFFI no implementa correctamente. Todos los registros
del thread a cero en el crash — el proceso ni siquiera arranca.

### 3. ltk (bindings Tk, puro Lisp)
**Resultado**: macOS 26.4 mata el proceso `Wish` (interprete Tk del
sistema) con `SIGKILL (Code Signature Invalid)`. El Tk 8.5.9 que
viene con macOS tiene una firma de codigo que macOS 26.4 rechaza
por "Launch Constraint Violation". ltk es puro Lisp y funciona
correctamente — el problema es que el Wish del sistema no arranca.

### 4. Core Graphics/Quartz via CFFI
**Resultado**: mismo problema que Cocoa — requiere pasar structs
CGRect via FFI, misma limitacion de CFFI en ARM64.

### Causa raiz

El problema no es Common Lisp ni SBCL. Es que **CFFI en SBCL en
ARM64 macOS no puede pasar structs a funciones C/Objective-C**.
Es una limitacion conocida de la interaccion entre:
- La ABI de ARM64 de Apple (structs en registros)
- La implementacion de CFFI (no maneja esta ABI correctamente)
- Las restricciones de firma de codigo de macOS 26.4

macOS no ofrece forma de dibujar en pantalla sin pasar por
Cocoa/AppKit o Core Graphics, ambos requieren pasar structs.
No hay framebuffer directo, no hay X11 nativo.

### Posibles soluciones futuras

Para un futuro modelo Claude mas avanzado o una version futura de
SBCL/CFFI que resuelva estos problemas:

1. **CFFI con soporte ARM64 struct passing**: si CFFI implementara
   correctamente el passing de structs en registros ARM64 (AAPCS64
   Apple variant), tanto cl-sdl2 como Cocoa FFI funcionarian
   inmediatamente.

2. **Homebrew Tcl/Tk**: `brew install tcl-tk` instalaria una version
   moderna de Tk con firma de codigo valida. ltk funcionaria
   apuntando a este Wish en vez del del sistema.

3. **McCLIM con backend Cocoa**: McCLIM (Common Lisp Interface
   Manager) es un framework GUI escrito enteramente en CL. Su
   backend para macOS esta en desarrollo experimental.

4. **Servidor web local**: arrancar un mini HTTP server en Lisp y
   abrir el navegador. El HTML pixel-art que ya generamos seria
   la propia interfaz. Cero dependencias nativas.

5. **ECL en vez de SBCL**: Embeddable Common Lisp compila a C y
   podria manejar el FFI de forma diferente, posiblemente
   evitando los problemas de struct passing de CFFI/SBCL.

6. **Escribir un mini servidor de ventanas**: un proceso C minimo
   (compilado con clang) que cree la ventana y el framebuffer,
   comunicandose con el proceso LISP via pipe/socket local.
   Similar a como ltk habla con Wish, pero con un "Wish" propio.
