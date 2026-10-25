# Test fixtures

All built from the same trivial `hello.c` (just a `write()` + `return`),
compiled different ways to exercise different code paths. All are real,
runnable x86_64 Linux ELF binaries built with gcc on Ubuntu 24.04 — not
hand-crafted/synthetic unless noted.

| File | What it's for |
|---|---|
| `test_static_exec` | Baseline: `ET_EXEC`, statically linked, normal note segments, large (~785 KB) — plenty of padding in the executable segment, should be an easy cave-find case. |
| `test_pie` | `ET_DYN` (PIE) — exercises the ASLR/PIE path; `e_entry` and all `p_vaddr`s are link-time-relative, not fixed load addresses. |
| `test_tight` | `ET_EXEC`, static, built `-Os -s` (optimised for size + stripped) — smaller and leaner than `test_static_exec`; a reasonable "is the default cave actually big enough" stress case. |
| `test_dynamic_note` | `ET_EXEC`, dynamically linked, full default note set (build-id + ABI-tag + GNU property) — normal case for testing `PT_NOTE` detection. |
| `test_no_note` | Built with `-Wl,--build-id=none -fcf-protection=none` to shrink the note segments as far as the toolchain allows. **Caveat:** glibc's default crt startup objects on this toolchain still emit two small `PT_NOTE` entries (ABI-tag + property) — I could not get a genuine zero-`PT_NOTE` binary out of gcc/ld directly. Treat this as "minimal notes," not "no notes." |
| `test_stripped` | Built with `-s` (strip symbols/debug info). Section headers are *not* fully gone — `strip`/`ld -s` only drops symtab-related sections, not the whole section header table. See `test_shnum_zero` for that case. |
| `test_shnum_zero` | A copy of `test_static_exec` with `e_shoff`/`e_shnum`/`e_shstrndx` manually zeroed (same operation your own `prepare_last_segment_strategy`-equivalent step would do) — genuinely `e_shnum == 0`, confirmed it still runs. Good case for testing that your section-header overlap check correctly no-ops when there's nothing to check against. |
| `test_truncated_elf` | First 20 bytes of `test_static_exec` only — smaller than `sizeof(Elf64_Ehdr)` (64 bytes). For the "file too small to be ELF" defensive check. |
| `test_not_elf` | 42 bytes of plain ASCII, no ELF magic at all. For the "bad magic number" defensive check. |
| `hello.c` | Source used for all the compiled fixtures, in case you want to rebuild with different flags or add more variants yourself. |

## Rebuilding / adding more

```sh
gcc -static -no-pie -O0 -o test_static_exec hello.c
gcc -pie -fPIE -O0 -o test_pie hello.c
```

Variants worth adding later if you need them: a binary with a deliberately
tiny executable segment and large data segment (to test picking the right
segment when multiple `PT_LOAD`s exist), and a 32-bit (`-m32`) build once
you're working on that bonus.
