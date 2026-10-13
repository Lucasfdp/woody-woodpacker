---
section: 6
slug: encryption-design
tier: T2
status: not-started
prereqs: [2]
terms: [cifrado simétrico, cifrado XOR, cifrado de flujo, keystream, PRNG, semilla, getrandom, roundtrip, clave parametrizada]
---

# Sección 6 — Diseño del cifrado de flujo, aleatoriedad, clave parametrizada

**Depth: T2** — el mecanismo es simple; la disciplina alrededor del
manejo de la clave es donde los proyectos de este nivel realmente pierden
puntos.
**Serás capaz de:** diseñar e implementar un par de cifrado/descifrado
que sea demostrablemente reversible, generar una clave aleatoria
suficientemente segura cuando no se da ninguna, y aceptar una clave dada
por línea de comandos en su lugar — produciendo exactamente los bytes que
`woody_woodpacker` revuelve en tiempo de empaquetado y que el stub
desenreda en tiempo de ejecución.

## La idea

El cifrado aquí no necesita ser irrompible — el enunciado descarta
explícitamente un cifrado trivial (un simple desplazamiento ROT/César)
pero no pide criptografía de nivel de investigación. Lo que realmente
necesita es un esquema con una sola propiedad, y solo una, que importa de
forma absoluta: aplicar la *misma operación* a los *mismos datos* con la
*misma clave*, dos veces, debe devolver exactamente los bytes
originales. Todo lo demás — cuán "aleatorio" parece el resultado, cuán
resistente es al análisis — es un extra en el que puedes gastar más o
menos esfuerzo, pero la reversibilidad no es negociable, porque un
descifrado que no reproduce el binario original byte a byte es un
programa empaquetado que se corrompe a sí mismo antes incluso de
arrancar.

La operación más simple con esa propiedad es XOR. Si aplicas XOR a un
byte con cierto valor una vez, y luego aplicas XOR al *resultado* con ese
mismo valor otra vez, recuperas el byte original — siempre, para
cualquier valor. Ese único hecho es todo el mecanismo: genera un flujo de
bytes de la misma longitud que los datos (un **keystream**), aplica XOR
al texto plano contra él una vez para cifrar, y aplica XOR al texto
cifrado contra el *mismo* keystream otra vez, más tarde, para descifrar.
No hace falta entender ni interpretar nada del texto plano en sí para que
esto funcione — por eso se aplica de forma uniforme a un binario entero,
cabeceras incluidas.

## Los nombres de esto

**Cifrado simétrico** — un esquema donde se usa la misma clave tanto para
cifrar como para descifrar, a diferencia de los esquemas *asimétricos*
(pares de clave pública/privada) que usan una clave distinta para cada
dirección. Este proyecto es simétrico: la clave que empaqueta el binario
es exactamente la clave que el stub incrustado debe usar para
desempaquetarlo.

**Cifrado XOR** — cifrado construido sobre la operación bit a bit XOR
(`texto_cifrado = texto_plano ^ byte_del_keystream`), apoyándose en el
hecho de que `(x ^ k) ^ k == x` para cualquier `x` y `k`. Toda la
reversibilidad del cifrado de este proyecto descansa sobre esta única
identidad a nivel de bit.

**Cifrado de flujo** — un cifrado que cifra los datos una unidad (aquí,
un byte) a la vez contra un flujo producido continuamente de bytes
pseudoaleatorios, en lugar de cifrar bloques de tamaño fijo de una sola
vez (un *cifrado de bloque*, la otra familia principal — no lo que estás
construyendo). El **keystream** es ese flujo producido; necesita ser al
menos tan largo como los datos que estás cifrando.

**PRNG** — **P**seudo-**R**andom **N**umber **G**enerator (generador de
números pseudoaleatorios). Un algoritmo que produce una secuencia de
números que *parece* estadísticamente aleatoria pero está enteramente
determinada por su estado inicial — la **semilla**. La misma semilla,
pasada por el mismo PRNG, siempre produce exactamente la misma secuencia.
Este determinismo no es un defecto aquí, es todo el punto: es lo que
permite que el stub regenere el keystream idéntico en tiempo de
ejecución a partir de solo la clave, sin que el keystream en sí se
almacene nunca en ningún sitio.

**`getrandom`** — una syscall de Linux que llena un búfer con bytes de la
propia fuente de aleatoriedad del kernel — genuinamente impredecible, a
diferencia de un PRNG semillado con algo adivinable (la hora actual, por
ejemplo). La lista de funciones permitidas del enunciado incluye
`syscall` directamente, así que esto se alcanza como
`syscall(SYS_getrandom, buf, len, 0)` en lugar de llamar a una función
envoltorio que el enunciado no permitió explícitamente. Esto es lo que
genera la *clave* en sí (una semilla corta y genuinamente aleatoria) — el
keystream mucho más largo derivado *de* esa clave puede venir entonces de
un PRNG determinista ordinario, porque ahí el determinismo es un
requisito, no una debilidad.

**Roundtrip** (prueba de ida y vuelta) — cifrar datos y luego descifrar
inmediatamente el resultado, y comprobar que la salida es idéntica byte a
byte a la entrada original. Esta es la prueba de corrección para
cualquier transformación reversible, y el checkpoint de esta sección en
concreto.

**Clave parametrizada** — el requisito de bonus de que la clave no
siempre se genera aleatoriamente; el usuario puede en su lugar
proporcionar su propia clave como argumento de línea de comandos, y el
programa debe usar *esa* clave tanto para la generación como (de forma
implícita, vía el stub incrustado) para el descifrado, en lugar de llamar
a `getrandom` en absoluto.

## Cómo funciona realmente

1. **Generar o aceptar la clave.** Si no se dio ningún argumento de
   clave, llama a `getrandom` vía `syscall` para N bytes (elige una
   longitud fija, p. ej. 16) e imprímela en stdout exactamente como
   exige el enunciado. Si *sí* se dio un argumento de clave, usa esos
   bytes directamente — valida su longitud/formato de forma defensiva (la
   disciplina de § 2 aplica también aquí: un argumento de clave mal
   formado sigue siendo una entrada que no debe hacer fallar el
   programa).

2. **Derivar un keystream a partir de la clave, no usar la clave en sí
   como keystream.** La clave es corta (16 bytes); los datos que se
   cifran son el binario de entrada completo, casi seguro mucho más
   largo. Siembra un PRNG pequeño y determinista con los bytes de la
   clave (p. ej. combínalos en un entero semilla, o usa los bytes de la
   clave para inicializar un generador simple como un LCG o un xorshift
   mezclado con la clave), y luego extrae de él tantos bytes de
   keystream como de largo tengan los datos. Esto es lo que evita que la
   salida tenga la propia longitud de la clave como un período visible y
   repetido (ver Trampas conocidas).

3. **XOR.** `para i en 0..len: cifrado[i] = plano[i] ^ keystream[i]`. Esa
   es toda la transformación, en ambas direcciones — cifrar y descifrar
   son *literalmente la misma llamada de función*, una de las razones por
   las que los cifrados de flujo basados en XOR son tan comunes
   precisamente para este tipo de uso embebido que debe ser simple de
   implementar dos veces.

4. **El stub de descifrado (§§ 7–8) debe regenerar el keystream
   idéntico en tiempo de ejecución.** Eso significa que la *clave en
   sí* — no el keystream, la clave — tiene que viajar con el binario
   empaquetado de alguna forma (incrustada como datos que el stub lee, o
   pasada por algún otro mecanismo que diseñes), y el stub ejecuta
   exactamente la misma lógica de siembra del PRNG que usaste en tiempo
   de empaquetado. Si el tiempo de empaquetado y el stub alguna vez
   discrepan sobre cómo se deriva el keystream de la clave, el
   descifrado produce basura en silencio en lugar de los bytes
   originales — sin error, solo un `woody` que falla en el momento en
   que intenta ejecutar su propio código "descifrado."

## Trampas conocidas

- **Usar los bytes de la clave directamente como keystream, repetidos
  para llenar la longitud de los datos.** Esto técnicamente satisface
  "reversible" — aplicar XOR con un patrón repetido de 16 bytes sigue
  siendo revertido aplicando XOR con el mismo patrón otra vez — pero
  produce un período visible: abre la salida en un editor hexadecimal y
  cualquier estructura repetida en el binario original (las tiradas
  largas de bytes cero son comunes en archivos ELF) aparece como *la
  clave misma*, repetida, a la vista. Un keystream derivado (paso 2 de
  arriba) evita esto al no repetirse en ningún período fijo ligado a la
  longitud de la clave.
- **Regenerar una clave "aleatoria" dentro del stub de descifrado en
  lugar de reutilizar la del tiempo de empaquetado.** El stub no puede
  llamar a `getrandom` y esperar recibir de vuelta los *mismos* bytes —
  la aleatoriedad, por definición, no es reproducible. La clave tiene que
  llevarse hacia adelante desde el tiempo de empaquetado de forma
  explícita, nunca re-derivarse.
- **Olvidar que la clave debe imprimirse en stdout exactamente una vez,
  en tiempo de empaquetado, incluso en el caso del bonus de clave
  parametrizada.** El requisito del enunciado de imprimir la clave no
  desaparece solo porque el usuario la haya proporcionado él mismo.
- **Tratar "no trivial" como "necesita ser criptográficamente seguro."**
  Gastar esfuerzo endureciendo este cifrado contra criptoanálisis real es
  esfuerzo gastado en el lugar equivocado para este proyecto — el nivel
  exigido por el enunciado es "no un simple desplazamiento César", no
  "sobrevive una auditoría de seguridad." El trabajo de abstracción de
  formatos (§ 3) y la inyección en el punto de entrada (§ 7) son donde
  vive la dificultad real de este proyecto.

## Checkpoint

Escribe una prueba de ida y vuelta (roundtrip) de cifrado/descifrado
independiente (esto puede convertirse en código real del proyecto, no es
descartable): dada una clave (aleatoria vía `getrandom`-`syscall`, o
proporcionada), deriva un keystream, aplica XOR a un búfer de prueba
(unos cientos de bytes, idealmente incluyendo algunas tiradas largas de
bytes repetidos para forzar la trampa del "período visible") para
producir el texto cifrado, confirma que el texto cifrado difiere del
texto plano, y luego aplica XOR al texto cifrado con un keystream
re-derivado de la misma clave y confirma que el resultado es idéntico
byte a byte al texto plano original. Ejecútalo tanto con una clave
recién generada como con una proporcionada a mano.

## Preguntas

Q-6.1 (recordar) ¿Por qué aplicar XOR a los mismos datos con el mismo
keystream dos veces devuelve los datos originales? ¿Qué propiedad de la
operación XOR hace esto verdadero para *cualquier* valor de keystream, no
solo valores especiales?

Q-6.2 (aplicación) El enunciado exige que la clave se imprima en stdout
en tiempo de empaquetado. Por separado, el stub de descifrado necesita
esa misma clave en tiempo de ejecución para regenerar el keystream.
Nombra la única cosa que debe viajar desde el tiempo de empaquetado hasta
dentro del binario empaquetado para que esto funcione, y explica por qué
imprimir la clave en stdout no satisface ese requisito por sí solo.

Q-6.3 (predicción) Tu keystream es simplemente la clave de 4 bytes
repetida para llenar un texto plano de 400 bytes. El texto plano tiene
una tirada de 64 bytes cero en medio (común en archivos ELF reales —
relleno). ¿Cómo se ve esa tirada en el texto cifrado, y por qué ocurre
eso específicamente porque el keystream se repite con un período fijo y
corto?

Q-6.4 (predicción) Tu stub de descifrado llama a `getrandom` él mismo en
tiempo de ejecución, razonando "simplemente generaré una clave nueva de
la misma forma que lo hizo el tiempo de empaquetado." ¿Cuál es el
resultado real cuando intenta descifrar el binario, y por qué "de la
misma forma" no significa "los mismos bytes"?

Respuestas: `ANSWERS.md` § 6
