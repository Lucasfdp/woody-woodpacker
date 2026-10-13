---
section: 5
slug: mmap-mprotect
tier: T2
status: not-started
prereqs: [2, 4]
terms: [mmap, MAP_PRIVATE / MAP_ANONYMOUS, PROT_READ / PROT_WRITE / PROT_EXEC, página, mprotect, munmap, W^X]
---

# Sección 5 — Mapeo de memoria y permisos de página

**Profundidad: T2** — este mecanismo es la base del stub de descifrado,
no una llamada puntual que se usa una vez y se olvida.
**Serás capaz de:** pedir al sistema operativo un bloque de memoria con
permisos exactos, y cambiar esos permisos en tiempo de ejecución — el
mismo movimiento que hace el stub de descifrado sobre sí mismo cuando
pasa una página de código de "ejecutable" a "escribible, para poder
descifrar dentro de ella" y vuelta.

## La idea

Ya sabes cómo obtener memoria con `malloc()` — pero `malloc` te da memoria
para *datos*: legible y escribible, nunca ejecutable, y no tienes
ninguna opción sobre eso. Para la mayor parte de este proyecto eso está
bien. Pero el stub de descifrado (§§ 7–8) tiene que hacer algo para lo
que `malloc` nunca se diseñó: tomar un trozo de memoria que actualmente
contiene *código* que la CPU tiene permiso de ejecutar, hacerlo
temporalmente *escribible* para que el stub pueda descifrar bytes dentro
de él, y luego volver a hacerlo *ejecutable* antes de saltar a él — todo
dentro del mismo proceso en ejecución, sin fallar.

Eso requiere dos cosas que `malloc` no puede dar: memoria con una
combinación de permisos que elijas tú mismo, y la capacidad de cambiar
esa combinación después de que la memoria ya exista. Ambas son
operaciones a nivel de sistema operativo, no comodidades de la biblioteca
C — por eso están en la lista de funciones permitidas del enunciado, por
su nombre.

## Los nombres de esto

**`mmap`** — **M**emory **MAP** (mapear memoria). Pide al kernel
directamente un bloque de memoria (o una vista sobre un archivo) con un
tamaño y permisos que tú especificas, en lugar de pasar por el heap de
`malloc`. Ya has usado conceptualmente `mmap` respaldado por archivo
cuando en § 1 se habló de que el loader "mapea" los segmentos
`PT_LOAD` — es exactamente el mismo mecanismo, solo que hecho por ti
mismo a mano, en vez de hecho por el sistema operativo al arrancar un
programa.

**`MAP_PRIVATE` / `MAP_ANONYMOUS`** — dos flags que pasarás juntos para la
demo desacartable y, de forma distinta, para la memoria inyectada real
más adelante. `MAP_PRIVATE` significa que las escrituras en este mapeo
son privadas de tu proceso, nunca se comparten con un archivo u otros
procesos. `MAP_ANONYMOUS` significa que no hay ningún archivo detrás de
este mapeo — estás pidiendo un bloque de memoria desnudo, respaldado por
nada más que sí mismo, que es justo de lo que están hechas internamente
las páginas anónimas del heap de `malloc`.

**`PROT_READ` / `PROT_WRITE` / `PROT_EXEC`** — flags de **PROT**ección,
los permisos que `mmap` y `mprotect` establecen, combinados con `|`
exactamente igual que los flags `O_*` de § 4. `PROT_READ`: se puede leer.
`PROT_WRITE`: se puede escribir. `PROT_EXEC`: la CPU tiene permiso de
buscar y ejecutar instrucciones aquí. Estos tres se pueden combinar casi
en cualquier mezcla — `PROT_READ | PROT_EXEC` sin escritura es el estado
normal y seguro para código; todo el truco del stub consiste en alternar
entre eso y `PROT_READ | PROT_WRITE`.

**Página** — el trozo de tamaño fijo (casi siempre 4096 bytes en x86_64)
en el que realmente opera la protección de memoria. No puedes pedirle al
hardware que haga ejecutables *17 bytes* — solo páginas completas. Toda
dirección y longitud de `mmap`/`mprotect` o bien ya está alineada a
página, o el kernel la redondea, y acertar con esto mal es el error más
común de esta sección.

**`mprotect`** — **M**emory **PROTECT** (proteger memoria). Cambia los
flags de permiso de una región *ya mapeada*, en el sitio, sin desmapearla
ni volver a mapearla. Esta es la llamada que usa el stub de descifrado
para alternar un segmento entre "escribible, estoy descifrando dentro de
ti" y "ejecutable, ahora corre."

**`munmap`** — el inverso de `mmap`: libera un mapeo de vuelta al kernel.
Todo `mmap` que no esté respaldando algo que piensas ejecutar durante el
resto de la vida del proceso necesita un `munmap` correspondiente, la
misma disciplina que `malloc`/`free` u `open`/`close`.

**W^X** (**W**rite **X**OR e**X**ecute — escritura XOR ejecución) — una
política de endurecimiento, aplicada por algunos kernels/configuraciones
de hardware, que se niega a permitir que un mismo mapeo sea a la vez
escribible *y* ejecutable (`PROT_WRITE | PROT_EXEC` juntos se rechaza o se
elimina en silencio). Es la razón directa por la que el stub no puede
simplemente dejarlo todo en `RWX` permanentemente y saltarse el baile de
`mprotect` — en un sistema endurecido, ese mapeo nunca se permitiría
existir en primer lugar.

## Cómo funciona realmente

Para la demo desacartable (no forma parte del entregable real — ver
Checkpoint):

```c
void *mem = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                  MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
/* escribe una secuencia de instrucciones diminuta en mem, p. ej. un solo
   byte `ret` */
mprotect(mem, 4096, PROT_READ | PROT_EXEC);
void (*f)(void) = (void (*)(void))mem;
f();            /* salta a mem, ejecuta `ret`, vuelve — sin fallo */
munmap(mem, 4096);
```

Los argumentos que vale la pena notar:
- `NULL` como primer argumento: "no me importa qué dirección, elige el
  kernel."
- `4096`: una página — la unidad más pequeña que es segura de pedir y que
  `mmap` garantiza alineada por sí misma.
- El orden *escribir-luego-proteger-luego-ejecutar* no es opcional:
  escribes tus bytes mientras el mapeo todavía es escribible, cambias los
  permisos solo una vez que los bytes que necesitas ya están ahí, y nunca
  intentas escribir en una región después de que sea solo `PROT_EXEC` —
  esa escritura fallará por sí misma.

El proyecto real no hace `mmap` de memoria nueva para el stub en tiempo
de *empaquetado* — escribe los bytes directamente en el archivo de
salida. Donde `mmap`/`mprotect` importan de verdad es *en tiempo de
ejecución*, dentro del propio binario empaquetado: cuando `woody` arranca,
su stub inyectado está en un segmento que el loader mapeó como
`PROT_READ | PROT_EXEC` (porque eso es lo que decía el program header que
escribiste en tiempo de empaquetado). Antes de que el stub pueda
descifrar el resto del binario *en el sitio*, esa región objetivo
necesita ser escribible — lo que significa que el propio stub tiene que
llamar a `mprotect` sobre la memoria de su propio proceso, en tiempo de
ejecución, exactamente como la demo de arriba, antes de aplicar XOR a
ningún byte para devolverlo a su forma original.

## Trampas conocidas

- **Dirección o longitud no alineada a página.** La longitud de `mmap` se
  redondea automáticamente hacia arriba a una página completa, pero la
  *dirección* que recibe `mprotect` ya tiene que estar alineada a
  página — pasar una dirección que meramente está "dentro" de la página
  correcta, no al principio, falla directamente (`EINVAL`) en lugar de
  redondear por ti.
- **Asumir que puedes saltarte la demo y hacer `mprotect` sobre memoria
  arbitraria del heap de `malloc`.** A veces puede funcionar, porque el
  heap resulta estar respaldado por páginas por debajo — pero no
  controlas dónde cae el puntero de `malloc` respecto a un límite de
  página, así que estarías confiando en un accidente. Usa `mmap` cuando
  necesites controlar la protección; para eso existe exactamente.
- **Escribir en memoria después de que ya sea solo `PROT_EXEC`.** Una vez
  que has llamado `mprotect(..., PROT_READ | PROT_EXEC)`, una escritura
  posterior a esa misma memoria es exactamente el escenario de SIGSEGV de
  § 2 — necesitas la escritura *y* el cambio de protección en el orden
  correcto, cada vez que alternas.
- **Esperar que `RWX` (los tres flags a la vez) siempre funcione sin
  más.** A menudo funciona en una configuración por defecto de Linux —
  pero confiar en ello es frágil, y es justo la combinación que una
  política de endurecimiento (W^X) está diseñada específicamente para
  rechazar. Escribir el stub de forma que nunca necesite escritura y
  ejecución simultáneas es la versión robusta de este mecanismo.

## Checkpoint

**Demo desacartable — no forma parte del entregable, código claramente
separado.** Escribe un pequeño archivo C independiente (fuera de
`srcs/`, p. ej. en una ubicación de pruebas) que: haga `mmap` de una
página anónima `PROT_READ | PROT_WRITE`, escriba un único byte `0xC3`
(la instrucción x86_64 `ret`) al principio de ella, llame a `mprotect`
para pasarla a `PROT_READ | PROT_EXEC`, convierta el puntero a un puntero
a función `void (*)(void)` y lo llame, y luego haga `munmap`. Confirma
que corre sin fallo y sin aviso de `valgrind` sobre ejecutar desde
memoria inválida o liberada. Esto es puramente para generar confianza en
el mecanismo antes de que §§ 7–8 pidan usar el mismo patrón sobre el stub
de verdad.

## Preguntas

Q-5.1 (recordar) ¿Qué puede darte `mmap` que `malloc` no puede, y por qué
importa eso para un programa cuyo trabajo es hacer ejecutable código
inyectado?

Q-5.2 (aplicación) En la demo de arriba, ¿por qué la llamada a `mprotect`
hacia `PROT_READ | PROT_EXEC` tiene que ocurrir *después* de haber escrito
el byte `0xC3`, no antes? ¿Qué sale mal si se invierte el orden?

Q-5.3 (predicción) Haces `mmap(NULL, 10, ...)`, pidiendo 10 bytes. La
llamada tiene éxito y devuelve una dirección no nula. ¿Cuál es el tamaño
utilizable real del mapeo que te dieron, y qué pasa si escribes en el
desplazamiento de byte 4096 de él?

Q-5.4 (predicción) Llamas a `mprotect(ptr + 8, 4096, PROT_READ |
PROT_EXEC)` donde `ptr` es una dirección alineada a página de un `mmap`
anterior. ¿Qué pasa, y por qué `mprotect` no simplemente redondea
`ptr + 8` hacia abajo al límite de página más cercano de la misma forma
que la longitud de `mmap` se redondea hacia arriba?

Respuestas: `ANSWERS.md` § 5
