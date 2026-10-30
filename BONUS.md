# Bonus — status and what's left

Tracks the bonus scope for woody-woodpacker: what is done, what remains, and
the order that keeps the mandatory part safe. Rationale for each choice lives
in `DECISIONS.md`; this file is the checklist, not the argument.

Status is read off the current `srcs/` tree — if code lands that this doesn't
reflect, update it.

Legend: ✅ done · 🟡 partial · ⬜ not started · ⏸ deferred by choice

---

## Mandatory (baseline the bonuses build on)

Effectively complete: parses/validates x86_64 ELF, finds a code cave, encrypts
the payload (RC4 keystream XOR), injects the decrypt stub, repoints the entry,
and the packed binary prints `..WOODY..` then runs identically.

Two recent fixes worth remembering because the bonuses can re-break them:
- **Stub preserves `rdx`** (the loader's `rtld_fini`) across to the original
  entry — otherwise a dynamic binary runs then segfaults *at exit*.
- **Section→segment fallback** when `.text` can't be found by name
  (stripped / `e_shnum == 0`): encrypt `[e_entry, p_vaddr+p_filesz)` of the
  executable `PT_LOAD` instead.

Coverage: `make test` over `resources/test_binaries/` (positive round-trip +
defensive rejection + crash-guard). Regenerate/extend fixtures with
`scripts/make_fixtures.sh`.

---

## Bonuses

### 1. Parameterised key — ✅ done
- **Where:** `srcs/key/key.c` (`resolve_key`), wired in `srcs/main.c`
  (`./woody_woodpacker <elf> [key]`); the stub reads the embedded
  `key_len`/`key` fields, so any length works at decrypt time.
- **Left:** C side caps a passed key at `KEY_LEN` (16 bytes) — decide if that
  cap is intended or should grow toward the stub's 32-byte field. Optional:
  accept a key from an environment variable as well as argv.

### 2. 32-bit ELF support — ⬜ not started
- **Where:** nothing yet; mandatory currently rejects `ELFCLASS32`
  (fixtures `test_bad_class`, and `test_32bit` once built).
- **Left:** an ELF32 parse path (`Elf32_Ehdr`/`Phdr`, bounds checks), a
  dedicated 32-bit stub (`int 0x80`, 32-bit registers — no code shared with
  the 64-bit stub, per DECISIONS), and 32-bit injection. Flip
  `test_32bit`/`test_bad_class` from "rejected" to "packs + runs" once done.

### 3. LZSS compression — ⬜ not started
- **Where:** nothing yet (no compressor on the pack side, no decompress stage
  in the stub).
- **Left:** an LZSS compressor (C, pack side) and an overlapping-copy
  decompressor in the stub (asm). Pipeline is fixed by DECISIONS:
  compress-then-encrypt packing; decrypt-then-decompress in the stub. Must
  never crash on malformed input — mandatory always wins.

### 4. Mach-O (full) — ⬜ not started
- **Where:** nothing yet; current code is ELF-specific.
- **Left:** Mach-O parse, an injection point (code cave or an added
  segment/load command), entry patch (`LC_MAIN` / `LC_UNIXTHREAD`), and a
  Mach-O stub. Verifiable natively on the Mac (that's why it beat PE).
- **Prerequisite:** the format-backend seam below.

### 5. Asm-optimised decrypt loop (SIMD) — ⏸ deferred
- **Where:** scalar RC4 in `srcs/encrypt/`; stub has its own copy.
- **Left:** a SIMD keystream/XOR path. Deferred by choice until the mandatory
  part and the other bonuses are solid — reuses the libasm SIMD mental model.

### PE (full) — ⏸ deferred / structural-only
- Rejected as primary (can't execute a packed PE without Wine/VM). If attempted
  at all: header/offset correctness only, presented as such at evaluation.

---

## Prerequisite not yet built: the format-backend seam

`DECISIONS.md` (2026-10-11) commits to a backend interface
(`parse_header` / `find_injection_point` / `patch_entry` / `write_output`),
one implementation per format. The current `srcs/` is still ELF64-specific
(`parse.c`, `inject.c` manipulate `Elf64_*` directly). Realising this seam is
the natural first step before 32-bit and Mach-O, so those land as backends
rather than by tearing the core apart.

## Suggested order

1. Finish mandatory hardening (the new defensive fixtures all behaving).
2. Extract the format-backend seam (refactor, no new behaviour).
3. 32-bit ELF (closest to existing ELF64 — shares structure).
4. Mach-O (the headline additional-format bonus, natively verifiable).
5. LZSS compression.
6. Asm-optimised decrypt loop.
7. PE — only if time remains, structural-only.
