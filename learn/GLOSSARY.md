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

### interface
**Plain:** an agreed set of named operations that more than one concrete
implementation can provide — the caller only needs to know the names and
meanings, not which implementation is behind them.
**Introduced in:** § 3
**You'll see it in:** `open`/`read`/`write`/`close` (an interface you
already use); the format-backend design for ELF64/ELF32/Mach-O

### function pointer
**Plain:** a variable that holds the address of a function instead of
data, so which function actually runs can change at runtime.
**Introduced in:** § 3
**You'll see it in:** every field of `format_backend_t`

### dispatch table
**Plain:** a struct whose fields are all function pointers, one struct
value per format, used to pick which implementation runs without an `if`
chain. Sometimes called a **vtable** (**v**irtual **table**) in C++.
**Introduced in:** § 3
**You'll see it in:** `elf64_backend` / `elf32_backend` / `macho_backend`

### format backend
**Plain:** one complete implementation of the format interface — the four
functions that handle everything the rest of the program needs, for
exactly one binary format.
**Introduced in:** § 3
**You'll see it in:** the ELF64, ELF32, and Mach-O implementations

### O_CREAT / O_TRUNC / O_WRONLY
**Stands for:** Open flags — CREATe / TRUNCate / WRite ONLY
**Plain:** `open()` flags: create the file if missing, truncate it to
zero length if it exists, and open it write-only.
**Introduced in:** § 4
**You'll see it in:** opening `woody` for writing

### file mode bits
**Plain:** the permission bits (e.g. `0755`) given to `open()`'s third
argument when `O_CREAT` is used — who can read, write, and execute the
new file.
**Introduced in:** § 4
**You'll see it in:** `woody` needing its execute bit set to actually run

### short write
**Plain:** `write()` returning fewer bytes written than requested, with
no error — rare on a local file, but must be handled in a loop, never
assumed away.
**Introduced in:** § 4
**You'll see it in:** the write loop that produces `woody`

### struct-of-pointers pattern
**Plain:** the same idea as a dispatch table, named for what it is in plain
C — a struct whose fields are pointers to functions rather than to data.
**Introduced in:** § 3
**You'll see it in:** `format_backend_t`

### mmap
**Stands for:** Memory MAP
**Plain:** asks the kernel directly for a block of memory (or a view onto
a file) at a size and permission you choose, instead of going through
`malloc`'s heap.
**Introduced in:** § 5
**You'll see it in:** the mmap/mprotect demo, the loader's own handling of
`PT_LOAD` segments (§ 1)

### MAP_PRIVATE / MAP_ANONYMOUS
**Plain:** `mmap` flags: `MAP_PRIVATE` keeps writes private to this
process; `MAP_ANONYMOUS` means there's no file behind the mapping, just a
bare block of memory.
**Introduced in:** § 5
**You'll see it in:** the mmap/mprotect demo

### PROT_READ / PROT_WRITE / PROT_EXEC
**Stands for:** PROTection flags — Read / Write / eXecute
**Plain:** the permissions `mmap` and `mprotect` set on a region of
memory, combined with `|`.
**Introduced in:** § 5
**You'll see it in:** every `mmap`/`mprotect` call, `p_flags` (§ 1)

### page
**Plain:** the fixed-size chunk (usually 4096 bytes on x86_64) that
memory protection actually operates in — permissions apply to whole
pages, never arbitrary byte ranges.
**Introduced in:** § 5
**You'll see it in:** `mmap`'s length rounding, `mprotect`'s address
alignment requirement

### mprotect
**Stands for:** Memory PROTECT
**Plain:** changes the permission flags of an already-mapped region, in
place, without unmapping it.
**Introduced in:** § 5
**You'll see it in:** the decrypt stub toggling a segment between
writable and executable

### munmap
**Plain:** releases a mapping back to the kernel — the inverse of
`mmap`, the same discipline as `free` or `close`.
**Introduced in:** § 5
**You'll see it in:** cleaning up after the mmap/mprotect demo

### W^X
**Stands for:** Write XOR eXecute
**Plain:** a hardening policy that refuses to let one mapping be both
writable and executable at the same time.
**Introduced in:** § 5
**You'll see it in:** why the decrypt stub can't just leave memory `RWX`
permanently

### symmetric encryption
**Plain:** a scheme where the same key both encrypts and decrypts, unlike
public/private-key (asymmetric) schemes.
**Introduced in:** § 6
**You'll see it in:** the pack-time encrypt / stub-time decrypt pair

### XOR cipher
**Plain:** encryption built on bitwise XOR — `(x ^ k) ^ k == x` for any
`x` and `k`, which is the entire reason this project's cipher is
reversible.
**Introduced in:** § 6
**You'll see it in:** both the encrypt and decrypt step — the same
operation, run twice

### stream cipher
**Plain:** a cipher that encrypts data one byte at a time against a
continuously-produced pseudorandom stream, rather than fixed-size blocks.
**Introduced in:** § 6
**You'll see it in:** this project's whole-file XOR pass

### keystream
**Plain:** the stream of pseudorandom bytes, as long as the data being
encrypted, that gets XOR'd against it.
**Introduced in:** § 6
**You'll see it in:** derived from the key, never stored directly

### PRNG
**Stands for:** Pseudo-Random Number Generator
**Plain:** an algorithm producing a statistically-random-looking sequence
that's entirely determined by its starting seed — same seed, same
sequence, every time.
**Introduced in:** § 6
**You'll see it in:** deriving the keystream from the key

### seed
**Plain:** the starting state fed into a PRNG; determines its entire
output sequence.
**Introduced in:** § 6
**You'll see it in:** the key's bytes, used to seed the keystream PRNG

### getrandom
**Plain:** a Linux syscall that fills a buffer with genuinely
unpredictable bytes from the kernel, reached here via `syscall` since
that's what the subject's allowed-function list permits.
**Introduced in:** § 6
**You'll see it in:** generating the random key when none is supplied

### roundtrip
**Plain:** encrypting then immediately decrypting, and checking the
result matches the original exactly — the correctness test for any
reversible transform.
**Introduced in:** § 6
**You'll see it in:** the § 6 checkpoint

### parameterised key
**Plain:** the bonus requirement that the key can be supplied on the
command line instead of always being randomly generated.
**Introduced in:** § 6
**You'll see it in:** the CLI argument parsing, DECISIONS.md
