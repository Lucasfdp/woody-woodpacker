#!/usr/bin/env bash
# Platform-aware launcher for the woody-woodpacker test container.
#
# Written for bash 3.2 — the version macOS still ships. No associative
# arrays, no ${var,,}, no mapfile. It has to run on the Mac as well as on
# Linux.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE="woody-env:amd64"

HOST_OS="$(uname -s)"
HOST_ARCH="$(uname -m)"

# Normalise: macOS says arm64, Linux says aarch64, both mean the same thing.
case "$HOST_ARCH" in
    arm64|aarch64) NATIVE_ARCH="arm64" ;;
    x86_64|amd64)  NATIVE_ARCH="amd64" ;;
    *) echo "unsupported host architecture: $HOST_ARCH" >&2; exit 1 ;;
esac

# The mandatory part is x86_64 ELF + a NASM stub. There is no --platform
# choice to make: an arm64 container could not assemble or run a single line
# of it. The 32-bit bonus does NOT need a different image — it's a format
# (nasm -f elf32, gcc -m32) running inside this same amd64 container, same as
# libasm's 64-bit-only story. The flag is accepted only so typing it gives you
# an explanation rather than a confusing nasm/syscall error.
PLATFORM="amd64"
DO_BUILD=0
FORCE_BUILD=0
RUN_CHECK=0
RUN_TARGETS=0
CMD=""

usage() {
    cat <<EOF
Usage: ./run.sh [options] [-- command...]

Options:
  --build           build the image if it is missing
  --rebuild         force a rebuild even if the image exists
  --check           run check-env inside the container and exit
  --targets         build victim ELF binaries under ./targets and exit
  --fish            start fish instead of bash
  --platform ARCH   accepted for symmetry with libasm/ft_ping; amd64 only
  -h, --help        this message

Examples:
  ./run.sh --build --check          # first-time setup and verification
  ./run.sh --targets                # get ELF binaries to pack against
  ./run.sh                          # interactive shell in /workspace
  ./run.sh -- ./woody_woodpacker targets/victim64_pie
  ./run.sh -- gdb ./woody

Note: this container does not build or run the Mach-O bonus. A packed
Mach-O binary only executes on macOS — do that part natively on the host,
outside Docker. See README.md.
EOF
}

START_CMD="/bin/bash"

while [ $# -gt 0 ]; do
    case "$1" in
        --platform) PLATFORM="${2:-}"; shift 2 ;;
        --build)    DO_BUILD=1; shift ;;
        --rebuild)  DO_BUILD=1; FORCE_BUILD=1; shift ;;
        --check)    RUN_CHECK=1; DO_BUILD=1; shift ;;
        --targets)  RUN_TARGETS=1; DO_BUILD=1; shift ;;
        --fish)     START_CMD="/usr/bin/fish"; shift ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; CMD="$*"; break ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

case "$PLATFORM" in
    amd64|native) PLATFORM="amd64" ;;
    arm64)
        cat >&2 <<'EOF'
The mandatory part of woody-woodpacker is 64-bit x86 ELF + NASM (and the
32-bit bonus is the same arch family, just -m32 / -f elf32). An arm64
container cannot assemble, link, or correctly run any of it, so there is no
arm64 image to build.

This is the same story as libasm: there, arm64 was never an option either.
Everything runs emulated on an Apple Silicon Mac. If valgrind fails under
emulation, see README.md -> "When valgrind won't run".

The Mach-O bonus is the exception, but it's intentionally NOT built here —
it runs natively on the Mac host, outside Docker, since only macOS can
execute a packed Mach-O binary.
EOF
        exit 1 ;;
    *) echo "--platform must be amd64 (got: $PLATFORM)" >&2; exit 1 ;;
esac

command -v docker >/dev/null || { echo "docker not found on PATH" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon not reachable — is Docker Desktop running?" >&2; exit 1; }

EMULATED=0
[ "$PLATFORM" != "$NATIVE_ARCH" ] && EMULATED=1

if [ "$DO_BUILD" -eq 1 ]; then
    if [ "$FORCE_BUILD" -eq 1 ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo ">> building $IMAGE (linux/$PLATFORM)"
        [ "$EMULATED" -eq 1 ] && echo "   emulated build — this will take a while"
        docker build --platform "linux/$PLATFORM" -t "$IMAGE" "$SCRIPT_DIR"
    fi
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "image $IMAGE not found. Run: ./run.sh --build" >&2
    exit 1
fi

echo ">> host: $HOST_OS/$NATIVE_ARCH   container: linux/$PLATFORM$([ "$EMULATED" -eq 1 ] && echo "  (emulated)")"
if [ "$EMULATED" -eq 1 ] && [ "$HOST_OS" = "Darwin" ]; then
    echo ">> note: valgrind is unreliable under x86_64 emulation on Apple Silicon,"
    echo "         and there is no native fallback for the mandatory ELF/NASM path."
    echo "         Run --check to find out where you stand; README.md has the"
    echo "         real-VM workaround. (The Mach-O bonus runs natively on macOS"
    echo "         instead, so it isn't affected by any of this.)"
fi

# --cap-add=SYS_PTRACE          gdb and valgrind both need to trace the process
# --security-opt seccomp=unconfined  the default seccomp profile blocks some of
#                               what valgrind, ptrace, and raw mmap/mprotect
#                               syscalls want; this is a local dev box on your
#                               own code, not a sandbox for untrusted binaries,
#                               so the trade is worth it
# HOST_ARCH                     lets check-env report emulation accurately
#                               instead of guessing from /proc
DOCKER_ARGS="--rm --platform linux/$PLATFORM \
    --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
    -e HOST_ARCH=$NATIVE_ARCH \
    -v $PROJECT_ROOT:/workspace -w /workspace"

# shellcheck disable=SC2086  # DOCKER_ARGS is intentionally word-split
if [ "$RUN_CHECK" -eq 1 ]; then
    exec docker run $DOCKER_ARGS "$IMAGE" check-env
elif [ "$RUN_TARGETS" -eq 1 ]; then
    exec docker run $DOCKER_ARGS "$IMAGE" mktargets /workspace/targets
elif [ -n "$CMD" ]; then
    exec docker run -it $DOCKER_ARGS "$IMAGE" /bin/bash -lc "$CMD"
else
    exec docker run -it $DOCKER_ARGS "$IMAGE" "$START_CMD"
fi
