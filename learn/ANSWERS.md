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

## Section 3

**A-3.1** Each field stores the *address of a function* — not a value, a
piece of behaviour. `parse_header` in the ELF64 backend points at code that
knows `Elf64_Ehdr`; in the Mach-O backend it points at completely different
code that knows Mach-O's header instead. A struct that stored header
values directly (e.g. `e_entry` as a field) would only ever hold one
format's data shape — you'd be back to `if` chains to interpret it
correctly. Storing *operations* instead of *data* is what lets one shared
struct type represent three unrelated binary formats.

**A-3.2**
```c
typedef struct {
    int  (*parse_header)(uint8_t *buf, size_t len, void *out_info);
    long (*find_injection_point)(void *info);
    void (*patch_entry)(void *info, long new_entry);
    int  (*write_output)(int fd, void *info);
} format_backend_t;
```
What matters is that every backend instance uses *identical* signatures —
that's the contract the rest of the program relies on to call through the
struct without caring which backend it has.

**A-3.3** Calling through a null (or garbage, if never zero-initialised)
function pointer is undefined behaviour at the CPU level — the program
tries to jump execution to whatever address happens to be sitting in that
field, which for an uninitialised struct could be any leftover stack value,
not necessarily `0`. A null-pointer *dereference* on a data pointer at
least reliably faults at a predictable, low address (`0x0`), giving you a
recognisable crash. An uninitialised function pointer can jump anywhere —
possibly into valid-looking memory that isn't code at all, producing
bizarre, hard-to-reproduce behaviour instead of a clean crash. This is
exactly why every backend struct needs all four fields assigned,
explicitly, before first use.

**A-3.4** It tells you `void *info` is leaking the abstraction's own
weakness: the caller has to somehow know, per format, what's actually
behind that pointer and how much memory it's allowed to touch — which
means the "generic" interface isn't actually generic, it's just untyped.
A tagged union (a struct with an explicit `enum format_tag` field plus a
union of the format-specific info structs) would at least let you assert
"this is the Mach-O variant" with a runtime check instead of hoping every
backend remembers what it put there. Either way, Mach-O needing
information ELF never needed is a sign the four operations themselves may
need a fifth parameter that's common to all formats (e.g. "format-specific
context size") rather than smuggling it in through an opaque pointer.

## Section 4

**A-4.1** `O_TRUNC` sets the file's length to 0 before any new writing —
so the new content fully replaces the old. Without it, writing a 2 KB
binary over a path that previously held a 10 KB one would only overwrite
the first 2 KB; bytes 2 KB–10 KB from the old file would still be sitting
there afterward, since `write()` only extends a file forward from its
current length and only overwrites what it actually writes over. The
result: `woody` would be 10 KB on disk, with the last 8 KB being stale
garbage from a previous run — a packed binary that's subtly corrupted in a
way `diff` against the *current* input would catch, but a casual size
check wouldn't.

**A-4.2** `int fd = open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0700);` —
`0700` grants read, write and execute to the owner only, nothing to group
or others. (`0755` is also a reasonable answer if "executable by its
owner" was read as "at minimum, including others" — the key point being
the owner's execute bit is present either way.)

**A-4.3** On a write of more than ~2 GB, `int` (commonly 32-bit, max
~2.1 billion) can't represent the byte count `write()` actually reports if
a single call happened to return a value near or past `INT_MAX` — more
realistically, the surrounding arithmetic (`written += n` where `written`
is also declared too narrow, or a loop bound computed as `int`) silently
wraps or truncates, and the loop can either stop early (truncated output,
exactly the § 4 trap) or never terminate, depending on exactly how the
overflow lands. `ssize_t` exists as a **s**igned version of `size_t`
specifically so functions like `write()` and `read()` can return either a
*byte count* (requiring the same width as `size_t`, to represent large
sizes) *or* `-1` for "error" — a plain unsigned `size_t` can't represent
`-1` meaningfully, and a plain `int` is too narrow on many platforms for
large files. Using the exact return type a syscall documents, instead of
whatever type happens to compile, is precisely the kind of thing that
doesn't matter until a file crosses some size threshold, and then produces
output corruption that's hard to connect back to the cause.

## Section 5

**A-5.1** `mmap` lets you choose the exact permission combination a
region of memory starts with — including `PROT_EXEC` — and `mprotect`
lets you change that combination later on an existing mapping. `malloc`
gives you memory that's always read/write-only, with no mechanism to make
it executable afterward. A program whose entire job is injecting code
that must later run needs that control; `malloc` was never designed to
give it.

**A-5.2** Because once the mapping is `PROT_EXEC`-only (no `PROT_WRITE`),
writing to it is the exact SIGSEGV scenario § 2 covers — the CPU/kernel
will refuse the write and fault. You must write your bytes while the
mapping is still writable, then flip permissions once, after the content
is already correct. Reversing the order means the write to insert the
`0xC3` byte faults before it ever happens.

**A-5.3** The actual mapping is rounded up to a full page (4096 bytes on
x86_64) even though only 10 were requested — `mmap` never gives partial
pages. Writing to byte offset 4096 is writing to the *next* page, which
was never mapped by this call; that's an access to unmapped memory and
faults with `SIGSEGV`, exactly the § 2 scenario, even though it "felt"
like it should be within a 10-byte allocation's neighbourhood.

**A-5.4** The call fails outright, typically with `EINVAL` — `mprotect`
requires its address argument to already be page-aligned and does not
round it for you. The asymmetry with `mmap`'s length (which does get
rounded up) exists because `mmap`'s length only has one reasonable
interpretation ("at least this much, rounding costs nothing"), while
`mprotect` rounding a misaligned *address* down would silently change
*which* page gets its protection changed — potentially a page the caller
didn't intend to touch at all, which is exactly the kind of silent,
surprising behaviour `mprotect` refuses to risk.

## Section 6

**A-6.1** `(x ^ k) ^ k == x` for every bit of every byte, because XOR-ing
a bit with the same value twice always returns to the original bit: if
the bit was `0`, XOR with `k` flips it to match `k`'s bit, and XOR with
`k` again flips it right back; if it was `1`, the same reasoning applies
in reverse. This holds for *any* value of `k`, which is exactly why the
keystream can be any pseudorandom sequence at all — the reversibility
doesn't depend on the keystream being special, only on using the *same*
one both times.

**A-6.2** The key itself has to travel from pack time into the packed
binary — not the keystream, and not merely "having been printed to
stdout." Printing to stdout tells the *user* the key so they can note it
down; it does nothing for the stub sitting inside the binary file, which
has no access to whatever the user saw on their terminal during packing.
The stub needs the key embedded as data it can read directly (or passed
some other way you design), so it can re-run the same keystream-
derivation logic at runtime, independent of what stdout showed.

**A-6.3** The 64-byte run of zero bytes becomes the 4-byte key repeated
16 times in a row, because XOR-ing `0x00` with any value `k` returns `k`
itself (`0 ^ k == k`) — so every "zero" byte in that run just becomes
whatever the keystream byte at that position was, and since the
keystream is the 4-byte key cycling on a period of 4, the run shows the
key, verbatim, repeating — in plain sight to anyone who opens the file in
a hex editor and notices the repetition.

**A-6.4** Decryption produces garbage — not an error, just wrong bytes,
because the stub's freshly-generated "random" key from `getrandom` is
statistically guaranteed to be different from the one used at pack time
(that's what randomness means: not reproducible). "The same way" refers
to the *procedure* (call `getrandom`, get some bytes) being identical,
but the procedure's *output* is different every single time by design —
reproducibility requires carrying the actual key value forward
explicitly, never re-invoking the random-generation step and hoping for
the same result.
