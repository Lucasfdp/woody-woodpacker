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

## Sección 3

**A-3.1** Cada campo guarda la dirección de una función — no un valor,
un trozo de comportamiento. `parse_header` en el backend de ELF64 apunta a
código que conoce `Elf64_Ehdr`; en el backend de Mach-O apunta a código
completamente distinto que conoce la cabecera de Mach-O. Un struct que
guardara valores de cabecera directamente (p. ej. `e_entry` como campo)
solo podría representar nunca la forma de datos de un formato — volverías
a cadenas de `if` para interpretarlo correctamente. Guardar *operaciones*
en vez de *datos* es lo que permite que un mismo tipo de struct represente
tres formatos binarios sin relación entre ellos.

**A-3.2**
```c
typedef struct {
    int  (*parse_header)(uint8_t *buf, size_t len, void *out_info);
    long (*find_injection_point)(void *info);
    void (*patch_entry)(void *info, long new_entry);
    int  (*write_output)(int fd, void *info);
} format_backend_t;
```
Lo importante es que cada instancia de backend use firmas *idénticas* —
ese es el contrato en el que confía el resto del programa para llamar a
través del struct sin importarle qué backend tiene.

**A-3.3** Llamar a través de un puntero a función nulo (o basura, si nunca
se inicializó a cero) es comportamiento indefinido a nivel de CPU — el
programa intenta saltar la ejecución a lo que sea que haya en ese campo,
que para un struct sin inicializar podría ser cualquier valor sobrante de
la pila, no necesariamente `0`. Una *desreferencia* de puntero nulo sobre
un puntero de datos al menos falla de forma fiable en una dirección baja y
predecible (`0x0`), dando un crash reconocible. Un puntero a función sin
inicializar puede saltar a cualquier parte — posiblemente a memoria que
parece válida pero que no es código en absoluto, produciendo
comportamiento extraño y difícil de reproducir en lugar de un crash
limpio. Por esto exactamente cada struct de backend necesita sus cuatro
campos asignados, explícitamente, antes del primer uso.

**A-3.4** Te dice que `void *info` está filtrando la propia debilidad de
la abstracción: quien llama tiene que saber, de alguna forma y por
formato, qué hay realmente detrás de ese puntero y cuánta memoria puede
tocar — lo cual significa que la interfaz "genérica" no es genérica de
verdad, es solo sin tipo. Una unión etiquetada (un struct con un campo
explícito `enum format_tag` más una unión de los structs de información
específicos de cada formato) al menos te permitiría comprobar en tiempo de
ejecución "esto es la variante Mach-O" en vez de confiar en que cada
backend recuerda qué puso ahí. En cualquier caso, que Mach-O necesite
información que ELF nunca necesitó es señal de que las cuatro operaciones
podrían necesitar un quinto parámetro común a todos los formatos (p. ej.
"tamaño del contexto específico del formato") en vez de pasarlo de
contrabando por un puntero opaco.

## Sección 4

**A-4.1** `O_TRUNC` pone la longitud del archivo a 0 antes de cualquier
escritura nueva — así el contenido nuevo reemplaza por completo al
antiguo. Sin él, escribir un binario de 2 KB sobre una ruta que antes tenía
uno de 10 KB solo sobrescribiría los primeros 2 KB; los bytes de 2 KB a
10 KB del archivo antiguo seguirían ahí después, ya que `write()` solo
extiende un archivo hacia delante desde su longitud actual y solo
sobrescribe lo que realmente escribe encima. El resultado: `woody`
ocuparía 10 KB en disco, con los últimos 8 KB siendo basura obsoleta de una
ejecución anterior — un binario empaquetado sutilmente corrupto, de una
forma que un `diff` contra la entrada *actual* detectaría, pero una
comprobación de tamaño descuidada no.

**A-4.2** `int fd = open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0700);` —
`0700` concede lectura, escritura y ejecución solo al propietario, nada al
grupo ni a otros. (`0755` también es una respuesta razonable si
"ejecutable por su propietario" se leyó como "como mínimo, incluyendo a
otros" — el punto clave es que el bit de ejecución del propietario está
presente en ambos casos.)

**A-4.3** En una escritura de más de ~2 GB, `int` (habitualmente de 32
bits, máximo ~2.100 millones) no puede representar el conteo de bytes que
`write()` reporta realmente si una sola llamada devuelve un valor cercano
o por encima de `INT_MAX` — más realista aún, la aritmética alrededor
(`written += n` donde `written` también está declarado demasiado estrecho,
o un límite de bucle calculado como `int`) se desborda o trunca en
silencio, y el bucle puede parar antes de tiempo (salida truncada,
exactamente la trampa de § 4) o no terminar nunca, según cómo caiga
exactamente el desbordamiento. `ssize_t` existe como versión con signo
de `size_t` precisamente para que funciones como `write()` y `read()`
puedan devolver o bien un *conteo de bytes* (necesitando el mismo ancho
que `size_t`, para representar tamaños grandes) o bien `-1` para "error" —
un `size_t` sin signo no puede representar `-1` con sentido, y un `int`
normal es demasiado estrecho en muchas plataformas para archivos grandes.
Usar el tipo de retorno exacto que documenta una syscall, en vez de
cualquier tipo que compile, es precisamente el tipo de cosa que no importa
hasta que un archivo cruza cierto umbral de tamaño, y entonces produce
corrupción de datos difícil de conectar con la causa.

## Sección 5

**A-5.1** `mmap` te permite elegir la combinación exacta de permisos con
la que empieza una región de memoria — incluyendo `PROT_EXEC` — y
`mprotect` te permite cambiar esa combinación más tarde sobre un mapeo
ya existente. `malloc` te da memoria que siempre es solo lectura/
escritura, sin ningún mecanismo para hacerla ejecutable después. Un
programa cuyo trabajo entero es inyectar código que luego debe
ejecutarse necesita ese control; `malloc` nunca se diseñó para darlo.

**A-5.2** Porque una vez que el mapeo es solo `PROT_EXEC` (sin
`PROT_WRITE`), escribir en él es exactamente el escenario de SIGSEGV que
cubre § 2 — la CPU/kernel rechazará la escritura y fallará. Debes
escribir tus bytes mientras el mapeo todavía es escribible, y luego
cambiar los permisos una vez, después de que el contenido ya sea
correcto. Invertir el orden significa que la escritura para insertar el
byte `0xC3` falla antes de que llegue a ocurrir.

**A-5.3** El mapeo real se redondea hacia arriba a una página completa
(4096 bytes en x86_64) aunque solo se pidieron 10 — `mmap` nunca da
páginas parciales. Escribir en el desplazamiento de byte 4096 es escribir
en la *siguiente* página, que esta llamada nunca mapeó; eso es un acceso
a memoria no mapeada y falla con `SIGSEGV`, exactamente el escenario de
§ 2, aunque "pareciera" que debería estar dentro del vecindario de una
asignación de 10 bytes.

**A-5.4** La llamada falla directamente, típicamente con `EINVAL` —
`mprotect` requiere que su argumento de dirección ya esté alineado a
página y no lo redondea por ti. La asimetría con la longitud de `mmap`
(que sí se redondea hacia arriba) existe porque la longitud de `mmap`
solo tiene una interpretación razonable ("al menos esto, redondear no
cuesta nada"), mientras que si `mprotect` redondeara hacia abajo una
*dirección* desalineada cambiaría en silencio *qué* página recibe el
cambio de protección — potencialmente una página que quien llama no
pretendía tocar en absoluto, que es exactamente el tipo de
comportamiento silencioso y sorpresivo que `mprotect` se niega a
arriesgar.

## Sección 6

**A-6.1** `(x ^ k) ^ k == x` para cada bit de cada byte, porque aplicar
XOR a un bit con el mismo valor dos veces siempre vuelve al bit
original: si el bit era `0`, XOR con `k` lo cambia para igualar el bit de
`k`, y XOR con `k` otra vez lo devuelve justo a donde estaba; si era `1`,
el mismo razonamiento aplica al revés. Esto se cumple para *cualquier*
valor de `k`, que es exactamente por qué el keystream puede ser cualquier
secuencia pseudoaleatoria — la reversibilidad no depende de que el
keystream sea especial, solo de usar el *mismo* las dos veces.

**A-6.2** La clave en sí tiene que viajar desde el tiempo de
empaquetado hasta dentro del binario empaquetado — no el keystream, y no
simplemente "haber sido impresa en stdout." Imprimirla en stdout le dice
al *usuario* la clave para que la anote; no hace nada por el stub que
está dentro del archivo binario, que no tiene acceso a lo que el usuario
vio en su terminal durante el empaquetado. El stub necesita la clave
incrustada como datos que pueda leer directamente (o pasada de alguna
otra forma que diseñes), para poder volver a ejecutar la misma lógica de
derivación del keystream en tiempo de ejecución, independientemente de
lo que mostrara stdout.

**A-6.3** La tirada de 64 bytes cero se convierte en la clave de 4 bytes
repetida 16 veces consecutivas, porque aplicar XOR a `0x00` con
cualquier valor `k` devuelve `k` mismo (`0 ^ k == k`) — así que cada byte
"cero" de esa tirada simplemente se convierte en el byte del keystream
que hubiera en esa posición, y como el keystream es la clave de 4 bytes
repitiéndose con un período de 4, la tirada muestra la clave, literal,
repitiéndose — a la vista de cualquiera que abra el archivo en un editor
hexadecimal y note la repetición.

**A-6.4** El descifrado produce basura — no un error, solo bytes
incorrectos, porque la clave "aleatoria" recién generada por el stub con
`getrandom` está estadísticamente garantizado que será distinta de la
usada en tiempo de empaquetado (eso es lo que significa aleatoriedad: no
reproducible). "De la misma forma" se refiere a que el *procedimiento*
(llamar a `getrandom`, obtener unos bytes) es idéntico, pero la *salida*
del procedimiento es distinta cada vez por diseño — la reproducibilidad
requiere llevar el valor real de la clave hacia adelante de forma
explícita, nunca volver a invocar el paso de generación aleatoria
esperando el mismo resultado.
