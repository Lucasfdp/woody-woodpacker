# Glossary — woody-woodpacker

Terms in the order they were introduced. Plain language first, then
precise. Identifiers keep their English names.

---

### ELF
**Stands for:** Executable and Linkable Format
**Plain:** the file format Linux uses for compiled programs and libraries —
a structured recipe telling the OS what to load into memory and where to
start running.
**Precise:** a binary format with a fixed header, a table of "segments"
(what to load at runtime) and a table of "sections" (how the file is
organised for linking/debugging).
**Introduced in:** § 1
**You'll see it in:** `readelf`, `objdump`, every Linux executable/`.so`

### magic number
**Plain:** the first few bytes of a file, used purely to say "this is an
ELF file" before anything else is trusted or parsed.
**Precise:** ELF's magic number is the 4 bytes `0x7F 'E' 'L' 'F'`.
**Introduced in:** § 1
**You'll see it in:** file-format detection code, the `file` command

### e_ident
**Stands for:** ELF identification
**Plain:** the first chunk of the ELF header — the magic number plus a few
flags describing the file's basic shape (32 vs 64-bit, byte order, etc.).
**Introduced in:** § 1
**You'll see it in:** `Elf64_Ehdr` / `Elf32_Ehdr` in `<elf.h>`

### EI_CLASS
**Stands for:** ELF Identification — Class
**Plain:** one byte inside `e_ident` that says whether this is a 32-bit or
64-bit ELF file.
**Introduced in:** § 1
**You'll see it in:** `<elf.h>` (`ELFCLASS32`, `ELFCLASS64`)

### e_type
**Plain:** says what *kind* of ELF file this is — an executable, a shared
library, a relocatable object file, etc.
**Introduced in:** § 1
**You'll see it in:** `<elf.h>` (`ET_EXEC`, `ET_DYN`, `ET_REL`)

### e_entry
**Plain:** the virtual address where execution begins — the very first
instruction the CPU runs when the OS loads this program.
**Introduced in:** § 1
**You'll see it in:** `readelf -h`, this is what woody_woodpacker patches

### ABI
**Stands for:** Application Binary Interface
**Plain:** the agreement about how compiled code is laid out and talks to
the OS/other compiled code — register usage, calling convention, syscall
numbers, struct layout.
**Introduced in:** § 1
**You'll see it in:** "System V AMD64 ABI" (libasm's calling convention)

### program header
**Plain:** an entry in the table that tells the OS *loader* what to map
into memory and with what permissions, before the program runs at all.
**Precise:** distinct from a *section header*, which is for
linking/debugging tools, not the runtime loader.
**Introduced in:** § 1
**You'll see it in:** `readelf -l`, `Elf64_Phdr`

### segment vs section
**Plain:** a **segment** is a runtime concept — "map these bytes into
memory, here, with these permissions." A **section** is a build-time/
linking concept — "this named chunk of the file is the symbol table" or
"this one is `.text`." Several sections can live inside one segment.
**Introduced in:** § 1
**You'll see it in:** `readelf -l` (segments) vs `readelf -S` (sections)

### PT_LOAD
**Stands for:** Program header Type — LOAD
**Plain:** the specific program-header type that means "load this chunk of
the file into memory and run/read/write it" — the one that actually makes
code and data appear in the running process.
**Introduced in:** § 1
**You'll see it in:** `readelf -l`, `<elf.h>`

### p_vaddr / p_offset / p_filesz / p_memsz
**Plain:** four fields on a program header — where it goes in memory
(`p_vaddr`), where its bytes start in the file (`p_offset`), how many bytes
to copy from the file (`p_filesz`), and how much memory to reserve for it
(`p_memsz`, which can be larger than `p_filesz` for zero-filled space).
**Introduced in:** § 1
**You'll see it in:** `Elf64_Phdr` in `<elf.h>`

### p_flags (PF_R / PF_W / PF_X)
**Stands for:** Program header — Flags (Read / Write / eXecute)
**Plain:** the permissions the OS applies to this segment's memory once
loaded — can it be read, written, executed.
**Introduced in:** § 1
**You'll see it in:** `readelf -l`, `mprotect`'s `PROT_*` flags (§ 5)

### defensive programming
**Plain:** writing code that assumes its input might be wrong, malicious,
or malformed, and fails safely instead of trusting it.
**Introduced in:** § 2
**You'll see it in:** every "never crash" requirement in this subject

### fail closed
**Plain:** when something unexpected happens, refuse and exit cleanly
rather than guessing and continuing.
**Introduced in:** § 2
**You'll see it in:** woody_woodpacker's architecture/format rejection path

### SIGSEGV
**Stands for:** SIGnal — SEGmentation Violation
**Plain:** the kernel telling your process it touched memory it isn't
allowed to touch — a crash.
**Introduced in:** § 2
**You'll see it in:** the exact failure this project must never produce

### errno / perror / strerror
**Plain:** `errno` is a number the OS sets after a failed call, saying
*why* it failed. `strerror` turns that number into a human-readable
message; `perror` prints that message for you, prefixed with your own
text.
**Introduced in:** § 2
**You'll see it in:** every allowed-function list in this subject

### EOF
**Stands for:** End Of File
**Plain:** the signal that there's no more data to read from a file.
**Introduced in:** § 2
**You'll see it in:** `read()` returning 0
