# ELF Header Cheatsheet — Ehdr / Phdr / Shdr

Quick reference for the three header structures in a 64-bit ELF file.
All types below are the `Elf64_*` variants (`<elf.h>`).

---

## 1. Ehdr — `Elf64_Ehdr` (the ELF header)

One per file, always at offset 0. Tells the loader (and you) how to find
everything else.

| Field | Size | Meaning |
|---|---|---|
| `e_ident[16]` | 16 bytes | Magic (`0x7f 'E' 'L' 'F'`), class (32/64-bit), endianness, ELF version, OS ABI |
| `e_type` | 2 | `ET_EXEC` (fixed-address executable), `ET_DYN` (PIE/shared object), `ET_REL` (relocatable `.o`), `ET_CORE` |
| `e_machine` | 2 | Target ISA — `EM_X86_64` for x86_64 |
| `e_version` | 4 | ELF version (always 1 in practice) |
| `e_entry` | 8 | **Virtual address of the entry point** — where execution starts |
| `e_phoff` | 8 | File offset of the **program header table** |
| `e_shoff` | 8 | File offset of the **section header table** |
| `e_flags` | 4 | Processor-specific flags (usually 0 on x86_64) |
| `e_ehsize` | 2 | Size of this header (should equal `sizeof(Elf64_Ehdr)`) |
| `e_phentsize` | 2 | Size of **one** program header entry |
| `e_phnum` | 2 | **Number** of program header entries |
| `e_shentsize` | 2 | Size of **one** section header entry |
| `e_shnum` | 2 | **Number** of section header entries |
| `e_shstrndx` | 2 | Index into the section table of the section-name string table |

**Key relationship:** program header table size = `e_phnum * e_phentsize`
(found at `e_phoff`). Same pattern for sections (`e_shnum * e_shentsize` at
`e_shoff`).

---

## 2. Phdr — `Elf64_Phdr` (program header / segment)

One entry per **segment** — what the *loader* cares about at `execve()`
time. Sections don't matter here; the kernel only reads Phdrs.

| Field | Size | Meaning |
|---|---|---|
| `p_type` | 4 | What kind of segment (see table below) |
| `p_flags` | 4 | `PF_R` (4), `PF_W` (2), `PF_X` (1) — readable/writable/executable, OR'd together |
| `p_offset` | 8 | Offset of the segment's data **in the file** |
| `p_vaddr` | 8 | Virtual address the segment is mapped to **in memory** |
| `p_paddr` | 8 | Physical address (irrelevant/ignored on most systems) |
| `p_filesz` | 8 | Size of the segment **in the file** |
| `p_memsz` | 8 | Size of the segment **in memory** |
| `p_align` | 8 | Required alignment (usually page size, 0x1000) |

### Common `p_type` values

| Value | Meaning |
|---|---|
| `PT_LOAD` | A segment that gets mapped into memory and actually runs/holds data — this is what matters most for packing |
| `PT_DYNAMIC` | Dynamic linking info (`.dynamic` section) |
| `PT_INTERP` | Path to the dynamic linker/interpreter (e.g. `/lib64/ld-linux-x86-64.so.2`) |
| `PT_NOTE` | Auxiliary note info (build-id, GNU stack markers, etc.) — small, often has slack space |
| `PT_PHDR` | Location of the program header table itself, mapped into memory |
| `PT_TLS` | Thread-local storage template |
| `PT_GNU_EH_FRAME` | Exception-handling unwind info |
| `PT_GNU_STACK` | Marks whether the stack should be executable |
| `PT_GNU_RELRO` | Read-only-after-relocation region |

**`p_memsz >= p_filesz` always.** When `p_memsz > p_filesz`, the extra
bytes are zero-filled at load time (e.g. `.bss`) — this gap is why
`p_filesz < p_memsz` padding can sometimes be (carefully) extended
without growing the file.

**Finding the executable segment:** the segment whose `p_vaddr` range
contains `e_entry`, with `PT_LOAD` and `PF_X` set, is the one the entry
point actually lives in.

---

## 3. Shdr — `Elf64_Shdr` (section header)

One entry per **section** — what the *linker* and debuggers/tools care
about. The kernel ignores these entirely when running the binary; a
binary can even have zero sections and still execute fine (`e_shnum = 0`).

| Field | Size | Meaning |
|---|---|---|
| `sh_name` | 4 | Offset into the string table (`.shstrtab`) for this section's name |
| `sh_type` | 4 | What kind of section (see table below) |
| `sh_flags` | 8 | `SHF_WRITE`, `SHF_ALLOC`, `SHF_EXECINSTR`, etc. |
| `sh_addr` | 8 | Virtual address if loaded into memory (0 if not) |
| `sh_offset` | 8 | Offset of this section's data in the file |
| `sh_size` | 8 | Size of the section |
| `sh_link` | 4 | Index of a related section (meaning depends on `sh_type`) |
| `sh_info` | 4 | Extra info (meaning depends on `sh_type`) |
| `sh_addralign` | 8 | Alignment requirement |
| `sh_entsize` | 8 | Size of each entry, if this section holds a fixed-size-entry table (e.g. symtab) |

### Common `sh_type` values

| Value | Meaning |
|---|---|
| `SHT_PROGBITS` | Program data — code (`.text`), initialised data (`.data`) |
| `SHT_NOBITS` | No file space taken, zero-filled at runtime (`.bss`) |
| `SHT_SYMTAB` / `SHT_DYNSYM` | Symbol tables |
| `SHT_STRTAB` | String table (names referenced by `sh_name`/symbols) |
| `SHT_RELA` | Relocation entries with explicit addends |
| `SHT_DYNAMIC` | Dynamic linking info |
| `SHT_NOTE` | Note data |

---

## 4. Phdr vs Shdr — why both exist

| | Phdr (segments) | Shdr (sections) |
|---|---|---|
| Read by | The kernel/loader at `execve()` | Linkers, debuggers, `objdump`/`readelf`, static analysis |
| Required to run? | **Yes** — no `PT_LOAD` segments, nothing gets mapped | **No** — can be entirely stripped and the binary still runs |
| Granularity | Coarse (a handful of segments: code, data, dynamic info) | Fine-grained (`.text`, `.data`, `.bss`, `.rodata`, `.symtab`, …) |
| Relationship | One `PT_LOAD` segment typically **contains multiple sections** | Sections map into the segment that covers their `sh_addr`/`sh_offset` range |

**Practical implication:** when `e_shnum == 0` (sections stripped,
`e_shoff`/`e_shstrndx` zeroed), the binary is still perfectly runnable —
this is also a legitimate way to shed section-header overlap checks when
packing, since there's nothing left to overlap with.

---

## 5. Where these live relative to each other in a typical file

```
offset 0            Ehdr
e_phoff           -> Phdr[0] Phdr[1] ... Phdr[e_phnum-1]
(scattered)       -> segment contents (code, data, dynamic info, notes...)
e_shoff           -> Shdr[0] Shdr[1] ... Shdr[e_shnum-1]   (often near/at EOF, or absent)
```

The program header table and section header table are each just **flat
arrays** — `e_phoff`/`e_shoff` give the start, `e_phnum`/`e_shnum` give
the count, `e_phentsize`/`e_shentsize` give the stride. Walking either is
always `base + i * entsize`.
