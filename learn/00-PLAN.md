# woody-woodpacker — Learning Plan

**Mode:** 42
**Goal:** build a foundation — no deadline, going deep on purpose
**Started:** 2026-10-11
**Languages:** learn/ (EN) · learn_es/ (ES)

## What this project is for
Build a working x86_64 ELF packer (`woody_woodpacker`): it encrypts a target
binary, injects a decryption stub, and patches the entry point so the
packed binary (`woody`) decrypts itself and runs identically to the
original. Then extend the same mechanism to 32-bit ELF, Mach-O, a
parameterised key, LZSS compression, and an assembly-optimised decrypt
loop — all 5 bonuses.

## What this project is NOT for
- **PE execution testing** — deferred. A packed `.exe` can't be run or
  verified on this Mac without Wine or a Windows VM. If attempted at all,
  it's structural-only (header/offset correctness), at the end, time
  permitting.
- **Deep cryptography** — the algorithm needs to be genuinely non-trivial
  (the subject rules out a simple ROT), not cryptographically bulletproof.
  Real cipher design is a different project.
- **General compiler/linker internals** beyond what ELF/Mach-O layout
  actually requires.

## Constraints (from the subject)
- 64-bit ELF only in the mandatory path — other architectures must be
  rejected with a clear message, never crash.
- Executable named `woody_woodpacker`; output named `woody`.
- Allowed functions only: `open`, `close`, `exit`, `fputs`, `fflush`,
  `lseek`, `mmap`, `munmap`, `mprotect`, `perror`, `strerror`, `syscall`,
  the `printf` family, and libft-authorised `read`/`write`/`malloc`/`free`.
- Key generated randomly, printed to stdout.
- The packed binary must print `....WOODY....` + newline, then run
  identically to the original after decrypting.
- Must never crash, must not alter the final execution.
- **Bonuses are only evaluated if the mandatory part is perfect.**

## Bonuses committed to (all 5)
1. 32-bit ELF management
2. Parameterised key (CLI-supplied, alongside the random default)
3. Algorithm optimisation in assembly (direct continuation of the libasm
   SWAR/SIMD work)
4. Additional binary format — **Mach-O**, full and execution-tested (this
   machine is a Mac); PE attempted structurally only, at the end, if time
   allows
5. Binary compression — **LZSS**

See `DECISIONS.md` for the reasoning behind each of these choices.

## Depth allocation

| # | Concept | Centrality | Transfer | Cost later | Total | Tier |
|---|---|---|---|---|---|---|
| 1 | ELF format (header, program headers) | 3 | 3 | 3 | 10→**T3** | T3 (override — this *is* the project) |
| 2 | Defensive "never crash" error handling | 2 | 3 | 2 | 8 | T2 |
| 3 | Format-abstraction interface (multi-format design) | 3 | 3 | 3 | 10 | T2 |
| 4 | C file I/O for exact byte-copying | 2 | 2 | 1 | 5 | T1 (mostly known) |
| 5 | `mmap`/`mprotect` | 3 | 3 | 3 | 10 | T2 |
| 6 | Encryption design: stream cipher, randomness, parameterised key | 3 | 3 | 2 | 9 | T2 |
| 7 | Entry-point patching / code injection | 3 | 3 | 3 | 10→**T3** | T3 (override — this *is* the project) |
| 8 | Position-independent decrypt stub (x86_64 asm) | 3 | 2 | 3 | 8 | T2 |
| 9 | 32-bit stub variant (`int 0x80`, narrower registers) | 2 | 2 | 2 | 6 | T1 (same pattern, second target) |
| 10 | LZSS compression & decompression | 3 | 3 | 3 | 10→**T3** | T3 (override — dedicated time, real learning goal) |
| 11 | Mach-O format & packing | 2 | 3 | 2 | 8 | T2 |
| 12 | *(Bonus)* asm-optimised keystream loop | 1 | 3 | 1 | 6 | T1 — direct libasm continuation |

## Sections

| # | File | Title | Tier | Status | Checkpoint |
|---|---|---|---|---|---|
| 1 | `01-elf-format.md` | ELF file format | T3 | not started | parse & print a real binary's ELF/program headers |
| 2 | `02-defensive-error-handling.md` | Never crash: defensive checks | T2 | not started | reject non-ELF/non-x86_64 input cleanly |
| 3 | `03-format-abstraction.md` | One interface, many formats | T2 | not started | design the format-backend interface |
| 4 | `04-file-io-binary-copying.md` | Exact byte-for-byte file copying | T1 | not started | identity-copy a binary to `woody` |
| 5 | `05-mmap-mprotect.md` | Memory mapping & page permissions | T2 | not started | throwaway: mmap+write+exec demo |
| 6 | `06-encryption-design.md` | Stream cipher, randomness, parameterised key | T2 | not started | standalone encrypt/decrypt roundtrip |
| 7 | `07-entry-point-injection.md` | Entry-point patching & code injection | T3 | not started | inject stub space, patch `e_entry` |
| 8 | `08-decrypt-stub-asm.md` | The position-independent decrypt stub | T2 | not started | full pipeline works on a 64-bit target |
| 9 | `09-32bit-stub-variant.md` | 32-bit: a second stub, same pattern | T1 | not started | full pipeline works on a 32-bit target |
| 10 | `10-lzss-compression.md` | LZSS compression & decompression | T3 | not started | compress-then-encrypt / decrypt-then-decompress works |
| 11 | `11-macho-format.md` | Mach-O format & packing | T2 | not started | full pipeline works on a Mach-O target |
| 12 | `12-asm-optimised-keystream.md` | Vectorising the decrypt loop | T1 | not started | SWAR/SIMD keystream XOR, after everything else is perfect |

## Defence prep
*(populated as sections complete)*

## Deferred / v2
- **PE packing, execution-tested** — needs Wine or a Windows VM. Revisit
  only after the mandatory part and the other four bonuses are solid.
- **Compression beyond LZSS** (e.g. adding Huffman coding on top) — real
  gzip-class compressors do this; out of scope here.
