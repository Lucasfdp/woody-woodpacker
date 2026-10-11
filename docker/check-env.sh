#!/usr/bin/env bash
# Smoke test for the woody-woodpacker container. Run this FIRST, before
# blaming your code.
#
# Exits non-zero if anything that would stop the packer working is broken, so
# it can be used in a Makefile target or CI step, not just read by a human.
set -uo pipefail

pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
warn() { printf '  \033[33mwarn\033[0m %s\n' "$1"; }
note() { printf '       %s\n' "$1"; }
FAILED=0
T=/tmp/_woody_check
mkdir -p "$T"

echo "woody-woodpacker environment check"
echo

# --- platform ----------------------------------------------------------------
echo "platform"
ARCH="$(uname -m)"
printf '  container arch: %s   ' "$ARCH"
case "$ARCH" in
    x86_64)  echo "(correct — the mandatory path is x86_64 ELF + NASM)" ;;
    aarch64) echo "(WRONG)" ;;
    *)       echo "(unexpected)" ;;
esac
if [ "$ARCH" != "x86_64" ]; then
    fail "container is not x86_64 — nasm -f elf64 code cannot run here"
    note "rebuild with --platform amd64; there is no arm64 variant of this project"
fi

# Emulation detection. run.sh passes HOST_ARCH in; fall back to heuristics if
# the container was started by hand.
EMULATED="no"
if [ "${HOST_ARCH:-}" = "arm64" ] && [ "$ARCH" = "x86_64" ]; then EMULATED="yes"; fi
[ -e /proc/sys/fs/binfmt_misc/rosetta ] && EMULATED="rosetta"
grep -qsi qemu /proc/cpuinfo && EMULATED="qemu"
if [ "$EMULATED" != "no" ]; then
    note "running under x86_64 emulation ($EMULATED) — see the memory-checking section below"
fi

LIBC_VER="$(ldd --version 2>/dev/null | sed -n '1p')"
printf '  libc: %s\n' "${LIBC_VER:-unknown}"
if printf '%s' "$LIBC_VER" | grep -qi musl; then
    fail "musl libc detected — this image must be glibc-based"
    note "stick to Debian/Ubuntu glibc, matching the 42 evaluation machines"
else
    pass "glibc (matches the evaluation platform)"
fi

# Default-PIE matters here for a different reason than in libasm: it decides
# whether the victim binaries you build (and the ones the moulinette hands
# you) are PIE or not, which changes e_entry's relationship to the base load
# address and which segment you can safely extend to hold the stub.
if gcc -v 2>&1 | grep -q -- '--enable-default-pie'; then
    pass "gcc defaults to PIE (same as the 42 machines) — your packer must handle PIE *and* -no-pie targets"
else
    warn "gcc does NOT default to PIE here — build with -no-pie explicitly if you need to match a non-PIE target"
fi
echo

# --- toolchain ---------------------------------------------------------------
echo "toolchain"
for t in nasm gcc ld ar nm objdump readelf eu-readelf make gdb strace patchelf; do
    command -v "$t" >/dev/null && pass "$t" || fail "$t missing"
done
if command -v nasm >/dev/null; then
    printf '       %s\n' "$(nasm -v)"
    if nasm -hf 2>&1 | grep -q 'elf64'; then
        pass "nasm supports -f elf64 (mandatory stub)"
    else
        fail "nasm cannot emit elf64 — wrong build of nasm"
    fi
    if nasm -hf 2>&1 | grep -q 'elf32'; then
        pass "nasm supports -f elf32 (32-bit bonus stub)"
    else
        warn "nasm cannot emit elf32 — 32-bit bonus stub will not assemble"
    fi
fi
if gcc -m32 -xc -o "$T/m32test" - <<<'int main(void){return 0;}' 2>"$T/m32err"; then
    pass "gcc -m32 works (gcc-multilib + libc6-dev-i386 are wired up)"
else
    fail "gcc -m32 failed — 32-bit bonus can't compile victims or link its stub"
    sed 's/^/       /' "$T/m32err"
fi
echo

# --- the thing that actually matters -----------------------------------------
# A toolchain that is merely *installed* proves nothing. The core mechanism of
# this whole project is: write bytes into a page, flip it executable, jump in.
# Prove that works end to end before trusting anything built on top of it.
echo "core mechanism: mmap + mprotect + jump into written code (via raw syscall)"
cat > "$T/stub_probe.s" <<'EOF'
; Mirrors the actual packer mechanism: mmap an RW page, write a tiny payload
; into it by hand (no libc), mprotect it RX, then call into it. If this
; works, the decrypt-stub mechanism will work; if it doesn't, nothing built
; on top of it will either.
section .text
global main
main:
    ; mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
    xor edi, edi            ; addr = NULL
    mov rsi, 4096            ; length
    mov edx, 3               ; PROT_READ|PROT_WRITE
    mov r10d, 0x22           ; MAP_PRIVATE|MAP_ANONYMOUS
    mov r8, -1                ; fd
    xor r9, r9                ; offset
    mov eax, 9                ; __NR_mmap
    syscall
    cmp rax, -1
    je .fail
    mov r15, rax             ; r15 = page base

    ; write a tiny payload by hand: mov eax, 42 ; ret
    mov byte [r15],   0xb8   ; mov eax, imm32
    mov dword [r15+1], 42
    mov byte [r15+5], 0xc3   ; ret

    ; mprotect(page, 4096, PROT_READ|PROT_EXEC)
    mov rdi, r15
    mov rsi, 4096
    mov edx, 5               ; PROT_READ|PROT_EXEC
    mov eax, 10              ; __NR_mprotect
    syscall
    cmp rax, 0
    jne .fail

    ; jump into the page we just wrote and flipped executable
    call r15
    cmp eax, 42
    jne .fail
    xor eax, eax
    ret
.fail:
    mov eax, 1
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
EOF
if nasm -f elf64 -g -F dwarf "$T/stub_probe.s" -o "$T/stub_probe.o" 2>"$T/err" \
   && ld "$T/stub_probe.o" -o "$T/stub_probe" 2>>"$T/err"; then
    pass "assembled and linked the mmap/mprotect/jump probe (no libc involved)"
    "$T/stub_probe"; RC=$?
    if [ "$RC" -eq 0 ]; then
        pass "mmap -> write bytes -> mprotect RX -> call worked end to end"
        note "this is exactly the mechanism your decrypt stub depends on"
    elif [ "$RC" -eq 1 ]; then
        fail "a raw mmap/mprotect syscall failed or the written page didn't run as 42"
        note "under some emulators raw syscalls or W^X page transitions behave differently than on real Linux"
    else
        fail "probe crashed (exit $RC) instead of returning cleanly"
    fi
else
    fail "could not assemble/link the mmap/mprotect probe"; sed 's/^/       /' "$T/err"
fi
echo

# --- 32-bit path --------------------------------------------------------------
echo "32-bit bonus path (int 0x80, narrower registers)"
cat > "$T/probe32.s" <<'EOF'
BITS 32
section .text
global main
main:
    mov eax, 42
    ret
EOF
if nasm -f elf32 "$T/probe32.s" -o "$T/probe32.o" 2>"$T/err32" \
   && gcc -m32 "$T/probe32.o" -o "$T/probe32" -nostartfiles -e main 2>>"$T/err32"; then
    pass "nasm -f elf32 assembles and gcc -m32 links a 32-bit NASM object"
    "$T/probe32"; RC=$?
    [ "$RC" -eq 42 ] && pass "the 32-bit binary runs and returns the right value" \
                     || fail "32-bit binary ran but returned $RC instead of 42"
else
    warn "32-bit nasm/link path failed — fine to skip if you haven't started the 32-bit bonus yet"
    sed 's/^/       /' "$T/err32"
fi
echo

# --- memory checking ---------------------------------------------------------
# This is the one that decides whether the container is good enough on its
# own. "Must never crash" makes this a correctness requirement, not a nicety.
echo "memory checking"
if command -v valgrind >/dev/null; then
    printf '       %s\n' "$(valgrind --version)"
    if [ -x "$T/stub_probe" ] && valgrind -q --error-exitcode=99 "$T/stub_probe" >"$T/vg" 2>&1; then
        pass "valgrind runs the mmap/mprotect probe correctly"
    elif valgrind --error-exitcode=99 /bin/true >/dev/null 2>&1; then
        warn "valgrind runs trivial programs but failed on the mmap/mprotect probe"
        sed 's/^/       /' "$T/vg" | head -8
        if [ "$EMULATED" != "no" ]; then
            note "valgrind's dynamic recompilation and self-modifying RWX/RX page tricks"
            note "don't always play well together even on bare metal; under emulation,"
            note "expect more of this. A clean run here is reassuring, not required."
        fi
    else
        fail "valgrind cannot run here"
        if [ "$EMULATED" != "no" ]; then
            note "expected: valgrind's dynamic recompilation conflicts with Rosetta"
            note "and QEMU user-mode emulation. As in libasm, there is no native"
            note "arm64 fallback — the mandatory part has to be x86_64."
            note "Options: (1) a real x86_64 VM —"
            note "    colima start --arch x86_64 --vm-type qemu --cpu 4 --memory 6"
            note "    docker context use colima && ./run.sh --rebuild --check"
            note "  (2) -fsanitize=address on the C driver, checked below."
        fi
    fi
else
    fail "valgrind missing"
fi

echo 'int main(void){return 0;}' > "$T/asan.c"
if gcc -fsanitize=address "$T/asan.c" -o "$T/asan" 2>/dev/null && "$T/asan" 2>/dev/null; then
    pass "AddressSanitizer available (works under emulation too)"
else
    warn "AddressSanitizer unavailable"
fi
echo

# --- debugger ----------------------------------------------------------------
# gdb needs ptrace, which needs --cap-add=SYS_PTRACE. Stepping through the
# stub after entry-point patching is most of how you debug a bad injection.
echo "debugger"
if [ -x "$T/stub_probe" ] && gdb -batch -ex run -ex quit "$T/stub_probe" >"$T/gdb" 2>&1; then
    pass "gdb can run a process (ptrace works)"
else
    if grep -qi 'operation not permitted\|ptrace' "$T/gdb" 2>/dev/null; then
        fail "gdb cannot ptrace — add --cap-add=SYS_PTRACE to docker run"
    else
        warn "gdb did not complete a batch run"
        sed 's/^/       /' "$T/gdb" 2>/dev/null | head -5
    fi
fi
if command -v gdb >/dev/null && gdb -batch -ex 'set disassembly-flavor intel' -ex quit >/dev/null 2>&1; then
    pass "gdb accepts Intel disassembly flavour"
fi
echo

# --- workspace ---------------------------------------------------------------
echo "workspace"
if [ -d /workspace ]; then
    if touch /workspace/.woody_write_test 2>/dev/null; then
        rm -f /workspace/.woody_write_test
        pass "/workspace is writable (bind mount is live)"
    else
        fail "/workspace is not writable — check the -v bind mount"
    fi
    # The cross-platform artifact trap: ELF .o/.a built on Linux won't mix with
    # Mach-O. Unlike libasm, intentional Mach-O output is NOT a mistake here —
    # the Mach-O bonus is built natively on macOS, outside this container, so
    # it should simply never show up inside /workspace's *Linux* build output
    # (obj/, target binaries you build with `make` in here). Flag it, don't
    # fail the check over it — this can legitimately be a work-in-progress mix.
    STALE=$(find /workspace -maxdepth 3 \( -name '*.o' -o -name '*.a' \) 2>/dev/null | head -50)
    BAD=""
    for f in $STALE; do
        file -b "$f" 2>/dev/null | grep -qi 'mach-o\|arm64\|aarch64' && BAD="$BAD $f"
    done
    if [ -n "$BAD" ]; then
        warn "non-x86_64/Mach-O object files in the bind mount:$BAD"
        note "expected if these came from the Mach-O bonus work done natively on macOS;"
        note "a problem only if you meant to build the ELF (Linux) side of these."
    else
        pass "no foreign object files in the Linux build output"
    fi
else
    warn "/workspace missing — started without the bind mount?"
fi
echo

# --- extras ------------------------------------------------------------------
echo "extras"
for t in fish rg strace cppcheck xxd eu-readelf mktargets; do
    command -v "$t" >/dev/null && pass "$t" || warn "$t missing"
done
echo

rm -rf "$T"

if [ "$FAILED" -eq 0 ]; then
    echo "environment looks good."
else
    echo "environment has problems — fix these before writing code."
    exit 1
fi
