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
