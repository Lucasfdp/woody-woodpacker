# Answers — woody-woodpacker

Read after attempting. Answers explain the reasoning, not just the fact.

## Section 1

**A-1.1** The four bytes are `0x7F`, `'E'`, `'L'`, `'F'` — in that exact
order, at offset 0 (`e_ident[0..3]`). Any file that doesn't start exactly
this way should be rejected immediately as "not an ELF file" before
anything else is parsed.

**A-1.2** `e_ident[EI_CLASS]` (byte index 4). Value `1` = `ELFCLASS32`
(32-bit), value `2` = `ELFCLASS64` (64-bit). This is the very first thing
woody_woodpacker needs to check, to decide which struct layout (`Elf32_*`
vs `Elf64_*`) to use for everything else.

**A-1.3** `e_entry`, in the ELF header itself (not a program header). It's
the virtual address the CPU jumps to first. Patching this value — plus
making sure your injected code is actually mapped at that address via a
`PT_LOAD` segment — is the core mechanism behind entry-point patching.

**A-1.4** The CPU would try to execute instructions at a virtual address
that was never mapped into the process — no `PT_LOAD` segment covers it.
The kernel raises a page fault it can't resolve, which surfaces as
`SIGSEGV`: a crash, exactly what this subject forbids. `e_entry` only means
anything relative to what the program headers actually load.

**A-1.5** Whichever segments the loader maps, they'll overlap in virtual
memory — one segment's bytes silently overwrite or get overwritten by the
other once both are loaded, corrupting whichever one loses. A naive
implementation will happily *write* a "valid-looking" ELF file with two
overlapping `PT_LOAD` entries at pack time — this is not caught then. You
only notice at run time, as a crash or silent misbehaviour that's hard to
trace back — which is exactly why overlap has to be checked explicitly
when choosing where to inject the stub, never assumed to "just work."

**A-1.6** They serve two different audiences with different lifecycles.
The loader, at process-startup time, only needs "map these bytes, here,
with these permissions" — it has no use for symbol names or debug info,
and carrying that would waste load time and memory on every single process
start. The linker and debugging tools, at build/inspection time, need much
richer structure (named sections, relocation tables, symbol tables) that
would be pointless baggage for the loader to parse on every launch.
Splitting them keeps the fast path (loading) minimal and the rich path
(linking/debugging) as detailed as it needs to be. It's also why you *can*
strip a binary's sections without breaking its ability to run — the loader
never looked at them.

## Section 2

**A-2.1** "Fail closed" means the default behaviour when something is
uncertain or invalid is to refuse and stop, not to proceed and hope. The
difference from "wrapping everything in error checks after the fact" is
architectural: fail-closed design decides, up front, what the safe default
is before a check has passed (e.g. "we haven't confirmed this is ELF, so
we haven't touched the output file at all"), rather than writing the happy
path first and bolting defensive `if`s on afterwards — a style that tends
to leave gaps you only patch for failures you happened to think of.

**A-2.2** Before you've written a single byte of the output file —
ideally before you've even opened it for writing. If you start
modifying/creating `woody` and only then discover the input wasn't valid
x86_64 ELF, you've left a partially-written, broken file on disk in the
failure case, possibly with descriptors still open. "Never crash" also
implicitly means "never leave a mess" — validate completely before
producing any output.

**A-2.3** On Linux, `open()` returns `-1` on failure and sets `errno` — it
doesn't raise an exception, and nothing stops you from using that `-1` as
if it were a real file descriptor. Pass it straight to `read()` and the
kernel rejects `-1` as invalid, so `read()` also returns `-1` — you likely
won't segfault immediately, but you will silently proceed with
garbage/empty data instead of failing with a clear message, which is worse
to debug than a crash. A programmer from an exception-based language might
wrongly expect a failed `open` to abort automatically — on Linux it never
does; checking return values is always on you.

**A-2.4** It's a real resource leak in general, but harmless here
specifically because you `exit()` immediately afterward — the OS closes
all of a process's open file descriptors automatically on exit, for any
reason. Still better style to `close()` explicitly (self-documenting, and
it avoids a habit that bites you in a longer-lived program), but not the
kind of bug that causes a crash or corruption in this case — worth knowing
the difference between "sloppy" and "actually broken."
