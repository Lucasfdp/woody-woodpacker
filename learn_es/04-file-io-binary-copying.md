---
section: 4
slug: file-io-binary-copying
tier: T1
status: not-started
prereqs: [1, 3]
terms: [O_CREAT / O_TRUNC / O_WRONLY, bits de modo de archivo, escritura corta]
---

# Sección 4 — Copia exacta de archivos byte a byte

**Nivel: T1** — ya lees un archivo entero en memoria en `main.c`; esta
sección es la otra mitad que falta, escribir uno, más los dos detalles
fáciles de hacer mal.
**Podrás:** producir `woody`, una copia byte a byte del binario de
entrada, como un nuevo archivo ejecutable con los permisos correctos — la
base que cada sección posterior modifica en vez de reconstruir.

## La idea

Ya sabes leer un archivo entero a memoria — `main.c` lo hace con `open` +
`fstat` + `malloc` + `read`. Escribir uno es la misma forma al revés, pero
hay dos cosas que suelen morder a quien no lo ha hecho antes: el archivo
que crees necesita decir *en el momento de crearse* quién puede
ejecutarlo, y una sola llamada a `write()` no garantiza escribir todos los
bytes que le pediste.

## Los nombres para esto

**`O_CREAT` / `O_TRUNC` / `O_WRONLY`** — flags que se pasan a `open()`,
combinados con `|`. Flag de **o**pen: **CREAT**e, crea el archivo si no
existe. Flag de **o**pen: **TRUNC**ate, lo trunca a longitud cero primero
si ya existía (para que bytes sobrantes de una ejecución anterior no
sobrevivan debajo de tu contenido nuevo, posiblemente más corto). Flag de
**o**pen: **W**rite **ONLY**, solo escritura — no vas a volver a leer este
archivo en la misma ejecución del programa.

**Bits de modo de archivo** — cuando se usa `O_CREAT`, `open()` recibe un
tercer argumento, los bits de permiso con los que se crea el archivo nuevo
(p. ej. `0755`): quién puede leerlo, escribirlo y — crítico aquí —
ejecutarlo. Si se olvida, `woody` existe pero el sistema se niega a
ejecutarlo, sin que el mensaje de error conecte eso con "olvidaste el
argumento de modo."

**Escritura corta** — el valor de retorno de `write()` es cuántos bytes
escribió realmente, que puede ser *menos* de lo que pediste, incluso sin
error. Es raro con un archivo local y un buffer pequeño, pero la regla de
"nunca debe crashear" del subject significa que lo compruebas, no que lo
asumes.

## Cómo funciona realmente

1. Abre la salida: `open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0755)`,
   comprueba el valor de retorno como cualquier otro `open()` de § 2.
2. Escribe el buffer que ya tienes en memoria, en un bucle que sigue hasta
   que se ha escrito cada byte:
   ```c
   ssize_t written = 0;
   while (written < total_size)
   {
       ssize_t n = write(fd, buf + written, total_size - written);
       if (n < 0)
       {
           perror("write");
           /* limpieza: cerrar ambos fd; puede que haya que borrar este archivo */
           exit(1);
       }
       written += n;
   }
   ```
3. Cierra ambos descriptores. En esta etapa `woody` debería ser idéntico
   byte a byte a la entrada — ejecuta `diff original woody` (o `cmp`) para
   confirmarlo, antes de que ninguna sección posterior empiece a cambiar
   bytes de verdad. Esta copia-identidad es la base sobre la que se
   construye cada checkpoint posterior: una vez que existan el cifrado
   (§ 6) y el parcheo del punto de entrada (§ 7), siempre estarás
   comparando contra "esto todavía se ejecuta exactamente como esta copia
   ya verificada."

## Trampas conocidas

- **Olvidar el argumento de modo, u olvidar que necesita el bit de
  ejecución.** `open(path, O_CREAT | O_WRONLY, 0644)` crea un archivo que
  nadie puede ejecutar — `./woody` falla entonces con "Permission denied,"
  que parece un bug en tu lógica de empaquetado pero es un solo dígito en
  el argumento de modo.
- **Tratar el valor de retorno de `write()` como "todo o un error."** Un
  simple `if (write(...) < 0) { error }` sin bucle descarta en silencio la
  cola del archivo en una escritura corta, produciendo un `woody` truncado
  — y truncado-pero-sin-crashear es exactamente el tipo de bug que buscan
  los evaluadores del subject.
- **No truncar un `woody` existente de una ejecución anterior.** Sin
  `O_TRUNC`, empaquetar un binario más pequeño después de uno más grande
  deja bytes antiguos más allá del nuevo final del contenido, corrompiendo
  el resultado de una forma que no se nota hasta que algo intenta
  ejecutarlo.

## Checkpoint

Extiende tu programa para que, tras la validación ELF de §§ 1–2, abra
`woody` para escritura con los flags y el modo correctos, escriba todo el
buffer de entrada de vuelta en un bucle seguro frente a escrituras cortas,
y cierre ambos descriptores. Verifica con `diff <entrada> woody` que la
salida es idéntica byte a byte, y `chmod +x woody && ./woody` confirma que
es realmente ejecutable y corre como el original.

## Preguntas

Q-4.1 (recuerdo) ¿Qué hace `O_TRUNC`, y qué observarías si empaquetaras un
binario de 10 KB, y luego uno de 2 KB a la misma ruta de salida sin él?

Q-4.2 (aplicación) Escribe la llamada a `open()` para crear `woody`, con
los flags correctos y un modo que lo haga ejecutable solo por su
propietario.

Q-4.3 (predicción) Tu bucle de escritura hace `written += n` pero
escribiste `n = write(...)` como `int n` en vez de `ssize_t n`, sobre un
buffer de más de 2 GB. ¿Cuál es el modo de fallo realista, y por qué
existe `ssize_t` como tipo distinto de `int` o `size_t`?

Respuestas: `ANSWERS.md` § 4
