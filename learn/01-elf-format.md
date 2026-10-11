---
section: 1
slug: elf-format
tier: T3
status: not-started
prereqs: []
terms: [ELF, magic number, e_ident, EI_CLASS, e_type, e_entry, ABI, program header, segment vs section, PT_LOAD, p_vaddr / p_offset / p_filesz / p_memsz, p_flags (PF_R / PF_W / PF_X)]
---

# Section 1 — What's actually inside a compiled program

**Depth: T3** — this isn't background knowledge for the project, it *is*
the project. Every bonus (32-bit, Mach-O, injection, compression) is a
variation on "understand and manipulate this file's structure."
**You'll be able to:** read any x86_64 ELF binary's header and program
headers by hand, and explain exactly what the OS does with each field when
it runs that file.

## The idea

When you run `clang -o sample sample.c`, the compiler doesn't just dump
machine code into a file. It writes a structured document — think of it
like a shipping manifest stapled to the front of a crate. The manifest
says: "this crate contains these sub-boxes, each one goes in this specific
spot in the warehouse, with these access rules (can you open it? can you
write into it? can you run what's inside it?)." The kernel reads that
manifest before it runs a single instruction of your program.

That manifest-plus-crate format is **ELF**. The "warehouse" is your
process's virtual memory. The "sub-boxes" are chunks of the file that get
placed at specific memory addresses. Your `woody_woodpacker` program's
entire job is to read this manifest, add a new sub-box (the decryption
stub), and edit one line of the manifest (where to start reading from) —
without breaking anything else the manifest describes.

## The names for it

**ELF** — **E**xecutable and **L**inkable **F**ormat. The name itself
tells you its two jobs: it's a format a loader can *execute* directly, and
one a linker can *link* (combine with other object files) before that.
Both uses share the same file structure, with different parts emphasised.

**Magic number** — the very first 4 bytes of any ELF file: `0x7F`, `'E'`,
`'L'`, `'F'`. "Magic number" is the generic term (across all file formats,
not just ELF) for a fixed byte sequence at the start of a file whose only
job is to say "this file is what it claims to be" before you trust
anything else in it. PNG files, ZIP files, JPEGs — all have their own
magic numbers for the same reason.

**e_ident** — **E**LF **ident**ification. This is the name of the first
field in the ELF header — a 16-byte array that holds the magic number plus
a handful of single-byte flags about the file's basic shape. One of those
flags is:

**EI_CLASS** — **E**LF **I**dentification, **CLASS**. Byte index 4 of
`e_ident`. Value `1` (`ELFCLASS32`) means "this is a 32-bit ELF file,"
value `2` (`ELFCLASS64`) means 64-bit. This single byte decides whether
every other structure in the file — the header, the program headers — is
laid out using 32-bit or 64-bit field widths. Get this wrong and every
offset you read afterward is garbage.

**e_type** — tells you what *category* of ELF file this is: `ET_EXEC`
(a standalone executable, the historical default), `ET_DYN` (a shared
library, or — on modern systems — a position-independent executable; most
binaries built today are actually `ET_DYN`), `ET_REL` (a relocatable
object file, like a `.o` before linking).

**e_entry** — the virtual memory address where the CPU starts executing.
This is the single most important field for this project: it's what you
patch to redirect execution into your injected decrypt stub.

**ABI** — **A**pplication **B**inary **I**nterface. The rulebook for how
compiled code is laid out and how it talks to the OS and to other compiled
code — which registers hold which arguments, how the stack must look,
which number means which syscall. You already met this in libasm as "the
System V AMD64 calling convention" — that *is* part of x86_64 Linux's ABI.
ELF's header records which ABI a binary targets, which is part of why a
32-bit ELF binary can't just be run as if it were 64-bit: the ABI, not
just the file layout, differs.

**Program header** — an entry in a second table (separate from the main
ELF header) that tells the *loader* — the part of the kernel that sets up
a new process — what to map into memory before execution starts at all.

**Segment vs. section** — these are easy to confuse because both are
"chunks of the file," but they serve different readers at different times:
- A **segment** (described by a program header) is a *runtime* concept:
  "map these bytes into memory, here, with these permissions." The loader
  only looks at segments.
- A **section** (described by a separate section header table) is a
  *build-time* concept: "this named chunk is `.text`," "this one is the
  symbol table." Linkers and debuggers use sections; the loader ignores
  them entirely.

  One segment usually *contains* several sections — e.g. the segment that
  gets mapped read+execute typically contains the `.text` section (actual
  instructions) and `.rodata` (read-only data) together, because they
  need the same memory permissions.

**PT_LOAD** — **P**rogram header **T**ype, **LOAD**. The specific program-
header type meaning "load this chunk of the file into memory." Not every
program header is `PT_LOAD` (there are others, for dynamic linking info,
etc.), but `PT_LOAD` entries are the ones that actually make your code and
data exist in the running process.

**p_vaddr / p_offset / p_filesz / p_memsz** — four fields on every program
header:
- `p_offset` — where this segment's bytes *start in the file on disk*.
- `p_vaddr` — where this segment should be placed *in virtual memory*.
- `p_filesz` — how many bytes to actually copy from the file.
- `p_memsz` — how much memory to reserve for it — this can be *larger*
  than `p_filesz`, with the extra space zero-filled. (This is how `.bss`,
  the zero-initialised data segment, works: it takes no space in the file
  at all, only a note saying "reserve this much memory and zero it.")

**p_flags (PF_R / PF_W / PF_X)** — **P**rogram header **Flags** —
**R**ead, **W**rite, e**X**ecute. The permission bits the OS applies to
this segment's memory once mapped. Code segments are typically R+X but
*not* W (so injected/modified code can't normally just be written to
directly — this is exactly why your stub will need `mprotect`, covered in
§ 5, to temporarily change this).

## How it actually works

When the kernel runs `execve()` on an ELF file, roughly:

1. Read `e_ident` — check the magic number, check `EI_CLASS` to know
   whether to interpret the rest as 32-bit or 64-bit structures.
2. Read the rest of the ELF header — including `e_entry` and where the
   program header table itself lives in the file.
3. Walk the program header table. For every entry with type `PT_LOAD`:
   copy `p_filesz` bytes starting at `p_offset` in the file, into memory
   starting at `p_vaddr`, reserving `p_memsz` bytes total (zero-filling
   any excess), and apply the permissions in `p_flags`.
4. Once every `PT_LOAD` segment is mapped, set the CPU's instruction
   pointer to `e_entry` and start executing.

That's the entire loading model. Nothing else happens before your code
runs. If `e_entry` points somewhere that step 3 didn't actually map, step
4 crashes immediately (see traps, below).

For a packer, this means your options to inject new executable code are
limited to things that fit this model:
- Find existing unused space inside a `PT_LOAD` segment's reserved-but-
  unused memory (`p_memsz > p_filesz`, or alignment padding) — no new
  segment needed, but space is tight and sometimes nonexistent.
- Add a brand new `PT_LOAD` segment entirely, with its own `p_vaddr`,
  carrying your stub's code and the encrypted payload.
- Extend an existing segment's `p_filesz`/`p_memsz` to make room at its
  end, appending your stub's bytes there.

Each has real trade-offs you'll weigh properly in § 7 (entry-point
injection) — this section is about understanding the format well enough
to make that choice informed, not making it yet.

## Known traps

- **Reading the wrong struct width.** If you parse a 32-bit ELF file using
  `Elf64_*` struct layouts (or vice versa), every field after `EI_CLASS`
  will read as nonsense — not a crash necessarily, just silently wrong
  numbers, which is worse because it looks like it's working.
- **Trusting `e_entry` without checking it's actually covered by a
  `PT_LOAD` segment.** This is exactly the Q-1.4 scenario: jump to an
  address nothing mapped, and the result is `SIGSEGV`.
- **Confusing segments and sections when deciding where to inject code.**
  The loader never looks at section headers — if you carefully preserve
  section-header correctness but break a `PT_LOAD` entry, the binary still
  won't run. Conversely, section headers can be a little "wrong" or even
  stripped entirely, and the binary runs fine — the loader doesn't care.
- **`readelf -h` vs `readelf -l` vs `readelf -S`** — easy to look at the
  wrong table while debugging. `-h` is the main header, `-l` is program
  headers (segments, what the loader uses), `-S` is section headers (what
  the linker/debugger used).

## Checkpoint

Write a small C program (this is real project code, not a throwaway — it
becomes the first piece of `woody_woodpacker`'s own ELF-reading logic)
that:
1. Opens a real compiled 64-bit ELF binary given as an argument.
2. Reads and validates the magic number — reject anything else.
3. Reads `EI_CLASS` and rejects anything that isn't `ELFCLASS64` (this is
   your first piece of the "File architecture not supported" mandatory
   check — § 2 will cover the rest of that requirement properly).
4. Prints `e_entry`, and then walks the program header table, printing
   each `PT_LOAD` entry's `p_vaddr`, `p_offset`, `p_filesz`, `p_memsz`, and
   `p_flags` in a human-readable form.

Verify it against `readelf -h` and `readelf -l` on the same binary — your
numbers must match exactly.

## Questions

Q-1.1 (recall) What four bytes must appear at the very start of any ELF
file, and in what order?

Q-1.2 (recall) Which single byte in `e_ident` tells you whether a file is
32-bit or 64-bit, and what are its two possible values?

Q-1.3 (application) Given a `readelf -h` dump, which field tells you where
you'd need to redirect execution if you wanted to hijack this binary's
entry point?

Q-1.4 (prediction) If you read `e_entry` from the header but then jump
straight to that address without making sure it's actually covered by a
loaded `PT_LOAD` segment, what happens?

Q-1.5 (prediction) Two `PT_LOAD` segments end up with overlapping
`p_vaddr` ranges after you naively append a new one without recalculating
offsets — what breaks, and when do you notice: at pack time, or at run
time?

Q-1.6 (open/design) Why does ELF separate "segments" (for the loader) from
"sections" (for the linker/debugger) instead of using one table for both?

Answers: `ANSWERS.md` § 1
