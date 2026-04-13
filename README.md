# spectrumify

> Image converter to pixel-art HTML with the 16-color palette of the ZX Spectrum.
> Implemented in 7 programming languages ​​as a comparative efficiency experiment, from Sinclair BASIC (1982) to ARM64 Assembly (2026).

## 🎮 Que es

Spectrumify convierte cualquier imagen (PNG, JPEG, BMP) en una tabla HTML de pixel-art
usando la paleta de 16 colores del ZX Spectrum. Incluye preview en tiempo real,
multiples modos de color, compresion lossless del HTML, y exportacion a formatos
retro (SCR nativo del Spectrum, GIF).

La herramienta nacio del problema de generar el pixel-art del sitio
[zx.josegomezfreelance.com](https://zx.josegomezfreelance.com/) y evoluciono hasta
convertirse en un estudio practico de programacion en multiples lenguajes.

## 🏷️ Version actual

**v0.1** — MVP funcional en 7 lenguajes

## 📦 Versiones disponibles

| Version | Binario | GUI | Lineas | Estado |
|---------|---------|-----|--------|--------|
| **Python** (MVP) | 18 MB | ✅ pygame | 1,378 | ✅ Completo |
| **C + SDL2** | 211 KB | ✅ SDL2 | 1,113 | ✅ Completo |
| **Pascal + SDL2** | 4.3 MB | ✅ SDL2 | 1,382 | ✅ Completo |
| **ARM64 Assembly** | 59 KB | ⚠️ Parcial | 3,513 | ⚠️ Core verificado |
| **Common Lisp** | 51 MB | ❌ CLI | 280 | ✅ CLI completo |
| **Sinclair BASIC** | N/A | N/A | 300 | 📝 Referencia |
| **Ensamblador Z80** | 250 B | N/A | 300 | ✅ Verificado (pasmo) |

## ✅ Funcionalidades

- ✅ Conversion a pixel-art con paleta ZX Spectrum (16 colores)
- ✅ Modo escala de grises (4 grises nativos del Spectrum)
- ✅ Modo blanco y negro (umbral de brillo)
- ✅ Preview side-by-side (original vs pixel-art)
- ✅ Resize preservando aspect ratio (Lanczos + nearest-neighbor)
- ✅ Hex corto (#RGB) para ~6% menos HTML
- ✅ Compresion HTML lossless: safari-safe y agresiva
- ✅ Size presets: SMALL (80), MEDIUM (153), BIG (256)
- ✅ Zoom del preview
- ✅ Estimacion de tamano HTML en vivo
- ✅ Export HTML, SCR (formato nativo ZX Spectrum), GIF
- ✅ SCR Viewer secreto con colores magenta/verde/rojo

## 🚀 Ejecutar (version Python)

```bash
python3 -m venv venv
source venv/bin/activate
pip install pygame Pillow
python main.py
```

## 🎹 Controles

| Tecla | Accion |
|-------|--------|
| `L` | Cargar imagen |
| `E` | Exportar (HTML / SCR / GIF) |
| `M` | Modo: 16 colores / Grises / B&W |
| `S` | Size: SMALL / MEDIUM / BIG |
| `+/-` | Zoom del preview |
| `C` | Compresion: safari-safe / agresiva / sin |
| `Q` | Salir |

## 📊 Benchmark

| | Binario | Arranque | Conversion | RAM |
|---|---------|----------|------------|-----|
| ARM64 ASM | **59 KB** | **<50 ms** | **~5 ms** | 85 MB |
| C + SDL2 | 211 KB | **<50 ms** | **~5 ms** | 85 MB |
| Pascal | 4.3 MB | **<50 ms** | ~15 ms | 85 MB |
| Python | 18 MB | ~2 s | 263 ms | 85 MB |
| LISP | 51 MB | 10 ms | ~100 ms | 73 MB |

## 📁 Estructura

```
spectrumify/
    main.py              # Python MVP
    src/                  # Modulos Python
    C/                    # Version C + SDL2 (211 KB)
    Pascal/               # Version Pascal + SDL2 (4.3 MB)
    Ensamblador/          # Version ARM64 Assembly (59 KB)
    LISP/                 # Version Common Lisp CLI (51 MB)
    Sinclair BASIC/       # Programas para ZX Spectrum real
    Ensamblador Z80/      # Rutinas Z80 (.tap listos)
    docs/                 # 3 documentos técnicos
```

## 📘 Documentacion

| Documento | Contenido |
|-----------|-----------|
| [Development Report (PDF)](docs/Spectrumify_Development_Report_ZX-V4_VFX.pdf) | Informe de desarrollo con benchmarks y graficas |
| [COMPARATIVA-LENGUAJES.md](docs/COMPARATIVA-LENGUAJES.md) | Analisis C vs Pascal vs ASM vs LISP vs Python |
| [GIF-ENCODER-PASCAL.md](docs/GIF-ENCODER-PASCAL.md) | Encoder GIF nativo en Pascal |

## 🔐 Seguridad

Todas las dependencias externas auditadas.

## 👤 Autor

**Jose Gomez Freelance (JGF)** — [josegomezfreelance.com](https://josegomezfreelance.com)

---

Co-desarrollado con Claude, Visual Studio Code, teclado y ratón.
