# Spectrumify — Version C + SDL2

Port completo de Spectrumify a C con SDL2. Un unico binario de ~200 KB
con la misma funcionalidad que la version Python de ~50 MB.

## Compilar

```bash
brew install sdl2    # solo la primera vez
cd C
# Descargar headers (no incluidos en el repo)
curl -sL -o stb_image.h https://raw.githubusercontent.com/nothings/stb/master/stb_image.h
curl -sL -o stb_image_write.h https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h
curl -sL -o msf_gif.h https://raw.githubusercontent.com/notnullnotvoid/msf_gif/master/msf_gif.h
make
```

## Ejecutar

```bash
./spectrumify
```

## Controles

Identicos a la version Python:

| Tecla | Accion |
|-------|--------|
| L | Cargar imagen (PNG, JPEG, BMP) |
| E | Exportar (submenu: HTML / SCR / BMP) |
| M | Modo: 16 colores / Grises / B&W |
| S | Size: SMALL (80) / MEDIUM (153) / BIG (256) |
| +/- | Zoom del preview |
| C | Compresion: safari-safe / agresiva / sin |
| Q | Salir |

## Arquitectura

Todo en headers para un unico punto de compilacion (`main.c`):

| Archivo | Funcion |
|---------|---------|
| `palette.h` | 16 colores ZX, nearest_color, hex corto |
| `converter.h` | Carga imagen (stb), resize bilinear, cuantizacion |
| `exporter.h` | Export HTML, SCR (6912 bytes), BMP |
| `ui.h` | Renderizado SDL2 con font bitmap 8x8 embebido |
| `main.c` | Loop principal, eventos, estado, dialogos |

## Dependencias

| Componente | Tipo | Tamano |
|-----------|------|--------|
| SDL2 | Libreria del sistema (`brew install sdl2`) | ~2 MB |
| stb_image.h | Header-only (descargar) | 250 KB |
| stb_image_write.h | Header-only (descargar) | 55 KB |
| msf_gif.h | Header-only (descargar) | 25 KB |

## Comparacion con Python

| Metrica | Python | C |
|---------|--------|---|
| Binario | ~50 MB (venv) | 194 KB |
| RAM | ~60 MB | ~8 MB |
| Dependencias runtime | Python + pygame + Pillow | SDL2 |
| Lineas de codigo | ~600 | ~400 (sin headers stb) |
