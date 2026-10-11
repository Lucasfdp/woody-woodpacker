# Decisions

## 2026-10-11 — Format support as an interface, not a monolith
**Chose:** a format-backend interface (parse_header / find_injection_point /
patch_entry / write_output), one implementation per binary format.
**Rejected:** a single function handling ELF64 only, extended later.
**Why:** the mandatory part already requires detecting "not x86_64 ELF" and
erroring, so a dispatch layer is unavoidable. With 4 of 5 committed bonuses
being format-related (32-bit ELF, Mach-O, PE), building the seam now avoids
tearing the core apart later.
**Cost accepted:** more upfront design than a quick ELF64-only version.
**Revisit if:** PE is dropped entirely and 32-bit/Mach-O turn out to share
almost nothing structurally (unlikely — ELF32/64 share the same shape).

## 2026-10-11 — Stream cipher (keystream XOR) over a block cipher or ROT
**Chose:** a keystream-based stream cipher — generate a pseudorandom stream
from the key, XOR it against the binary's bytes.
**Rejected:** a simple ROT/substitution (subject explicitly says this isn't
"advanced" enough), and a block cipher (more structure than needed and
harder to vectorise cleanly).
**Why:** a stream cipher is both a legitimate answer to "not an easy ROT"
and naturally vectorisable — same SIMD mental model as the libasm strlen
work, which feeds directly into the asm-optimisation bonus.
**Cost accepted:** need a well-mixed keystream generator, not just a
counter — a weak generator is a ROT in disguise.
**Revisit if:** the generator turns out too weak to defend as "advanced"
during evaluation.

## 2026-10-11 — LZSS over RLE for the compression bonus
**Chose:** LZSS (sliding-window back-reference compression).
**Rejected:** RLE (byte-run encoding) — far simpler, but gives poor/negative
ratio on real compiled binaries since they rarely have long identical-byte
runs.
**Why:** Lucas wants to dedicate real time and actually learn the
algorithm, not just satisfy the bonus checkbox. LZSS is also what real
executable packers (UPX) use, for the same reason — small enough to
decompress from a tiny stub, far more effective than RLE on code.
**Cost accepted:** meaningfully more asm to hand-write for the
decompression stub (window buffer, overlapping-copy logic), and it must
never crash on malformed input.
**Revisit if:** the decompression stub's complexity starts threatening the
mandatory part's stability — compression is a bonus, mandatory always wins.

## 2026-10-11 — Mach-O (full) over PE (full) for the "additional format" bonus
**Chose:** Mach-O as the primary additional-format bonus, fully implemented
and tested end-to-end.
**Rejected:** PE as the primary target.
**Why:** Lucas develops on a Mac — a packed Mach-O binary can actually be
built, packed, and run to verify identical execution. A packed PE binary
cannot be executed without Wine or a Windows VM, so it could only be
verified structurally (header/offset correctness), not behaviourally.
**Cost accepted:** PE is deferred; if attempted at all, it will be
structural-only and explicitly presented as such at evaluation.
**Revisit if:** Wine or a Windows VM becomes available and there's time
left after the mandatory part and the other four bonuses are solid.

## 2026-10-11 — Pipeline order: compress-then-encrypt / decrypt-then-decompress
**Chose:** when packing, compress the payload first, then encrypt the
compressed bytes. The stub reverses this: decrypt first, then decompress.
**Rejected:** encrypt-then-compress (compressing encrypted/high-entropy
data gives essentially no size reduction, defeating the point).
**Why:** compression only works on data with structure; encryption
deliberately destroys structure. Compressing before encrypting is the only
order that gets any benefit from LZSS at all.
**Cost accepted:** the stub needs two stages instead of one.

## 2026-10-11 — 32-bit support as a separate stub, shared design
**Chose:** a dedicated 32-bit decrypt stub (own register widths, `int 0x80`
instead of `syscall`), following the same design taught once for 64-bit.
**Rejected:** trying to share literal stub code between 32-bit and 64-bit
targets.
**Why:** the two use different syscall calling conventions and register
widths — there's no meaningful code to share, only a pattern to repeat.
**Cost accepted:** two stubs to maintain instead of one.
