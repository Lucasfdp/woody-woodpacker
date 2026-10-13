---
section: 5
slug: mmap-mprotect
tier: T2
status: not-started
prereqs: [2, 4]
terms: [mmap, MAP_PRIVATE / MAP_ANONYMOUS, PROT_READ / PROT_WRITE / PROT_EXEC, page, mprotect, munmap, W^X]
---

# Section 5 — Memory mapping & page permissions

**Depth: T2** — this is the mechanism the decrypt stub depends on, not a
one-off call you use once and forget.
**You'll be able to:** get a block of memory from the OS with exact
permissions, and change those permissions at runtime — the same move the
decrypt stub performs on itself when it switches a code page from
"executable" to "writable, so I can decrypt into it" and back.

## The idea

You already know how to get memory from `malloc()` — but `malloc` gives
you memory for *data*: readable and writable, never executable, and you
have no say over that. For most of this project that's fine. But the
decrypt stub (§§ 7–8) has to do something `malloc` was never designed
for: take a chunk of memory that currently holds *code* the CPU is allowed
to run, temporarily make it *writable* so the stub can decrypt bytes into
it, and then make it *executable again* before jumping into it — all
inside the same running process, without crashing.

That needs two things `malloc` can't give you: memory with a permission
combination you chose yourself, and the ability to change that combination
after the memory already exists. Both are OS-level operations, not C
library conveniences — which is why they're on the subject's allowed-
function list by name.

## The names for it

**`mmap`** — **M**emory **MAP**. Asks the kernel directly for a block of
memory (or a view onto a file) at a size and permission you specify,
instead of going through `malloc`'s heap. You've technically already used
file-backed `mmap` conceptually when § 1 talked about the loader "mapping"
`PT_LOAD` segments — that's the exact same mechanism, just done for you by
the OS when a program starts, instead of called by hand.

**`MAP_PRIVATE` / `MAP_ANONYMOUS`** — two flags you'll pass together for
the throwaway demo and, differently, for real injected memory later.
`MAP_PRIVATE` means writes to this mapping are private to your process,
never shared back to a file or other processes. `MAP_ANONYMOUS` means
there's no file behind this mapping at all — you're asking for a bare
block of memory, backed by nothing but itself, which is what `malloc`'s
anonymous heap pages are internally built from anyway.

**`PROT_READ` / `PROT_WRITE` / `PROT_EXEC`** — **PROT**ection flags, the
permissions `mmap` and `mprotect` set, combined with `|` exactly like the
`O_*` flags from § 4. `PROT_READ`: can be read. `PROT_WRITE`: can be
written. `PROT_EXEC`: the CPU is allowed to fetch and run instructions
from here. These three can be combined in almost any mix — `PROT_READ |
PROT_EXEC` with no write is the normal, safe state for code; the stub's
whole trick is toggling between that and `PROT_READ | PROT_WRITE`.

**Page** — the fixed-size chunk (almost always 4096 bytes on x86_64) that
memory protection actually operates in. You cannot ask the hardware to
make *17 bytes* executable — only whole pages. Every `mmap`/`mprotect`
address and length either must already be page-aligned or gets rounded by
the kernel, and getting this wrong is the single most common bug in this
section.

**`mprotect`** — **M**emory **PROTECT**. Changes the permission flags of
an *already-mapped* region, in place, without unmapping or remapping it.
This is the call the decrypt stub uses to flip a segment between
"writable, I'm decrypting into you" and "executable, now run."

**`munmap`** — the inverse of `mmap`: releases a mapping back to the
kernel. Every `mmap` that isn't backing something you intend to run for
the rest of the process's life needs a matching `munmap`, the same
discipline as `malloc`/`free` or `open`/`close`.

**W^X** (**W**rite **X**OR e**X**ecute) — a hardening policy, enforced by
some kernels/hardware configurations, that refuses to let a single mapping
be both writable *and* executable at the same time (`PROT_WRITE |
PROT_EXEC` together gets rejected or silently stripped). It's the direct
reason the stub can't just leave everything `RWX` permanently and skip the
`mprotect` dance — on a hardened system, that mapping would never be
allowed to exist in the first place.

## How it actually works

For the throwaway demo (not part of the real deliverable — see
Checkpoint):

```c
void *mem = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                  MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
/* write a tiny instruction sequence into mem, e.g. a single `ret` byte */
mprotect(mem, 4096, PROT_READ | PROT_EXEC);
void (*f)(void) = (void (*)(void))mem;
f();            /* jumps into mem, executes `ret`, returns — no crash */
munmap(mem, 4096);
```

The arguments worth noticing:
- `NULL` as the first argument: "I don't care what address, kernel picks."
- `4096`: one page — the smallest unit that's safe to request and
  guaranteed aligned by `mmap` itself.
- The *write-then-protect-then-execute* ordering is not optional: you
  write your bytes while the mapping is still writable, flip permissions
  only once the bytes you need are already there, and never try to write
  into a region after it's `PROT_EXEC`-only — that write will itself
  segfault.

The real project doesn't `mmap` fresh memory for the stub at *pack* time —
it writes bytes directly into the output file. Where `mmap`/`mprotect`
matter for real is *at run time*, inside the packed binary itself: when
`woody` starts, its injected stub is sitting in a segment the loader
mapped as `PROT_READ | PROT_EXEC` (because that's what the program header
you wrote at pack time said). Before the stub can decrypt the rest of the
binary *in place*, it needs that target region to be writable — which
means the stub itself has to call `mprotect` on its own process's memory,
at runtime, exactly like the demo above, before XOR-ing any bytes back to
their original form.

## Known traps

- **Non-page-aligned address or length.** `mmap`'s length gets rounded up
  to a full page automatically, but `mprotect`'s *address* argument must
  already be page-aligned — passing an address that's merely "inside" the
  right page, not at its start, fails outright (`EINVAL`) rather than
  rounding for you.
- **Assuming you can skip the demo and `mprotect` arbitrary heap memory
  from `malloc`.** It can sometimes work, because the heap happens to be
  page-backed underneath — but you don't control where `malloc`'s pointer
  sits relative to a page boundary, so you'd be relying on an accident. Use
  `mmap` when you need protection control; that's exactly what it's for.
- **Writing into memory after it's already `PROT_EXEC`-only.** Once you've
  called `mprotect(..., PROT_READ | PROT_EXEC)`, a subsequent write to
  that same memory is itself the exact SIGSEGV scenario from § 2 — you
  need the write *and* the protection change in the right order, every
  time you toggle.
- **Expecting `RWX` (all three flags at once) to always just work.** It
  often does on a default Linux config — but relying on it is fragile, and
  it's the one combination a hardened kernel (W^X) is specifically
  designed to refuse. Writing the stub to never need simultaneous write +
  execute is the robust version of this mechanism.

## Checkpoint

**Throwaway demo — not part of the deliverable, clearly separate code.**
Write a small standalone C file (outside `srcs/`, e.g. in a scratch
location) that: `mmap`s one anonymous page `PROT_READ | PROT_WRITE`,
writes a single `0xC3` byte (the x86_64 `ret` instruction) at the start of
it, calls `mprotect` to flip it to `PROT_READ | PROT_EXEC`, casts the
pointer to a `void (*)(void)` function pointer and calls it, then
`munmap`s it. Confirm it runs with no crash and no warning from
`valgrind` about executing from freed/invalid memory. This is purely to
build confidence in the primitive before § 7–8 ask you to use the same
pattern on the stub for real.

## Questions

Q-5.1 (recall) What can `mmap` give you that `malloc` can't, and why does
that matter for a program whose job is to make injected code executable?

Q-5.2 (application) In the demo above, why must the `mprotect` call to
`PROT_READ | PROT_EXEC` happen *after* you've written the `0xC3` byte, not
before? What goes wrong if you reverse the order?

Q-5.3 (prediction) You `mmap(NULL, 10, ...)`, asking for 10 bytes. The call
succeeds and returns a non-null address. What is the actual usable size of
the mapping you were given, and what happens if you write to byte offset
4096 of it?

Q-5.4 (prediction) You call `mprotect(ptr + 8, 4096, PROT_READ |
PROT_EXEC)` where `ptr` is a page-aligned address from a prior `mmap`.
What happens, and why does `mprotect` not just round `ptr + 8` down to the
nearest page boundary for you the way `mmap`'s length argument gets
rounded up?

Answers: `ANSWERS.md` § 5
