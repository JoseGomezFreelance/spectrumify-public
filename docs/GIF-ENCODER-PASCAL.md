# GIF Encoder para Free Pascal

Encoder GIF minimo escrito desde cero en Pascal puro para Spectrumify.
Sin dependencias externas, sin librerias, sin C, sin FFI.

## Origen

Free Pascal no tiene writer GIF en su biblioteca estandar (tiene PNG,
BMP, JPEG, pero no GIF). En vez de añadir una dependencia externa,
escribimos un encoder GIF completo en ~150 lineas de Pascal.

## Caracteristicas

- **Frame unico** (imagen estatica, no animada)
- **Paleta indexada** de hasta 256 colores
- **Compresion LZW** completa (misma que usa el formato GIF estandar)
- **GIF89a** compatible con todos los navegadores y visores
- **Cero dependencias** — solo usa tipos basicos de Pascal
- **~150 lineas** de codigo limpio y comentado

## Uso

```pascal
type
  TColor3 = record R, G, B: Byte; end;
  TPixelArray = array of TColor3;

const
  MiPaleta: array[0..3] of TColor3 = (
    (R:0;G:0;B:0), (R:85;G:85;B:85),
    (R:170;G:170;B:170), (R:255;G:255;B:255)
  );

var
  Pixels: TPixelArray;

// ... cargar o generar pixeles ...

ExportGIF(Pixels, Ancho, Alto, MiPaleta, 'salida.gif');
```

Los pixeles deben estar cuantizados a los colores de la paleta antes
de llamar a ExportGIF. El encoder busca cada pixel en la paleta por
coincidencia exacta de RGB.

## Como funciona

### Estructura del archivo GIF

```
Bytes     Contenido
------    ---------
6         "GIF89a" (firma)
7         Logical Screen Descriptor (ancho, alto, flags)
3*N       Global Color Table (N colores RGB)
10        Image Descriptor (posicion, tamaño)
variable  Datos LZW comprimidos (sub-bloques de max 255 bytes)
1         Terminador de bloque (0x00)
1         Trailer GIF (0x3B)
```

### Compresion LZW

El corazon del encoder es la compresion LZW (Lempel-Ziv-Welch):

1. Inicializar diccionario con los codigos base (uno por color)
2. Añadir Clear Code y EOI Code
3. Recorrer los pixeles secuencialmente
4. Para cada pixel, buscar la secuencia mas larga en el diccionario
5. Cuando la secuencia no se encuentra, emitir el codigo actual
   y añadir la nueva secuencia al diccionario
6. Los codigos se empaquetan en bits de longitud variable (5-12 bits)
7. Cuando el diccionario se llena (4096 entradas), emitir Clear Code
   y reiniciar

### Parametros segun paleta

| Colores | MinCodeSize | Clear | EOI | Bits iniciales |
|---------|-------------|-------|-----|----------------|
| 2 (B&W) | 2 | 4 | 5 | 3 |
| 4 (grises) | 2 | 4 | 5 | 3 |
| 16 (ZX) | 4 | 16 | 17 | 5 |
| 256 | 8 | 256 | 257 | 9 |

## Limitaciones

- Solo frame unico (no GIF animado)
- No soporta transparencia
- No hace dithering
- Busqueda lineal en el diccionario LZW (O(n) por entrada) — suficiente
  para imagenes pequeñas, no optimo para imagenes grandes
- Sin entrelazado

## Libreria independiente

El encoder esta extraido como unit independiente en `Pascal/gifwriter.pas`.
Para usarlo en cualquier proyecto Free Pascal:

```pascal
unit GIFWriter;

interface

type
  TGIFColor = record R, G, B: Byte; end;
  TGIFPixels = array of TGIFColor;

procedure WriteGIF(const Pixels: TGIFPixels; W, H: Integer;
                    const Palette: array of TGIFColor;
                    const FileName: string);

implementation
// ... codigo del encoder ...
end.
```

Cualquier proyecto Free Pascal puede exportar GIF con un simple
`uses GIFWriter` sin dependencias externas. Solo hay que copiar
`gifwriter.pas` al proyecto.

## Referencia

- [Especificacion GIF89a](https://www.w3.org/Graphics/GIF/spec-gif89a.txt)
- [Articulo LZW en Wikipedia](https://en.wikipedia.org/wiki/Lempel%E2%80%93Ziv%E2%80%93Welch)
- Inspirado en la filosofia header-only de [msf_gif.h](https://github.com/notnullnotvoid/msf_gif) (usado en la version C)
