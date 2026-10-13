---
section: 3
slug: format-abstraction
tier: T2
status: not-started
prereqs: [1, 2]
terms: [interfaz, puntero a función, tabla de despacho, patrón struct-de-punteros, backend de formato]
---

# Sección 3 — Una interfaz, varios formatos

**Nivel: T2** — es una decisión de diseño que tomas una vez y con la que
convives en cada bonus posterior.
**Podrás:** diseñar un único conjunto de operaciones que funcione igual sea
el archivo subyacente ELF de 64 bits, ELF de 32 bits o Mach-O, sin cadenas
de `if` repartidas por todo el programa.

## La idea

Ahora mismo `main.c` lee un solo formato: ELF de 64 bits, directamente, con
los tipos `Elf64_Ehdr` y `Elf64_Phdr` nombrados explícitamente en el código.
Eso está bien mientras haya un solo formato. En el momento en que existan
los bonus de ELF de 32 bits y Mach-O, cada lugar que toque la cabecera
necesitaría su propio `if (is_elf64) ... else if (is_elf32) ... else if
(is_macho)`. Multiplica eso por cada operación que necesitas — leer la
cabecera, encontrar dónde inyectar el stub, parchear el punto de entrada,
escribir el resultado — y el programa se convierte en un laberinto de ramas
casi duplicadas, fácil de romper en un formato mientras arreglas otro.

La solución es dejar de preguntar "¿qué formato es este?" más de una vez.
Pregúntalo una sola vez, justo después de leer el número mágico (§ 1) — y
que esa única respuesta elija *qué conjunto completo de funciones* se
encarga de todo lo demás para ese archivo, desde ese punto en adelante. El
resto del programa entonces llama a "parsea la cabecera", "encuentra el
punto de inyección", "parchea la entrada", "escribe la salida" sin
importarle con qué formato está hablando.

## Los nombres para esto

**Interfaz** — un conjunto acordado de operaciones, con nombre y con un
significado fijo, que más de una implementación concreta puede
proporcionar. Ya has usado una sin la palabra: `open`, `read`, `write`,
`close` son una interfaz — las mismas cuatro llamadas funcionan sea lo que
haya debajo un archivo normal, una tubería o un socket. Estás a punto de
construir una pequeña interfaz propia, con operaciones como "parsea esta
cabecera".

**Puntero a función** — una variable que guarda la dirección de una
función en vez de la dirección de un dato. Puedes llamarla exactamente
como una función normal, salvo que qué función se ejecuta realmente lo
decide la dirección que esté almacenada en ese momento en el puntero — que
puede cambiar en tiempo de ejecución. Este es el mecanismo que hace posible
en C, que no tiene clases ni polimorfismo integrado, "elige el formato una
vez, luego llama siempre a los mismos nombres sin importar cuál sea".

**Tabla de despacho** (también: **patrón struct-de-punteros**) — un
`struct` cuyos campos son todos punteros a función, un valor de struct por
formato (`elf64_backend`, `elf32_backend`, `macho_backend`), cada uno
relleno con las funciones reales de ese formato. "Despacho" porque decidir
qué función se ejecuta se llama *despachar* la llamada a la implementación
correcta. A veces verás esto llamado **vtable** en contextos de C++ —
abreviatura de **v**irtual **table**, tabla virtual — pero en C puro
construyes la misma idea a mano, como un struct corriente.

**Backend de formato** — el nombre de este proyecto para una implementación
completa de la interfaz: las cuatro funciones que saben hacer todo lo que
el resto del programa necesita, para exactamente un formato binario.

## Cómo funciona realmente

1. **Define primero la interfaz**, como un `struct` de punteros a función
   con una firma fija por operación, p. ej.:
   ```c
   typedef struct {
       int  (*parse_header)(uint8_t *buf, size_t len, void *out_info);
       long (*find_injection_point)(void *info);
       void (*patch_entry)(void *info, long new_entry);
       int  (*write_output)(int fd, void *info);
   } format_backend_t;
   ```
   Los campos exactos importan menos que la disciplina: cada backend debe
   implementar *las cuatro*, con la *misma firma*, para que quien llama
   nunca necesite saber cuál tiene en la mano.

2. **Detecta el formato una sola vez**, justo después de la comprobación
   del número mágico de § 1 y § 2 — los bytes `0x7F 'E' 'L' 'F'` de ELF
   frente a los propios de Mach-O — y a partir de esa única comprobación,
   elige *un* valor `format_backend_t` (un global `elf64_backend`,
   `elf32_backend` o `macho_backend`, cada uno un `struct` literal con sus
   cuatro funciones rellenas).

3. **En todo lo demás, llama a través del struct**: `backend.parse_header(...)`,
   `backend.find_injection_point(...)`, nunca más `if (format == ELF64) {...}
   else {...}`. La rama ocurrió exactamente una vez, en el momento de la
   detección.

4. **El `void *info` de cada formato** (o una unión etiquetada, si
   prefieres tipado explícito frente a `void *`) lleva lo que ese formato
   necesite realmente — los punteros `Elf64_Ehdr`/`Elf64_Phdr` de ELF, los
   propios de cabecera/load-commands de Mach-O — sin que la interfaz en sí
   necesite saber detalles de ELF o Mach-O.

## Trampas conocidas

- **Diseñar la interfaz pensando solo en ELF, y descubrir después que
  Mach-O no encaja.** ELF usa program headers; Mach-O usa load commands —
  formas distintas. Si la firma de una función de la interfaz deja ver
  tipos específicos de ELF (`Elf64_Phdr *` como parámetro, por ejemplo), el
  backend de Mach-O no puede implementarla honestamente. Mantén los
  parámetros de la interfaz genéricos (punteros opacos, tamaños, offsets) y
  deja que cada backend los interprete por dentro.
- **Un puntero a función que nunca se ha asignado.** Llamar a un puntero a
  función sin inicializar o nulo no da un error útil — es comportamiento
  indefinido, a menudo un crash sin mensaje útil. Cada struct de backend
  debe tener *los cuatro* campos asignados antes de usarse jamás; un
  backend a medio rellenar es peor que ninguna abstracción, porque parece
  completo hasta que se llama a la única operación que falta.
- **Redetectar el formato en más de un sitio.** Si "¿es esto ELF64?" se
  vuelve a comprobar dentro de `write_output`, has roto la abstracción en
  silencio — ahora hay dos sitios que decían el formato, y pueden
  discrepar si uno se actualiza sin el otro.

## Checkpoint

Diseña (en papel o como comentario de cabecera primero, luego como C real)
la interfaz `format_backend_t`: las firmas exactas de `parse_header`,
`find_injection_point`, `patch_entry` y `write_output`. Escribe el backend
de ELF64 como primera implementación concreta, rellenando un struct literal
con tu lógica ya existente de §§ 1–2, refactorizada para encajar en las
firmas. No escribas aún los backends de ELF32 o Mach-O — el checkpoint es
demostrar que la interfaz tiene la *forma* correcta haciendo funcionar
exactamente una implementación, de forma idéntica a como funciona `main.c`
hoy.

## Preguntas

Q-3.1 (recuerdo) ¿Qué guarda realmente cada campo de una tabla de despacho,
y en qué se diferencia eso de un struct que guarda directamente los
valores de la cabecera ELF?

Q-3.2 (aplicación) Escribe la declaración del struct `format_backend_t` de
cuatro campos (solo las firmas, sin cuerpos) para las operaciones descritas
arriba.

Q-3.3 (predicción) Llamas a `backend.patch_entry(...)` sobre un valor
`format_backend_t` cuyo campo nunca se asignó. ¿Qué pasa realmente cuando
el programa se ejecuta, y por qué es peor que una desreferencia normal de
puntero nulo sobre un puntero de datos?

Q-3.4 (predicción) Supón que `find_injection_point` del backend de Mach-O
necesita información que la versión de ELF de esa función nunca necesitó
(digamos, qué load command hacer crecer). ¿Qué te dice eso sobre si
`void *info` era la elección correcta para el parámetro compartido, frente
a una unión etiquetada?

Respuestas: `ANSWERS.md` § 3
