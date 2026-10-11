#!/usr/bin/env bash
# Builds a small, varied set of ELF "victim" binaries to run
# ./woody_woodpacker against. The packer has to handle whatever kind of ELF
# it's handed, so one plain dynamic PIE binary is not enough test coverage —
# PIE vs no-PIE changes how e_entry relates to the load base, and static vs
# dynamic changes whether there's a PT_INTERP segment and a dynamic linker
# in the picture at all.
set -euo pipefail

OUT="${1:-/workspace/targets}"
mkdir -p "$OUT"

SRC="$(mktemp --suffix=.c)"
trap 'rm -f "$SRC"' EXIT
cat > "$SRC" <<'EOF'
#include <stdio.h>
int main(void)
{
    printf("original binary ran fine\n");
    return 0;
}
EOF

build() { # build <outfile> <description> <gcc args...>
    local out="$1" desc="$2"; shift 2
    if gcc "$SRC" -o "$OUT/$out" "$@" 2>"$OUT/.${out}.err"; then
        echo "  built  $out  ($desc)"
        rm -f "$OUT/.${out}.err"
    else
        echo "  SKIP   $out  ($desc) — see $OUT/.${out}.err"
    fi
}

echo "writing victim binaries to $OUT"
build victim64_pie    "64-bit, dynamic, PIE (gcc default)"
build victim64_nopie  "64-bit, dynamic, no-PIE"             -no-pie
build victim64_static "64-bit, static (no PT_INTERP)"       -static
build victim32_nopie  "32-bit, dynamic, no-PIE (bonus)"     -m32 -no-pie

echo
echo "quick look:"
file "$OUT"/victim* 2>/dev/null || true
echo
echo "entry points and program headers, e.g.:"
echo "  readelf -h $OUT/victim64_pie | grep Entry"
echo "  readelf -l $OUT/victim64_pie"
