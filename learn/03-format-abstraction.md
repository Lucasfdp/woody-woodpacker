---
section: 3
slug: format-abstraction
tier: T2
status: not-started
prereqs: [1, 2]
terms: [interface, function pointer, dispatch table, struct-of-pointers pattern, format backend]
---

# Section 3 — One interface, many formats

**Depth: T2** — this is a design decision you make once and live with for
every bonus after it.
**You'll be able to:** design a single set of operations that works the
same way whether the file underneath is 64-bit ELF, 32-bit ELF, or
Mach-O, without `if` chains scattered through the whole program.

## The idea

Right now `main.c` reads one format: 64-bit ELF, directly, with `Elf64_Ehdr`
and `Elf64_Phdr` types named explicitly in the code. That's fine while
there's one format. The moment 32-bit ELF and Mach-O bonuses exist, every
place that touches the header would need its own `if (is_elf64) ... else if
(is_elf32) ... else if (is_macho)`. Multiply that by every operation you
need — read the header, find where to inject the stub, patch the entry
point, write the result — and the program becomes a maze of near-duplicate
branches that's easy to break in one format while fixing another.

The fix is to stop asking "which format is this?" more than once. Ask it a
single time, right after you've read the magic number (§ 1) — and let that
one answer choose *which complete set of functions* handles everything else
for this file, from that point on. The rest of the program then calls
"parse the header", "find the injection point", "patch the entry", "write
the output" without caring which format it's talking to.

## The names for it

**Interface** — an agreed set of operations, named and with a fixed meaning,
that more than one concrete implementation can provide. You've already been
using one without the word: `open`, `read`, `write`, `close` are an
interface — the same four calls work whether the underlying thing is a
regular file, a pipe, or a socket. You're about to build a small interface
of your own, with operations like "parse this header" instead.

**Function pointer** — a variable that holds the address of a function*
instead of the address of data. You can call it exactly like a normal
function, except which function actually runs is decided by whatever address
is currently stored in the pointer — which can change at runtime. This is
the mechanism that makes "pick the format once, then call the same four
names regardless of which format it is" possible in C, which has no classes
or built-in polymorphism.

**Dispatch table** (also: **struct-of-pointers pattern**) — a `struct` whose
fields are all function pointers, one struct value per format
(`elf64_backend`, `elf32_backend`, `macho_backend`), each one filled in with
that format's actual functions. "Dispatch" because deciding which function
runs is called *dispatching* the call to the right implementation. You'll
sometimes see this called a **vtable** in C++ contexts — short for **v**irtual
**table** — but in plain C you build the same idea by hand, as one ordinary
struct.

**Format backend** — this project's name for one complete implementation of
the interface: the four functions that know how to do everything the rest of
the program needs, for exactly one binary format.

## How it actually works

1. **Define the interface first**, as a `struct` of function pointers with a
   fixed signature per operation, e.g.:
   ```c
   typedef struct {
       int  (*parse_header)(uint8_t *buf, size_t len, void *out_info);
       long (*find_injection_point)(void *info);
       void (*patch_entry)(void *info, long new_entry);
       int  (*write_output)(int fd, void *info);
   } format_backend_t;
   ```
   The exact fields matter less than the discipline: every backend must
   implement *all four*, with the *same signature*, so the caller never
   needs to know which one it's holding.

2. **Detect the format once**, right after the magic-number check from § 1
   and § 2 — ELF's `0x7F 'E' 'L' 'F'` versus Mach-O's own magic bytes — and
   from that single check, pick *one* `format_backend_t` value (a global
   `elf64_backend`, `elf32_backend`, or `macho_backend`, each a `struct`
   literal with its four functions filled in).

3. **Everywhere else, call through the struct**: `backend.parse_header(...)`,
   `backend.find_injection_point(...)`, never `if (format == ELF64) {...}
   else {...}` again. The branch happened exactly once, at detection time.

4. **Each format's `void *info`** (or a tagged union, if you prefer explicit
   typing over `void *`) carries whatever that format actually needs — ELF's
   `Elf64_Ehdr`/`Elf64_Phdr` pointers, Mach-O's own header/load-command
   pointers — without the interface itself needing to know ELF or Mach-O
   details.

## Known traps

- **Designing the interface around ELF only, then discovering Mach-O doesn't
  fit it.** ELF uses program headers; Mach-O uses load commands — different
  shapes. If an interface function's signature leaks ELF-specific types
  (`Elf64_Phdr *` as a parameter, say), the Mach-O backend can't honestly
  implement it. Keep the interface's parameters generic (opaque pointers,
  sizes, offsets) and let each backend interpret them internally.
- **A function pointer that's never been assigned.** Calling an
  uninitialised or null function pointer doesn't give a helpful error — it's
  undefined behaviour, often a crash with no useful message. Every backend
  struct must have *all four* fields assigned before it's ever used; a
  partially-filled backend is worse than no abstraction at all, because it
  looks complete until the one missing operation is called.
- **Re-detecting the format in more than one place.** If "is this ELF64?"
  gets checked again deep inside `write_output`, you've quietly broken the
  abstraction — now there are two places that decide the format, and they
  can disagree if one is ever updated without the other.

## Checkpoint

Design (on paper or as a header comment first, then as real C) the
`format_backend_t` interface: the exact function signatures for
`parse_header`, `find_injection_point`, `patch_entry`, and `write_output`.
Write the ELF64 backend as the first concrete implementation, filling in a
struct literal with your four existing pieces of logic from §§ 1–2 refactored
to match the signatures. Don't write the ELF32 or Mach-O backends yet —
the checkpoint is proving the interface is *shaped* right by making exactly
one implementation of it work, identically to how `main.c` works today.

## Questions

Q-3.1 (recall) What does a dispatch table actually store in each of its
fields, and how is that different from a struct that stores ELF header
values directly?

Q-3.2 (application) Write the four-field `format_backend_t` struct
declaration (signatures only, no bodies) for the operations described
above.

Q-3.3 (prediction) You call `backend.patch_entry(...)` on a
`format_backend_t` value where that field was never assigned. What
actually happens when the program runs, and why is it worse than a normal
null-pointer dereference on a data pointer?

Q-3.4 (prediction) Suppose the Mach-O backend's `find_injection_point`
needs information ELF's version of that function never needed (say, which
load command to grow). What does that tell you about whether `void *info`
was the right choice for the shared parameter type, versus a tagged union?

Answers: `ANSWERS.md` § 3
