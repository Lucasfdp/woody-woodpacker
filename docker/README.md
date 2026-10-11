# woody-woodpacker test container

A glibc **x86_64** Linux environment matching the 42 evaluation platform,
with the NASM/ELF toolchain this project actually needs: an mmap/mprotect
smoke test for the core packing mechanism, a 32-bit (`-m32`) path for that
bonus, and a victim-binary generator so there's always something to pack.

Adapted from the libasm container in this repo's neighbour project — same
shape, different centre of gravity: libasm lived and died by glibc PLT calls
(`malloc wrt ..plt`), this one lives and dies by raw `mmap`/`mprotect`/
`syscall` and ELF header surgery.

## Quick start

```sh
cd docker
./run.sh --build --check      # build the image and verify it
./run.sh --targets            # build victim ELF binaries to pack against
./run.sh                      # interactive shell in /workspace
```

Or via make, if you prefer:

```sh
make build && make check
make targets
make shell
```

`run.sh` finds the project root itself, so you can invoke it from anywhere.

---

## Which platform should I use?

Same answer as libasm, for the same reason: there is no choice. The
mandatory part is **64-bit x86 ELF** with a hand-written NASM decrypt stub —
`nasm -f elf64`, raw `syscall`. An arm64 container can't assemble, link, or
correctly run a single instruction of it, so `--platform arm64` doesn't
exist here; it prints an explanation and exits.

The **32-bit bonus** does *not* need a second image. ELF32 is a format
(`nasm -f elf32`, `gcc -m32`, `int 0x80`), not a different host architecture
— it runs fine inside this same amd64 container, which is why the Dockerfile
installs `gcc-multilib` + `libc6-dev-i386`.

The **Mach-O bonus** is the one genuinely different case: a packed Mach-O
binary only *executes* on macOS (or under Rosetta/a Mach-O-aware loader),
so it's developed and tested **natively on the Mac host, outside Docker**.
Nothing in this container tries to build, pack, or run Mach-O — don't go
looking for `otool` in here.

| | mandatory + 32-bit bonus (here) | Mach-O bonus |
|---|---|---|
| Where it runs | this container, linux/amd64 | natively on macOS |
| Native arm64 image | impossible — x86 ELF/asm | n/a, not Docker |
| Emulated amd64 | the only option | n/a |
| valgrind | **may not run** — see below | n/a (use Instruments/lldb natively if needed) |

Docker Desktop → Settings → General → **Use Rosetta for x86_64/amd64
emulation** makes the emulated path noticeably faster.

---

## When valgrind won't run

Both Rosetta and QEMU user-mode conflict with valgrind's dynamic
recompilation — and this project's core trick (write bytes into a page,
flip it RX, jump in) leans on exactly the kind of self-modifying/W^X
behaviour that stresses that recompilation hardest. `./run.sh --check` runs
valgrind against a real assembled mmap/mprotect/jump probe, not just
`/bin/true`, so it tells you which situation you're actually in.

If it fails, use a real x86_64 VM instead of emulation:

```sh
brew install colima docker
colima start --arch x86_64 --vm-type qemu --cpu 4 --memory 6 --disk 30
docker context use colima
cd docker && ./run.sh --rebuild --check
```

That's a genuine x86_64 kernel, so valgrind, gdb, and strace behave exactly
as they do on a 42 iMac. Builds are slower. Switch back with
`docker context use desktop-linux`.

Interim fallback: `-fsanitize=address` on the C side works under emulation
and catches overflows and use-after-free (not leaks as thoroughly), and is
checked by `--check` too.

---

## First thing, every session

```sh
./run.sh --check
```

Verifies, in order: the container is x86_64; glibc not musl; gcc's
default-PIE setting (which decides whether victim binaries you build are PIE
or not — your packer needs to handle both); nasm can emit elf64 *and*
elf32; `gcc -m32` actually works; a hand-assembled probe does a raw
`mmap` → writes machine code into the page by hand → `mprotect`s it
`PROT_READ|PROT_EXEC` → calls into it and gets the right value back — i.e.
the exact mechanism your decrypt stub depends on, proven without any libc
involvement; the same thing again through `nasm -f elf32`/`gcc -m32` for the
32-bit bonus; valgrind on that probe; gdb can ptrace; and the bind mount is
writable.

**Run this before concluding you have a bug.** An emulation problem that
looks like a logic bug (a page that silently stays non-executable, a raw
syscall returning something unexpected) will cost you an afternoon. It
exits non-zero on failure, so you can wire it into CI.

---

## Getting something to pack

Unlike libasm, this project doesn't come with a test suite that diffs
against libc — the "test" is: pack a real binary, run the packed one, and
check it still does what the original did. You need real ELF binaries to
pack, and one plain `gcc` binary isn't enough coverage, because PIE vs
no-PIE and dynamic vs static change the shape of the ELF you're patching.

```sh
./run.sh --targets          # or: make targets, or `targets` inside fish
```

writes a small set of victims under `targets/`:

| Binary | What's different about it |
|---|---|
| `victim64_pie` | 64-bit, dynamic, PIE — gcc's default; `e_entry` is a relative-to-base offset |
| `victim64_nopie` | 64-bit, dynamic, no-PIE — fixed load address |
| `victim64_static` | 64-bit, static — no `PT_INTERP`, no dynamic linker in the picture |
| `victim32_nopie` | 32-bit, dynamic, no-PIE — the bonus target |

Then, once you have a working build:

```sh
make                                     # your own project Makefile
./woody_woodpacker targets/victim64_pie
./woody                                  # should print ....WOODY.... then run identically
```

`hdr`/`segs`/`secs` (fish helpers, see below) are the fast way to check
*why* a given victim behaves differently before and after packing.

---

## Fish helpers

| Command | Does |
|---|---|
| `targets` | build a fresh set of victim binaries under `/workspace/targets` |
| `hdr FILE` | `readelf -h` — ELF header, `e_entry`, type (EXEC/DYN) |
| `segs FILE` | `readelf -l` — program headers/segments: where a stub can go |
| `secs FILE` | `readelf -S` — section headers |
| `nn file.s` | assemble to `.o` and list symbols (`nn -32 file.s` for elf32) |
| `dis FILE` | `objdump -d -M intel` — Intel-syntax disassembly |
| `vg CMD` | valgrind at full 42-defense strictness |

Bash scripts and `run.sh -- cmd` still use `/bin/bash`; fish is interactive-only
(`./run.sh --fish` / `make fish`).

---

## Gotchas

**Build artifacts collide across platforms.** The bind mount is shared
between macOS and the container. If you ever build the ELF side of
something in here *and* the Mach-O side of the same thing natively on the
Mac, keep them in separate output directories — `make` compares timestamps,
not architectures, and a `file`-based mismatch check in `--check` only
warns, it doesn't block you, since mixed Mach-O/ELF output is *expected*
while you're working both bonuses.

**Don't add `--user`.** It costs you the ptrace capability gdb and valgrind
need. If root-owned files on a Linux host bother you, use `make fix-perms`.

**Don't swap to Alpine.** The allowed-functions list and the raw-syscall
path assume glibc's ABI and ELF loader behaviour, matching Debian/Ubuntu —
not musl. `check-env` fails loudly if it ever finds musl.

**Add `.note.GNU-stack` to any `.s` you hand `ld` directly.** Without it the
linker warns that your object implies an executable stack:

```asm
section .note.GNU-stack noalloc noexec nowrite progbits
```

This matters more here than in most projects — you're deliberately building
a page that *is* executable at runtime via `mprotect`, so keep that
transition explicit and intentional rather than falling out of a missing
section marker on an unrelated object.

**`--rm` is intentional.** With the toolchain baked into the image,
containers are disposable. Anything worth keeping belongs in the Dockerfile
or in `/workspace` (the bind mount), never inside the container's own
filesystem.

**The Mach-O bonus lives outside this file entirely.** Don't try to extend
this container to build or run it — there's no useful way to execute a
packed Mach-O binary on Linux. Do that work natively on macOS and keep the
reasoning for the split in `DECISIONS.md`.

---

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | The image. x86_64 only, pinned to ubuntu:22.04, with the 32-bit multilib packages. |
| `run.sh` | Launcher. Detects host arch, warns about emulation, wires up ptrace. |
| `check-env.sh` | Smoke test, baked into the image as `check-env`. |
| `mktargets.sh` | Victim-binary generator, baked into the image as `mktargets`. |
| `Makefile` | Optional convenience targets around `run.sh`. |
| `fish/config.fish` | `targets`, `hdr`, `segs`, `secs`, `nn`, `dis`, `vg` helpers for the fish shell. |
| `valgrind.supp` | Deliberately empty suppression file. |
| `.dockerignore` | Keeps the build context to what the image copies. |
