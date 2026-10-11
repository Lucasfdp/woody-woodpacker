# woody-woodpacker — Plan de aprendizaje

**Modo:** 42
**Objetivo:** construir una base sólida — sin plazo, profundizando a propósito
**Empezado:** 2026-10-11
**Idiomas:** learn/ (EN) · learn_es/ (ES)

## Para qué es este proyecto
Construir un empaquetador (packer) de ELF x86_64 (`woody_woodpacker`): cifra
un binario objetivo, le inyecta un stub de descifrado, y modifica el punto
de entrada para que el binario empaquetado (`woody`) se descifre a sí mismo
y se ejecute de forma idéntica al original. Después extender el mismo
mecanismo a ELF de 32 bits, Mach-O, una clave parametrizable, compresión
LZSS, y un bucle de descifrado optimizado en ensamblador — los 5 bonus.

## Para qué NO es este proyecto
- **Pruebas de ejecución de PE** — aplazado. Un `.exe` empaquetado no se
  puede ejecutar ni verificar en este Mac sin Wine o una VM de Windows. Si
  se intenta, será solo estructural (corrección de cabeceras/offsets), al
  final, si queda tiempo.
- **Criptografía profunda** — el algoritmo tiene que ser realmente no
  trivial (el enunciado descarta un ROT simple), no criptográficamente
  inviolable. El diseño real de cifrados es otro proyecto.
- **Internals de compiladores/enlazadores** más allá de lo que realmente
  exige el formato ELF/Mach-O.

## Restricciones (del enunciado)
- Solo ELF de 64 bits en la parte obligatoria — otras arquitecturas deben
  rechazarse con un mensaje claro, nunca con un fallo (crash).
- Ejecutable llamado `woody_woodpacker`; salida llamada `woody`.
- Solo funciones permitidas: `open`, `close`, `exit`, `fputs`, `fflush`,
  `lseek`, `mmap`, `munmap`, `mprotect`, `perror`, `strerror`, `syscall`,
  la familia `printf`, y `read`/`write`/`malloc`/`free` autorizadas por la
  libft.
- Clave generada aleatoriamente, impresa en stdout.
- El binario empaquetado debe imprimir `....WOODY....` + salto de línea, y
  luego ejecutarse igual que el original tras descifrarse.
- Nunca debe fallar (crash), no debe alterar la ejecución final.
- **Los bonus solo se evalúan si la parte obligatoria es perfecta.**

## Bonus asumidos (los 5)
1. Gestión de ELF de 32 bits
2. Clave parametrizable (por CLI, además de la aleatoria por defecto)
3. Optimización del algoritmo en ensamblador (continuación directa del
   trabajo de SWAR/SIMD en libasm)
4. Formato binario adicional — **Mach-O**, completo y probado en ejecución
   (esta máquina es un Mac); PE solo estructural, al final, si da tiempo
5. Compresión binaria — **LZSS**

Ver `DECISIONS.md` para el razonamiento detrás de cada elección.

## Asignación de profundidad

| # | Concepto | Centralidad | Transferencia | Coste después | Total | Nivel |
|---|---|---|---|---|---|---|
| 1 | Formato ELF (cabecera, program headers) | 3 | 3 | 3 | 10→**T3** | T3 (excepción — esto *es* el proyecto) |
| 2 | Manejo defensivo de errores ("nunca fallar") | 2 | 3 | 2 | 8 | T2 |
| 3 | Interfaz de abstracción de formatos | 3 | 3 | 3 | 10 | T2 |
| 4 | E/S de archivos para copia exacta de bytes | 2 | 2 | 1 | 5 | T1 (ya conocido en su mayoría) |
| 5 | `mmap`/`mprotect` | 3 | 3 | 3 | 10 | T2 |
| 6 | Diseño del cifrado: cifrado de flujo, aleatoriedad, clave parametrizable | 3 | 3 | 2 | 9 | T2 |
| 7 | Modificación del punto de entrada / inyección de código | 3 | 3 | 3 | 10→**T3** | T3 (excepción — esto *es* el proyecto) |
| 8 | Stub de descifrado independiente de posición (asm x86_64) | 3 | 2 | 3 | 8 | T2 |
| 9 | Variante del stub para 32 bits (`int 0x80`, registros más estrechos) | 2 | 2 | 2 | 6 | T1 (mismo patrón, segundo objetivo) |
| 10 | Compresión y descompresión LZSS | 3 | 3 | 3 | 10→**T3** | T3 (excepción — tiempo dedicado, objetivo real de aprendizaje) |
| 11 | Formato Mach-O y empaquetado | 2 | 3 | 2 | 8 | T2 |
| 12 | *(Bonus)* bucle de keystream optimizado en asm | 1 | 3 | 1 | 6 | T1 — continuación directa de libasm |

## Secciones

| # | Archivo | Título | Nivel | Estado | Checkpoint |
|---|---|---|---|---|---|
| 1 | `01-elf-format.md` | Formato de archivo ELF | T3 | no empezado | analizar e imprimir las cabeceras ELF/program de un binario real |
| 2 | `02-defensive-error-handling.md` | Nunca fallar: comprobaciones defensivas | T2 | no empezado | rechazar limpiamente entradas que no sean ELF/x86_64 |
| 3 | `03-format-abstraction.md` | Una interfaz, varios formatos | T2 | no empezado | diseñar la interfaz de backend de formatos |
| 4 | `04-file-io-binary-copying.md` | Copia exacta de archivos byte a byte | T1 | no empezado | copiar un binario idéntico a `woody` |
| 5 | `05-mmap-mprotect.md` | Mapeo de memoria y permisos de página | T2 | no empezado | demo descartable: mmap+write+exec |
| 6 | `06-encryption-design.md` | Cifrado de flujo, aleatoriedad, clave parametrizable | T2 | no empezado | ida y vuelta de cifrado/descifrado aislado |
| 7 | `07-entry-point-injection.md` | Modificación del punto de entrada e inyección | T3 | no empezado | inyectar espacio para el stub, modificar `e_entry` |
| 8 | `08-decrypt-stub-asm.md` | El stub de descifrado independiente de posición | T2 | no empezado | el flujo completo funciona en un objetivo de 64 bits |
| 9 | `09-32bit-stub-variant.md` | 32 bits: un segundo stub, el mismo patrón | T1 | no empezado | el flujo completo funciona en un objetivo de 32 bits |
| 10 | `10-lzss-compression.md` | Compresión y descompresión LZSS | T3 | no empezado | funciona comprimir-luego-cifrar / descifrar-luego-descomprimir |
| 11 | `11-macho-format.md` | Formato Mach-O y empaquetado | T2 | no empezado | el flujo completo funciona en un objetivo Mach-O |
| 12 | `12-asm-optimised-keystream.md` | Vectorizar el bucle de descifrado | T1 | no empezado | keystream XOR con SWAR/SIMD, tras tener todo lo demás perfecto |

## Preparación para la defensa
*(se completa a medida que se terminan las secciones)*

## Aplazado / v2
- **Empaquetado de PE probado en ejecución** — necesita Wine o una VM de
  Windows. Revisar solo después de que la parte obligatoria y los otros
  cuatro bonus estén sólidos.
- **Compresión más allá de LZSS** (p. ej. añadir codificación Huffman
  encima) — los compresores de clase gzip reales hacen esto; fuera de
  alcance aquí.
