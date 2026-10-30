#!/usr/bin/env bash
# =============================================================================
#  Regenerate / extend the woody-woodpacker test fixtures.
#
#  These are x86_64 Linux ELFs, so run this on x86_64 Linux or inside the
#  project container (`make shell`, then `scripts/make_fixtures.sh`). On any
#  other host (e.g. Apple Silicon) gcc will not emit runnable x86_64 output.
#
#  Default: build the ADDITIONAL compiled fixtures and (re)craft the
#  header-mutation fixtures. Pass --all to also rebuild the base set that
#  resources/test_binaries/README.md documents.
# =============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/resources/test_binaries"
CC="${CC:-gcc}"
cd "$OUT"
say(){ printf '  %s\n' "$*"; }

# --- base set (opt-in) ----------------------------------------------------
if [ "${1:-}" = "--all" ]; then
	say "rebuilding base set"
	$CC -static -no-pie -O0                            -o test_static_exec  hello.c
	$CC -pie -fPIE -O0                                 -o test_pie          hello.c
	$CC -static -Os -s                                 -o test_tight        hello.c
	$CC -O0                                            -o test_dynamic_note hello.c
	$CC -O0 -Wl,--build-id=none -fcf-protection=none   -o test_no_note      hello.c
	$CC -O0 -s                                         -o test_stripped     hello.c
	head -c 20 test_static_exec                         > test_truncated_elf
	printf 'this is just some plain ascii, not an elf\n' > test_not_elf
fi

# --- additional compiled fixtures -----------------------------------------
say "test_ret42        (non-zero exit preserved through packing)"
$CC -static -no-pie -O0 -o test_ret42 hello_ret42.c

say "test_pie_stripped (PIE + stripped at once)"
$CC -pie -fPIE -O0 -s -o test_pie_stripped hello.c

say "test_tiny_text    (tiny code, large RO segment: segment selection)"
$CC -static -no-pie -O0 -o test_tiny_text hello_bigdata.c

if printf 'int main(void){return 0;}' | $CC -m32 -xc - -o /dev/null 2>/dev/null; then
	say "test_32bit        (ELFCLASS32 — mandatory REJECTS; 32-bit bonus should pack)"
	$CC -m32 -static -no-pie -O0 -o test_32bit hello.c
else
	say "test_32bit        SKIPPED — no 32-bit toolchain (apt install gcc-multilib)"
fi

# --- crafted header-mutation fixtures (arch-independent byte edits) --------
say "crafting header-mutation fixtures from test_static_exec"
python3 - "$OUT" <<'PY'
import struct, os, sys
out = sys.argv[1]
d0 = bytearray(open(os.path.join(out, "test_static_exec"), "rb").read())
def craft(name, fn):
    d = bytearray(d0); fn(d)
    open(os.path.join(out, name), "wb").write(d)
    os.chmod(os.path.join(out, name), 0o600)
    print("   ", name)
craft("test_shstrndx_xindex", lambda d: struct.pack_into("<H", d, 62, 0xffff))
craft("test_bad_class",       lambda d: d.__setitem__(4, 1))
craft("test_bad_phoff",       lambda d: struct.pack_into("<Q", d, 32, 0x00000000deadbeef))
craft("test_entry_oob",       lambda d: struct.pack_into("<Q", d, 24, 0))
craft("test_shnum_zero",      lambda d: (struct.pack_into("<Q", d, 40, 0),
                                         struct.pack_into("<H", d, 60, 0),
                                         struct.pack_into("<H", d, 62, 0)))
PY

say "done — run 'make test' to exercise the suite."
