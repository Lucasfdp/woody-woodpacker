---
section: 2
slug: defensive-error-handling
tier: T2
status: not-started
prereqs: [1]
terms: [defensive programming, fail closed, SIGSEGV, errno / perror / strerror, EOF]
---

# Sección 2 — Nunca fallar: comprobaciones defensivas antes que nada

**Nivel: T2** — esto no es un mecanismo que se aprende una vez, es una
disciplina que da forma a cada checkpoint desde aquí en adelante.
**Podrás:** validar la entrada por completo, en el orden correcto, antes
de tocar el archivo de salida — y explicar exactamente por qué importa el
orden.

## La idea

La regla que suena más difícil del enunciado es en realidad la más
sencilla de cumplir una vez que la internalizas: "en ningún caso tu
programa puede terminar de forma inesperada." No "manejar la mayoría de
errores" — *nunca fallar*, con ninguna entrada, incluidas entradas
hostiles o sin sentido.

El truco no es escribir más comprobaciones de error por todas partes. Es
decidir, antes de escribir el camino feliz, cuál es el *valor por
defecto* de tu programa cuando todavía no sabe si algo es seguro. Si el
valor por defecto es "asumo que está bien a menos que detecte
específicamente un problema," se te escaparán casos que no se te
ocurrieron. Si el valor por defecto es "asumo que es un problema hasta que
haya confirmado específicamente que está bien," también capturas los
casos que no se te ocurrieron — porque la carga de la prueba está
invertida.

## Los nombres para esto

**Defensive programming (programación defensiva)** — escribir código que
asume que su entrada puede estar mal formada, ser incorrecta o
malintencionada, y falla de forma segura en lugar de confiar en ella. No
es paranoia gratuita — es reconocer que `woody_woodpacker` lo va a
ejecutar un evaluador intentando específicamente romperlo.

**Fail closed (fallar cerrado)** — cuando pasa algo inesperado, rechazar y
salir limpiamente en lugar de adivinar y continuar. Lo opuesto, "fallar
abierto," sería continuar igualmente y esperar que salga bien — así es
como se obtiene un programa que "funciona la mayoría de las veces" y de
vez en cuando corrompe la salida o falla con entradas que nadie probó.

**SIGSEGV** — **SIG**nal, **SEG**mentation **V**iolation (violación de
segmentación). El kernel diciéndole a tu proceso que tocó memoria a la
que no tiene permiso de acceder. Este es el fallo literal que el
enunciado prohíbe, y suele ser el resultado directo del escenario de
Q-1.4 de la § 1 (saltar a, o leer/escribir, una dirección que nunca se
validó).

**errno / perror / strerror** — `errno` es un número que el sistema
operativo fija tras una llamada *fallida*, diciendo por qué falló — solo
lo compruebas después de que una función te haya dicho (mediante su
valor de retorno) que algo salió mal. `strerror` convierte ese número en
una cadena legible. `perror` imprime esa cadena directamente, con el
texto que le pases delante — p. ej. `perror("open")` tras un `open()`
fallido imprime algo como `open: No such file or directory`.

**EOF** — **E**nd **O**f **F**ile (fin de archivo). La señal de que ya no
hay más datos que leer. En una lectura exitosa pero vacía, `read()`
devuelve `0` — esto no es un error (`errno` no se fija), pero tampoco es
"obtuve los bytes que pedí," así que necesita su propia rama, no solo una
comprobación `if (resultado == -1)`.

## Cómo funciona realmente

Para `woody_woodpacker`, el orden de validación que te mantiene fallando
cerrado:

1. **Antes de abrir nada para escritura:** valida el número de
   argumentos, luego abre el archivo *de entrada* solo lectura y comprueba
   el valor de retorno.
2. **Antes de confiar en ningún byte de la entrada como datos
   estructurados:** lee lo justo para comprobar el número mágico (§ 1).
   Si está mal, imprime el error y llama a `exit()` — no has creado nada
   todavía, así que no hay nada que limpiar.
3. **Antes de asumir que el archivo es de la arquitectura que soportas:**
   comprueba `EI_CLASS` (y más adelante, para el trabajo de abstracción de
   formatos de la § 3, de qué familia de formato se trata siquiera). Aquí
   es donde se imprime el mensaje exacto del enunciado — `File
   architecture not suported. x86_64 only` — y solo aquí, antes de que
   exista un solo byte de `woody`.
4. **Solo después de que todo lo anterior haya pasado** abres el archivo
   de salida para escritura. Desde este punto, si algo va mal, también
   necesitas limpiar (cerrar descriptores, y — una vez llegues a
   secciones posteriores — `munmap` lo que esté mapeado) antes de salir,
   porque ahora *sí* hay un archivo parcial o un recurso del que ocuparte.

Esta es la forma general de cada checkpoint posterior también: validar
primero, mutar solo una vez completada la validación, limpiar ante
cualquier fallo después de ese punto.

## Trampas conocidas

- **Comprobar `errno` sin comprobar primero el valor de retorno.**
  `errno` solo tiene sentido inmediatamente después de una llamada que te
  *dijo* (mediante su valor de retorno) que falló. Comprobarlo tras una
  llamada que tuvo éxito puede mostrar un valor obsoleto de algún fallo
  anterior.
- **Tratar que `read()` devuelva `0` como un error.** No lo es — es EOF,
  una condición normal y esperada, especialmente cuando lees un archivo
  en trozos y llegas al final.
- **Validar en el orden equivocado** — p. ej. abrir el archivo de salida
  para escritura antes de haber confirmado que la entrada es válida. Si
  la validación falla después, ya has creado/truncado un archivo que
  ahora tienes que borrar explícitamente o dejar como basura.
- **Asumir un modelo mental estilo Windows** — en Linux, nada lanza una
  excepción automáticamente por ti. Cada función respaldada por una
  syscall que puede fallar, fallará *en silencio* (solo un valor de
  retorno) a menos que lo compruebes tú mismo.

## Checkpoint

Extiende el programa de lectura de ELF de la § 1 para que:
1. Imprima el mensaje exacto del enunciado y salga limpiamente (sin
   crash, sin salida parcial) cuando se le dé un archivo que no sea en
   absoluto un ELF válido.
2. Imprima el mensaje exacto del enunciado y salga limpiamente cuando se
   le dé un archivo ELF válido que no sea `ELFCLASS64`.
3. Maneje un archivo ausente/illegible (ruta incorrecta, sin permisos) de
   la misma manera — comprueba el valor de retorno de `open()`, usa
   `perror`, sal limpiamente.
4. Haga todo esto *antes* de intentar abrir o crear ningún archivo de
   salida.

Pruébalo con: un archivo de texto renombrado para parecer un binario, un
binario ELF de 32 bits válido (si puedes construir uno — ver § 9), una
ruta que no existe, y un archivo al que le hayas hecho `chmod 000`.

## Preguntas

Q-2.1 (recuerdo) ¿Qué significa "fallar cerrado," y en qué se diferencia
de simplemente envolver todo en comprobaciones de error después de
escribir el código?

Q-2.2 (aplicación) El enunciado da un mensaje de error exacto para un
binario que no sea x86_64. ¿En qué punto del flujo de tu programa tiene
que pasar esa comprobación — antes o después de haber empezado ya a
modificar el archivo de salida? ¿Por qué importa el orden?

Q-2.3 (predicción) Si `open()` falla y no compruebas su valor de retorno
antes de pasar el resultado a `read()`, ¿qué pasa realmente en Linux,
frente a lo que podría asumir alguien que viene de un lenguaje basado en
excepciones?

Q-2.4 (predicción) Tu programa detecta con éxito una entrada mal formada
pero llama a `exit()` sin hacer `close()` del descriptor de archivo que
abrió. ¿Es esto realmente un fallo, para un programa que sale
inmediatamente después? ¿Por qué sí o por qué no?

Respuestas: `ANSWERS.md` § 2
