# Respuestas — woody-woodpacker

Leer después de intentarlo. Las respuestas explican el razonamiento, no
solo el hecho.

## Sección 1

**A-1.1** Los cuatro bytes son `0x7F`, `'E'`, `'L'`, `'F'` — en ese orden
exacto, en el offset 0 (`e_ident[0..3]`). Cualquier archivo que no empiece
exactamente así debe rechazarse de inmediato como "no es un archivo ELF",
antes de analizar nada más.

**A-1.2** `e_ident[EI_CLASS]` (byte número 4). El valor `1` = `ELFCLASS32`
(32 bits), el valor `2` = `ELFCLASS64` (64 bits). Esto es lo primero que
woody_woodpacker necesita comprobar, para decidir qué organización de
estructura (`Elf32_*` o `Elf64_*`) usar para todo lo demás.

**A-1.3** `e_entry`, en la propia cabecera ELF (no en una cabecera de
programa). Es la dirección virtual a la que salta la CPU primero.
Modificar este valor — y asegurarse de que tu código inyectado esté
realmente mapeado en esa dirección mediante un segmento `PT_LOAD` — es el
mecanismo central detrás de la modificación del punto de entrada.

**A-1.4** La CPU intentaría ejecutar instrucciones en una dirección virtual
que nunca se mapeó en el proceso — ningún segmento `PT_LOAD` la cubre. El
kernel genera un fallo de página que no puede resolver, lo cual se
manifiesta como `SIGSEGV`: un fallo (crash), exactamente lo que este
enunciado prohíbe. `e_entry` solo significa algo en relación con lo que
las cabeceras de programa realmente cargan.

**A-1.5** Los segmentos que el cargador mapee se superpondrán en memoria
virtual — los bytes de un segmento sobrescriben silenciosamente a los del
otro (o viceversa) una vez cargados ambos, corrompiendo el que pierda. Una
implementación ingenua escribirá alegremente un archivo ELF "con pinta
válida" con dos entradas `PT_LOAD` superpuestas en el momento de empaquetar
— esto no se detecta entonces. Solo se nota en tiempo de ejecución, como
un fallo o un comportamiento extraño difícil de rastrear — por eso la
superposición hay que comprobarla explícitamente al elegir dónde inyectar
el stub, nunca asumir que "simplemente funcionará".

**A-1.6** Sirven a dos públicos distintos con ciclos de vida distintos. El
cargador, al arrancar el proceso, solo necesita "mapea estos bytes, aquí,
con estos permisos" — no necesita nombres de símbolos ni información de
depuración, y llevarlos desperdiciaría tiempo de carga y memoria en cada
arranque de proceso. El enlazador y las herramientas de depuración, en
tiempo de compilación/inspección, necesitan una estructura mucho más rica
(secciones con nombre, tablas de reubicación, tablas de símbolos) que
sería equipaje inútil para que el cargador la analice en cada ejecución.
Separarlos mantiene la ruta rápida (carga) mínima y la ruta rica
(enlazado/depuración) tan detallada como necesite. Por eso también se
puede "stripear" las secciones de un binario sin romper su capacidad de
ejecutarse — el cargador nunca las miró.

## Sección 2

**A-2.1** "Fallar cerrado" significa que el comportamiento por defecto
cuando algo es incierto o inválido es rechazar y detenerse, no continuar y
esperar que salga bien. La diferencia con "envolver todo en comprobaciones
de error después de escribir el código" es arquitectónica: el diseño que
falla cerrado decide, de antemano, cuál es el estado seguro por defecto
antes de que una comprobación haya pasado (p. ej. "no hemos confirmado que
esto sea ELF, así que no hemos tocado el archivo de salida en absoluto"),
en lugar de escribir primero el camino feliz y añadir `if`s defensivos
después — un estilo que tiende a dejar huecos, porque solo se parchean los
fallos que se te ocurrieron.

**A-2.2** Antes de escribir un solo byte del archivo de salida — idealmente
antes incluso de abrirlo para escritura. Si empiezas a modificar/crear
`woody` y solo entonces descubres que la entrada no era ELF x86_64 válido,
has dejado en disco un archivo a medio escribir y roto en el caso de
fallo, posiblemente con descriptores todavía abiertos. "Nunca fallar"
también implica, de forma implícita, "nunca dejar desorden" — valida por
completo antes de producir ninguna salida.

**A-2.3** En Linux, `open()` devuelve `-1` al fallar y fija `errno` — no
lanza una excepción, y nada te impide usar ese `-1` como si fuera un
descriptor de archivo real. Si lo pasas directamente a `read()`, el kernel
rechaza el `-1` como inválido, así que `read()` también devuelve `-1` —
probablemente no obtendrás un fallo (segfault) inmediato, pero continuarás
silenciosamente con datos basura/vacíos en vez de fallar con un mensaje
claro, lo cual es peor de depurar que un crash. Alguien que venga de un
lenguaje basado en excepciones podría esperar, erróneamente, que un
`open` fallido abortara automáticamente — en Linux nunca lo hace;
comprobar los valores de retorno siempre depende de ti.

**A-2.4** Es una fuga de recursos real en general, pero inofensiva aquí en
concreto porque llamas a `exit()` justo después — el sistema operativo
cierra automáticamente todos los descriptores abiertos de un proceso al
salir, por cualquier motivo. Aun así es mejor estilo cerrar con `close()`
explícitamente (autodocumentado, y evita un hábito que te puede morder en
un programa de vida más larga), pero no es el tipo de fallo que causa un
crash o corrupción en este caso — vale la pena saber la diferencia entre
"descuidado" y "realmente roto".
