---
section: 1
slug: elf-format
tier: T3
status: not-started
prereqs: []
terms: [ELF, magic number, e_ident, EI_CLASS, e_type, e_entry, ABI, program header, segment vs section, PT_LOAD, p_vaddr / p_offset / p_filesz / p_memsz, p_flags (PF_R / PF_W / PF_X)]
---

# Sección 1 — Qué hay realmente dentro de un programa compilado

**Nivel: T3** — esto no es conocimiento de fondo para el proyecto, *es* el
proyecto. Cada bonus (32 bits, Mach-O, inyección, compresión) es una
variación de "entender y manipular la estructura de este archivo."
**Podrás:** leer a mano la cabecera y las cabeceras de programa de
cualquier binario ELF x86_64, y explicar exactamente qué hace el sistema
operativo con cada campo cuando ejecuta ese archivo.

## La idea

Cuando ejecutas `clang -o sample sample.c`, el compilador no simplemente
vuelca código máquina en un archivo. Escribe un documento estructurado —
piénsalo como un manifiesto de envío grapado a una caja. El manifiesto
dice: "esta caja contiene estas subcajas, cada una va en este sitio
concreto del almacén, con estas reglas de acceso (¿se puede abrir? ¿se
puede escribir dentro? ¿se puede ejecutar lo que hay dentro?)." El kernel
lee ese manifiesto antes de ejecutar una sola instrucción de tu programa.

Ese formato de manifiesto-más-caja es **ELF**. El "almacén" es la memoria
virtual de tu proceso. Las "subcajas" son trozos del archivo que se
colocan en direcciones de memoria específicas. El trabajo entero de tu
programa `woody_woodpacker` es leer ese manifiesto, añadir una subcaja
nueva (el stub de descifrado), y editar una línea del manifiesto (por
dónde empezar a leer) — sin romper nada más de lo que el manifiesto
describe.

## Los nombres para esto

**ELF** — **E**xecutable and **L**inkable **F**ormat (formato ejecutable y
enlazable). El propio nombre te dice sus dos trabajos: es un formato que
un cargador puede *ejecutar* directamente, y uno que un enlazador puede
*enlazar* (combinar con otros archivos objeto) antes de eso. Ambos usos
comparten la misma estructura de archivo, con distintas partes
enfatizadas.

**Magic number (número mágico)** — los primeros 4 bytes de cualquier
archivo ELF: `0x7F`, `'E'`, `'L'`, `'F'`. "Número mágico" es el término
genérico (en todos los formatos de archivo, no solo ELF) para una
secuencia de bytes fija al principio de un archivo cuyo único trabajo es
decir "este archivo es lo que dice ser" antes de confiar en nada más de
él. Los archivos PNG, ZIP, JPEG — todos tienen su propio número mágico por
la misma razón.

**e_ident** — **E**LF **ident**ification (identificación ELF). Es el
nombre del primer campo de la cabecera ELF — un array de 16 bytes que
contiene el número mágico más un puñado de flags de un byte sobre la
forma básica del archivo. Uno de esos flags es:

**EI_CLASS** — **E**LF **I**dentification, **CLASS** (clase). Byte número
4 de `e_ident`. El valor `1` (`ELFCLASS32`) significa "esto es un ELF de
32 bits," el valor `2` (`ELFCLASS64`) significa 64 bits. Este único byte
decide si cualquier otra estructura del archivo — la cabecera, las
cabeceras de programa — se interpreta con anchos de campo de 32 o 64
bits. Si te equivocas aquí, todos los offsets que leas después son
basura.

**e_type** — te dice qué *categoría* de archivo ELF es: `ET_EXEC` (un
ejecutable independiente, el valor histórico por defecto), `ET_DYN` (una
librería compartida, o — en sistemas modernos — un ejecutable
independiente de posición; la mayoría de binarios compilados hoy son en
realidad `ET_DYN`), `ET_REL` (un archivo objeto reubicable, como un `.o`
antes de enlazar).

**e_entry** — la dirección de memoria virtual donde la CPU empieza a
ejecutar. Este es el campo más importante para este proyecto: es lo que
modificas para redirigir la ejecución hacia tu stub de descifrado
inyectado.

**ABI** — **A**pplication **B**inary **I**nterface (interfaz binaria de
aplicación). El libro de reglas sobre cómo se organiza el código
compilado y cómo habla con el sistema operativo y con otro código
compilado — qué registros llevan qué argumentos, cómo debe quedar la
pila, qué número significa qué syscall. Ya conociste esto en libasm como
"la convención de llamada System V AMD64" — eso *es* parte de la ABI de
x86_64 Linux. La cabecera de ELF registra a qué ABI apunta un binario, lo
cual es parte de por qué un ELF de 32 bits no se puede simplemente
ejecutar como si fuera de 64 bits: la ABI, no solo la organización del
archivo, es distinta.

**Program header (cabecera de programa)** — una entrada en una segunda
tabla (separada de la cabecera ELF principal) que le dice al *cargador* —
la parte del kernel que prepara un proceso nuevo — qué mapear en memoria
antes de que empiece la ejecución siquiera.

**Segment vs. section (segmento vs. sección)** — es fácil confundirlos
porque ambos son "trozos del archivo," pero sirven a lectores distintos
en momentos distintos:
- Un **segmento** (descrito por una cabecera de programa) es un concepto
  de *tiempo de ejecución*: "mapea estos bytes en memoria, aquí, con
  estos permisos." El cargador solo mira los segmentos.
- Una **sección** (descrita por una tabla de cabeceras de sección
  separada) es un concepto de *tiempo de compilación*: "este trozo con
  nombre es `.text`," "este otro es la tabla de símbolos." Los
  enlazadores y depuradores usan secciones; el cargador las ignora por
  completo.

  Un segmento normalmente *contiene* varias secciones — p. ej. el
  segmento que se mapea con lectura+ejecución suele contener la sección
  `.text` (instrucciones reales) y `.rodata` (datos de solo lectura)
  juntas, porque necesitan los mismos permisos de memoria.

**PT_LOAD** — **P**rogram header **T**ype (tipo de cabecera de programa),
**LOAD**. El tipo específico de cabecera de programa que significa "carga
este trozo del archivo en memoria." No todas las cabeceras de programa
son `PT_LOAD` (hay otras, para información de enlazado dinámico, etc.),
pero las entradas `PT_LOAD` son las que realmente hacen que tu código y
tus datos existan en el proceso en ejecución.

**p_vaddr / p_offset / p_filesz / p_memsz** — cuatro campos de cada
cabecera de programa:
- `p_offset` — dónde empiezan los bytes de este segmento *en el archivo en
  disco*.
- `p_vaddr` — dónde debe colocarse este segmento *en memoria virtual*.
- `p_filesz` — cuántos bytes copiar realmente del archivo.
- `p_memsz` — cuánta memoria reservar para él — puede ser *mayor* que
  `p_filesz`, rellenando el exceso con ceros. (Así funciona `.bss`, el
  segmento de datos inicializados a cero: no ocupa espacio en el archivo
  en absoluto, solo una nota que dice "reserva esta cantidad de memoria y
  pon ceros.")

**p_flags (PF_R / PF_W / PF_X)** — **P**rogram header **Flags** — Read
(lectura), Write (escritura), eXecute (ejecución). Los bits de permiso
que el sistema operativo aplica a la memoria de este segmento una vez
mapeado. Los segmentos de código suelen ser R+X pero *no* W (así que el
código inyectado/modificado normalmente no se puede escribir
directamente — por eso tu stub necesitará `mprotect`, visto en § 5, para
cambiar esto temporalmente).

## Cómo funciona realmente

Cuando el kernel ejecuta `execve()` sobre un archivo ELF, aproximadamente:

1. Lee `e_ident` — comprueba el número mágico, comprueba `EI_CLASS` para
   saber si debe interpretar el resto como estructuras de 32 o 64 bits.
2. Lee el resto de la cabecera ELF — incluyendo `e_entry` y dónde vive en
   el archivo la propia tabla de cabeceras de programa.
3. Recorre la tabla de cabeceras de programa. Para cada entrada de tipo
   `PT_LOAD`: copia `p_filesz` bytes empezando en `p_offset` del archivo,
   a memoria empezando en `p_vaddr`, reservando `p_memsz` bytes en total
   (rellenando con ceros el exceso), y aplica los permisos de `p_flags`.
4. Una vez mapeado cada segmento `PT_LOAD`, pone el puntero de
   instrucciones de la CPU en `e_entry` y empieza a ejecutar.

Ese es todo el modelo de carga. No pasa nada más antes de que tu código se
ejecute. Si `e_entry` apunta a algún sitio que el paso 3 no mapeó
realmente, el paso 4 falla (crash) de inmediato (ver trampas, abajo).

Para un packer, esto significa que tus opciones para inyectar código
ejecutable nuevo están limitadas a lo que encaje en este modelo:
- Encontrar espacio sin usar dentro de la memoria reservada-pero-no-usada
  de un segmento `PT_LOAD` (`p_memsz > p_filesz`, o relleno de
  alineación) — no hace falta un segmento nuevo, pero el espacio es
  escaso y a veces no existe.
- Añadir un segmento `PT_LOAD` completamente nuevo, con su propio
  `p_vaddr`, llevando el código de tu stub y el payload cifrado.
- Extender el `p_filesz`/`p_memsz` de un segmento existente para hacer
  sitio al final, añadiendo ahí los bytes de tu stub.

Cada opción tiene compromisos reales que valorarás a fondo en § 7
(inyección en el punto de entrada) — esta sección trata de entender el
formato lo bastante bien como para tomar esa decisión con información, no
de tomarla todavía.

## Trampas conocidas

- **Leer con el ancho de estructura equivocado.** Si analizas un archivo
  ELF de 32 bits usando las estructuras `Elf64_*` (o al revés), todos los
  campos después de `EI_CLASS` se leerán como basura — no
  necesariamente un crash, solo números silenciosamente incorrectos, que
  es peor porque parece que funciona.
- **Confiar en `e_entry` sin comprobar que esté realmente cubierto por un
  segmento `PT_LOAD`.** Este es exactamente el escenario de Q-1.4: saltar
  a una dirección que nada mapeó, y el resultado es `SIGSEGV`.
- **Confundir segmentos y secciones al decidir dónde inyectar código.** El
  cargador nunca mira las cabeceras de sección — si preservas con cuidado
  la corrección de las cabeceras de sección pero rompes una entrada
  `PT_LOAD`, el binario sigue sin ejecutarse. Al revés, las cabeceras de
  sección pueden estar un poco "mal" o incluso eliminadas por completo, y
  el binario funciona bien — al cargador no le importa.
- **`readelf -h` vs `readelf -l` vs `readelf -S`** — es fácil mirar la
  tabla equivocada al depurar. `-h` es la cabecera principal, `-l` son las
  cabeceras de programa (segmentos, lo que usa el cargador), `-S` son las
  cabeceras de sección (lo que usaba el enlazador/depurador).

## Checkpoint

Escribe un pequeño programa en C (esto es código real del proyecto, no
descartable — se convierte en la primera pieza de la propia lógica de
lectura de ELF de `woody_woodpacker`) que:
1. Abra un binario ELF de 64 bits real compilado, dado como argumento.
2. Lea y valide el número mágico — rechace cualquier otra cosa.
3. Lea `EI_CLASS` y rechace cualquier cosa que no sea `ELFCLASS64` (esta
   es tu primera pieza de la comprobación obligatoria "File architecture
   not supported" — la § 2 cubrirá el resto de ese requisito
   correctamente).
4. Imprima `e_entry`, y luego recorra la tabla de cabeceras de programa,
   imprimiendo cada entrada `PT_LOAD` con su `p_vaddr`, `p_offset`,
   `p_filesz`, `p_memsz` y `p_flags` de forma legible.

Verifícalo contra `readelf -h` y `readelf -l` sobre el mismo binario — tus
números deben coincidir exactamente.

## Preguntas

Q-1.1 (recuerdo) ¿Qué cuatro bytes deben aparecer al principio de
cualquier archivo ELF, y en qué orden?

Q-1.2 (recuerdo) ¿Qué único byte de `e_ident` te dice si un archivo es de
32 o 64 bits, y cuáles son sus dos valores posibles?

Q-1.3 (aplicación) Dado un volcado de `readelf -h`, ¿qué campo te dice a
dónde tendrías que redirigir la ejecución si quisieras secuestrar el punto
de entrada de este binario?

Q-1.4 (predicción) Si lees `e_entry` de la cabecera pero saltas
directamente a esa dirección sin asegurarte de que esté realmente cubierta
por un segmento `PT_LOAD` cargado, ¿qué pasa?

Q-1.5 (predicción) Dos segmentos `PT_LOAD` terminan con rangos de
`p_vaddr` superpuestos después de que añades uno nuevo sin recalcular los
offsets — ¿qué se rompe, y cuándo te das cuenta: al empaquetar, o en
tiempo de ejecución?

Q-1.6 (abierta/diseño) ¿Por qué ELF separa los "segmentos" (para el
cargador) de las "secciones" (para el enlazador/depurador) en lugar de
usar una sola tabla para ambos?

Respuestas: `ANSWERS.md` § 1
