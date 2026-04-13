# Spectrumify — Version Pascal (Free Pascal + SDL2)

Port completo de Spectrumify a Pascal con Free Pascal y SDL2.
Un binario de 4.3 MB con la misma funcionalidad que las versiones
Python (~50 MB) y C (211 KB).

## Compilar

```bash
brew install fpc    # solo la primera vez
cd Pascal
make
```

## Ejecutar

```bash
./spectrumify
```

## Controles

Identicos a las otras versiones: L/E/M/S/C/+/-/Q

## Arquitectura

Todo en un unico archivo `spectrumify.pas` (~950 lineas):

- FPImage (stdlib de FPC) para carga de imagenes — sin dependencias externas
- SDL2 para GUI via bindings de PascalGameDevelopment
- Font bitmap 8x8 embebido
- Export: HTML, SCR (6912 bytes), BMP

## Comparacion

| Metrica | Python | C | Pascal |
|---------|--------|---|--------|
| Binario | ~50 MB | 211 KB | 4.3 MB |
| Deps imagen | Pillow (5 MB) | stb_image.h | FPImage (stdlib) |
| Deps GUI | pygame (12 MB) | SDL2 | SDL2 |
| Lineas codigo | ~600 | ~400 | ~950 |
