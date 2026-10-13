# Glosario — woody-woodpacker

Términos en el orden en que se introdujeron. Primero lenguaje llano, luego
preciso. Los identificadores mantienen su nombre en inglés.

---

### ELF
**Significa:** Executable and Linkable Format (formato ejecutable y
enlazable)
**Llano:** el formato de archivo que usa Linux para programas y librerías
compiladas — una receta estructurada que le dice al sistema operativo qué
cargar en memoria y por dónde empezar a ejecutar.
**Preciso:** un formato binario con una cabecera fija, una tabla de
"segmentos" (qué cargar en tiempo de ejecución) y una tabla de "secciones"
(cómo está organizado el archivo para enlazado/depuración).
**Introducido en:** § 1
**Lo verás en:** `readelf`, `objdump`, todo ejecutable/`.so` de Linux

### magic number
**Llano:** los primeros bytes de un archivo, usados solo para decir "esto
es un archivo ELF" antes de analizar o confiar en nada más.
**Preciso:** el número mágico de ELF son los 4 bytes `0x7F 'E' 'L' 'F'`.
**Introducido en:** § 1
**Lo verás en:** código de detección de formato, el comando `file`

### e_ident
**Significa:** ELF identification (identificación ELF)
**Llano:** el primer trozo de la cabecera ELF — el número mágico más unos
flags que describen la forma básica del archivo (32 o 64 bits, orden de
bytes, etc.).
**Introducido en:** § 1
**Lo verás en:** `Elf64_Ehdr` / `Elf32_Ehdr` en `<elf.h>`

### EI_CLASS
**Significa:** ELF Identification — Class (clase)
**Llano:** un byte dentro de `e_ident` que dice si este archivo ELF es de
32 o 64 bits.
**Introducido en:** § 1
**Lo verás en:** `<elf.h>` (`ELFCLASS32`, `ELFCLASS64`)

### e_type
**Llano:** indica *qué tipo* de archivo ELF es esto — un ejecutable, una
librería compartida, un archivo objeto reubicable, etc.
**Introducido en:** § 1
**Lo verás en:** `<elf.h>` (`ET_EXEC`, `ET_DYN`, `ET_REL`)

### e_entry
**Llano:** la dirección virtual donde empieza la ejecución — la primera
instrucción que ejecuta la CPU cuando el sistema operativo carga este
programa.
**Introducido en:** § 1
**Lo verás en:** `readelf -h`; esto es lo que woody_woodpacker modifica

### ABI
**Significa:** Application Binary Interface (interfaz binaria de
aplicación)
**Llano:** el acuerdo sobre cómo se organiza el código compilado y cómo se
comunica con el sistema operativo/otro código compilado — uso de
registros, convención de llamada, números de syscall, organización de
estructuras.
**Introducido en:** § 1
**Lo verás en:** "System V AMD64 ABI" (la convención de llamada de libasm)

### program header
**Llano:** una entrada en la tabla que le dice al *cargador* del sistema
operativo qué mapear en memoria y con qué permisos, antes de que el
programa se ejecute siquiera.
**Preciso:** distinto de una *section header*, que es para herramientas de
enlazado/depuración, no para el cargador en tiempo de ejecución.
**Introducido en:** § 1
**Lo verás en:** `readelf -l`, `Elf64_Phdr`

### segment vs section
**Llano:** un **segmento** es un concepto de tiempo de ejecución —
"mapea estos bytes en memoria, aquí, con estos permisos." Una **sección**
es un concepto de tiempo de compilación/enlazado — "este trozo con nombre
del archivo es la tabla de símbolos" o "este es `.text`." Varias secciones
pueden vivir dentro de un solo segmento.
**Introducido en:** § 1
**Lo verás en:** `readelf -l` (segmentos) vs `readelf -S` (secciones)

### PT_LOAD
**Significa:** Program header Type — LOAD
**Llano:** el tipo específico de cabecera de programa que significa "carga
este trozo del archivo en memoria y ejecútalo/léelo/escríbelo" — el que
realmente hace que el código y los datos aparezcan en el proceso en
ejecución.
**Introducido en:** § 1
**Lo verás en:** `readelf -l`, `<elf.h>`

### p_vaddr / p_offset / p_filesz / p_memsz
**Llano:** cuatro campos de una cabecera de programa — dónde va en memoria
(`p_vaddr`), dónde empiezan sus bytes en el archivo (`p_offset`), cuántos
bytes copiar del archivo (`p_filesz`), y cuánta memoria reservar
(`p_memsz`, que puede ser mayor que `p_filesz` para espacio relleno de
ceros).
**Introducido en:** § 1
**Lo verás en:** `Elf64_Phdr` en `<elf.h>`

### p_flags (PF_R / PF_W / PF_X)
**Significa:** Program header — Flags (Read / Write / eXecute)
**Llano:** los permisos que el sistema operativo aplica a la memoria de
este segmento una vez cargado — si se puede leer, escribir, ejecutar.
**Introducido en:** § 1
**Lo verás en:** `readelf -l`, los flags `PROT_*` de `mprotect` (§ 5)

### defensive programming
**Llano:** escribir código que asume que su entrada puede estar mal
formada, ser incorrecta o malintencionada, y falla de forma segura en
lugar de confiar en ella.
**Introducido en:** § 2
**Lo verás en:** todo requisito de "nunca debe fallar" de este enunciado

### fail closed
**Llano:** cuando pasa algo inesperado, rechazar y salir limpiamente en
lugar de adivinar y continuar.
**Introducido en:** § 2
**Lo verás en:** la ruta de rechazo de arquitectura/formato de
woody_woodpacker

### SIGSEGV
**Significa:** SIGnal — SEGmentation Violation (violación de segmentación)
**Llano:** el kernel diciéndole a tu proceso que tocó memoria a la que no
tiene permiso de acceder — un fallo (crash).
**Introducido en:** § 2
**Lo verás en:** exactamente el fallo que este proyecto nunca debe producir

### errno / perror / strerror
**Llano:** `errno` es un número que pone el sistema operativo tras una
llamada fallida, diciendo *por qué* falló. `strerror` convierte ese número
en un mensaje legible; `perror` imprime ese mensaje por ti, con tu propio
texto delante.
**Introducido en:** § 2
**Lo verás en:** toda lista de funciones permitidas de este enunciado

### EOF
**Significa:** End Of File (fin de archivo)
**Llano:** la señal de que ya no hay más datos que leer de un archivo.
**Introducido en:** § 2
**Lo verás en:** `read()` devolviendo 0

### interfaz
**Llano:** un conjunto acordado de operaciones con nombre que más de una
implementación concreta puede proporcionar — quien llama solo necesita
conocer los nombres y su significado, no qué implementación hay detrás.
**Introducido en:** § 3
**Lo verás en:** `open`/`read`/`write`/`close` (una interfaz que ya usas);
el diseño de backend de formato para ELF64/ELF32/Mach-O

### puntero a función
**Llano:** una variable que guarda la dirección de una función en vez de
un dato, de modo que qué función se ejecuta realmente puede cambiar en
tiempo de ejecución.
**Introducido en:** § 3
**Lo verás en:** cada campo de `format_backend_t`

### tabla de despacho
**Llano:** un struct cuyos campos son todos punteros a función, un valor
de struct por formato, usado para elegir qué implementación se ejecuta sin
una cadena de `if`. A veces llamada **vtable** (**v**irtual **table**,
tabla virtual) en contextos de C++.
**Introducido en:** § 3
**Lo verás en:** `elf64_backend` / `elf32_backend` / `macho_backend`

### backend de formato
**Llano:** una implementación completa de la interfaz de formato — las
cuatro funciones que manejan todo lo que el resto del programa necesita,
para exactamente un formato binario.
**Introducido en:** § 3
**Lo verás en:** las implementaciones de ELF64, ELF32 y Mach-O

### O_CREAT / O_TRUNC / O_WRONLY
**Significa:** Open flags — CREATe / TRUNCate / WRite ONLY
**Llano:** flags de `open()`: crea el archivo si no existe, lo trunca a
longitud cero si ya existe, y lo abre solo para escritura.
**Introducido en:** § 4
**Lo verás en:** abrir `woody` para escritura

### bits de modo de archivo
**Llano:** los bits de permiso (p. ej. `0755`) que se dan al tercer
argumento de `open()` cuando se usa `O_CREAT` — quién puede leer, escribir
y ejecutar el archivo nuevo.
**Introducido en:** § 4
**Lo verás en:** que `woody` necesite su bit de ejecución para poder
correr

### escritura corta
**Llano:** `write()` devolviendo menos bytes de los pedidos, sin error —
raro en un archivo local, pero hay que manejarlo con un bucle, nunca
asumir que no pasa.
**Introducido en:** § 4
**Lo verás en:** el bucle de escritura que produce `woody`

### patrón struct-de-punteros
**Llano:** la misma idea que una tabla de despacho, nombrada por lo que es
en C puro — un struct cuyos campos son punteros a funciones en vez de a
datos.
**Introducido en:** § 3
**Lo verás en:** `format_backend_t`

### mmap
**Significa:** Memory MAP (mapear memoria)
**Sencillo:** pide al kernel directamente un bloque de memoria (o una
vista sobre un archivo) con un tamaño y permisos que tú eliges, en lugar
de pasar por el heap de `malloc`.
**Introducido en:** § 5
**Lo verás en:** la demo de mmap/mprotect, el manejo que hace el propio
loader de los segmentos `PT_LOAD` (§ 1)

### MAP_PRIVATE / MAP_ANONYMOUS
**Sencillo:** flags de `mmap`: `MAP_PRIVATE` mantiene las escrituras
privadas a este proceso; `MAP_ANONYMOUS` significa que no hay ningún
archivo detrás del mapeo, solo un bloque de memoria desnudo.
**Introducido en:** § 5
**Lo verás en:** la demo de mmap/mprotect

### PROT_READ / PROT_WRITE / PROT_EXEC
**Significa:** flags de PROTección — Read / Write / eXecute
**Sencillo:** los permisos que `mmap` y `mprotect` establecen sobre una
región de memoria, combinados con `|`.
**Introducido en:** § 5
**Lo verás en:** toda llamada a `mmap`/`mprotect`, `p_flags` (§ 1)

### página
**Sencillo:** el trozo de tamaño fijo (normalmente 4096 bytes en x86_64)
en el que realmente opera la protección de memoria — los permisos se
aplican a páginas completas, nunca a rangos de bytes arbitrarios.
**Introducido en:** § 5
**Lo verás en:** el redondeo de longitud de `mmap`, el requisito de
alineación de dirección de `mprotect`

### mprotect
**Significa:** Memory PROTECT (proteger memoria)
**Sencillo:** cambia los flags de permiso de una región ya mapeada, en el
sitio, sin desmapearla.
**Introducido en:** § 5
**Lo verás en:** el stub de descifrado alternando un segmento entre
escribible y ejecutable

### munmap
**Sencillo:** libera un mapeo de vuelta al kernel — el inverso de
`mmap`, la misma disciplina que `free` o `close`.
**Introducido en:** § 5
**Lo verás en:** limpiar después de la demo de mmap/mprotect

### W^X
**Significa:** Write XOR eXecute (escritura XOR ejecución)
**Sencillo:** una política de endurecimiento que se niega a permitir que
un mapeo sea a la vez escribible y ejecutable.
**Introducido en:** § 5
**Lo verás en:** por qué el stub de descifrado no puede dejar la memoria
en `RWX` permanentemente

### cifrado simétrico
**Sencillo:** un esquema donde la misma clave cifra y descifra, a
diferencia de los esquemas de clave pública/privada (asimétricos).
**Introducido en:** § 6
**Lo verás en:** el par cifrado en tiempo de empaquetado / descifrado en
el stub

### cifrado XOR
**Sencillo:** cifrado construido sobre XOR bit a bit — `(x ^ k) ^ k == x`
para cualquier `x` y `k`, que es toda la razón por la que el cifrado de
este proyecto es reversible.
**Introducido en:** § 6
**Lo verás en:** tanto el paso de cifrado como el de descifrado — la
misma operación, ejecutada dos veces

### cifrado de flujo
**Sencillo:** un cifrado que cifra los datos un byte a la vez contra un
flujo pseudoaleatorio producido continuamente, en lugar de bloques de
tamaño fijo.
**Introducido en:** § 6
**Lo verás en:** el paso de XOR sobre el archivo completo de este
proyecto

### keystream
**Sencillo:** el flujo de bytes pseudoaleatorios, tan largo como los
datos que se cifran, que se aplica con XOR contra ellos.
**Introducido en:** § 6
**Lo verás en:** derivado de la clave, nunca almacenado directamente

### PRNG
**Significa:** Pseudo-Random Number Generator (generador de números
pseudoaleatorios)
**Sencillo:** un algoritmo que produce una secuencia que parece
estadísticamente aleatoria pero está enteramente determinada por su
semilla inicial — misma semilla, misma secuencia, siempre.
**Introducido en:** § 6
**Lo verás en:** derivar el keystream a partir de la clave

### semilla
**Sencillo:** el estado inicial que se da a un PRNG; determina toda su
secuencia de salida.
**Introducido en:** § 6
**Lo verás en:** los bytes de la clave, usados para sembrar el PRNG del
keystream

### getrandom
**Sencillo:** una syscall de Linux que llena un búfer con bytes
genuinamente impredecibles del kernel, alcanzada aquí vía `syscall` ya
que es lo que permite la lista de funciones permitidas del enunciado.
**Introducido en:** § 6
**Lo verás en:** generar la clave aleatoria cuando no se proporciona
ninguna

### roundtrip
**Sencillo:** cifrar y luego descifrar inmediatamente, comprobando que el
resultado coincide exactamente con el original — la prueba de corrección
de cualquier transformación reversible.
**Introducido en:** § 6
**Lo verás en:** el checkpoint de § 6

### clave parametrizada
**Sencillo:** el requisito de bonus de que la clave se pueda dar por
línea de comandos en lugar de generarse siempre aleatoriamente.
**Introducido en:** § 6
**Lo verás en:** el parseo de argumentos de línea de comandos,
DECISIONS.md
