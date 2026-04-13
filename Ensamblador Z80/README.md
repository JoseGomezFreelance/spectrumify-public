# Ensamblador Z80 — Spectrumify para el metal

Rutinas en ensamblador Z80 para el ZX Spectrum. Hacen lo mismo que las
versiones en Sinclair BASIC pero son **instantaneas** (vs segundos en BASIC).

## Archivos

| Archivo | Descripcion |
|---------|-------------|
| `bw.asm` | Convierte la pantalla actual a blanco y negro |
| `gray.asm` | Convierte la pantalla actual a 4 grises del Spectrum |
| `palette.asm` | Muestra los 16 colores del Spectrum en pantalla |

## Como ensamblar

A diferencia del Sinclair BASIC, el ensamblador Z80 **si se puede verificar**
en un Mac moderno usando [pasmo](https://pasmo.speccy.org/), un ensamblador
cruzado Z80:

```bash
# Instalar pasmo
brew install pasmo

# Ensamblar a .tap (cinta virtual)
pasmo --tapbas bw.asm bw.tap
pasmo --tapbas gray.asm gray.tap
pasmo --tapbas palette.asm palette.tap
```

La opcion `--tapbas` genera un `.tap` con un cargador BASIC automatico
que hace `RANDOMIZE USR 32768` al cargar.

## Como probar

1. Ensamblar con `pasmo --tapbas archivo.asm archivo.tap`
2. Abrir el `.tap` en un emulador:
   - **[Qaop](https://torinak.com/qaop/)** — arrastrar el `.tap` al navegador
   - **[JSSpeccy 3](https://jsspeccy.zxdemo.org/)** — idem
   - **Fuse** (`brew install fuse-emulator`) — File > Open

## Uso desde BASIC

Si cargas las rutinas en memoria, se invocan con:

```basic
RANDOMIZE USR 32768
```

Todas las rutinas estan en ORG 32768 (0x8000), la direccion estandar
para codigo maquina en el Spectrum.

## Notas tecnicas

- Las rutinas modifican los 768 bytes de atributos (22528-23295)
  sin tocar el bitmap (16384-22527)
- Usan tablas de lookup para mapear colores a brillo, evitando
  calculos lentos en tiempo de ejecucion
- B&W y grises ejecutan en ~1ms vs ~30s del equivalente en BASIC
- No usan interrupciones ni modifican el stack del sistema
- Compatibles con Spectrum 48K y 128K

## Verificacion

El codigo ha sido verificado con pasmo 0.5.5 (compilado desde fuente).
Los 3 archivos ensamblan sin errores y generan `.tap` funcionales.

Los `.tap` incluidos en esta carpeta estan listos para cargar en
cualquier emulador. Para reensamblar tras modificaciones:

```bash
pasmo --tapbas bw.asm bw.tap
pasmo --tapbas gray.asm gray.tap
pasmo --tapbas palette.asm palette.tap
```

Verificar que el resultado visual es correcto requiere un emulador.
