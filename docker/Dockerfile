# woody-woodpacker test environment — matches the 42 evaluation platform (Debian/Ubuntu + glibc).
#
# x86_64 ONLY. The mandatory part is a 64-bit ELF packer with a hand-written
# position-independent decrypt stub; nasm -f elf64 and the mmap/mprotect/syscall
# path only exist on x86_64. Like libasm, there is no native option on an Apple
# Silicon Mac — everything runs emulated, and valgrind is the one tool that
# genuinely suffers for it. check-env reports on that explicitly.
#
# The 32-bit bonus (int 0x80, narrower registers) still runs inside this SAME
# amd64 container — ELF32 is a format choice (nasm -f elf32, gcc -m32), not a
# different host architecture, so no second image is needed. gcc-multilib +
# libc6-dev-i386 below are what make `gcc -m32` and 32-bit targets possible.
#
# The Mach-O bonus is NOT built or run in here. A packed Mach-O binary only
# executes on macOS, so that bonus is developed and tested natively on the
# Mac host, outside Docker. This image is Linux/ELF only — see README.md.
#
# Do NOT swap this for Alpine. The decrypt stub and C driver use raw syscalls
# and the allowed-functions list (open/close/exit/mmap/mprotect/printf family/
# etc.) against glibc's ABI; musl's syscall wrappers and ELF loader behaviour
# are not what you're graded against.
#
# Pinned, not :latest — a floating base tag means your environment silently
# changes under you mid-project, which is the opposite of what a test
# environment is for.
FROM ubuntu:22.04
ARG TARGETARCH
LABEL org.opencontainers.image.title="woody-woodpacker test environment" \
      org.opencontainers.image.description="glibc x86_64 Linux for 42 woody-woodpacker (ELF packer, NASM stub)" \
      woody.arch="${TARGETARCH}"

ARG DEBIAN_FRONTEND=noninteractive

# Toolchain + the diagnostic tools an ELF packer actually calls for.
#   nasm              assembles the decrypt stub (-f elf64, and -f elf32 for the
#                      32-bit bonus — nasm supports both from one install)
#   build-essential    gcc/ld/ar/make — the C side (parsing, mmap, injection,
#                      entry-point patching) is the bulk of the mandatory part
#   gcc-multilib       gcc -m32: compile 32-bit ELF victim binaries and link a
#                      32-bit stub for the bonus. Without this, -m32 just fails.
#   libc6-dev-i386     32-bit glibc headers/libs, the other half of -m32 support
#   binutils           nm / objdump / readelf: readelf -h/-l is how you read
#                      e_entry, program headers and segment flags — i.e. most
#                      of what this project is actually about
#   elfutils            eu-readelf as a second, independently-implemented
#                      opinion on the same ELF — useful when you suspect your
#                      own reading of the spec, not the binary, is wrong
#   gdb                stepping the injected stub instruction-by-instruction
#                      after entry-point patching. Needs --cap-add=SYS_PTRACE.
#   valgrind           "must never crash" is a hard subject requirement, not a
#                      style note — catches bad mmap/mprotect use and
#                      wild writes while patching. See the emulation note below.
#   strace             proves exactly what mmap/mprotect/syscall your stub (or
#                      your C code) issued, with real arguments and return
#                      values — the fastest way to debug "it segfaults on run"
#   clang              -fsanitize=address as the valgrind-under-emulation fallback
#   cppcheck           lints the C side, not the asm stub
#   patchelf            a second, trusted ELF patcher to diff your own patched
#                      header/segments against, when you suspect your by-hand
#                      patch (not patchelf's) is the one that's wrong
#   file/xxd/bsdmainutils  inspecting magic bytes and hex-dumping the encrypted
#                      payload you produce
#   fish               requested as the interactive shell; bash stays the
#                      CMD-safe default for scripts and `run.sh -- cmd`
RUN apt-get update && apt-get install -y --no-install-recommends \
        nasm \
        build-essential \
        gcc-multilib \
        libc6-dev-i386 \
        make \
        binutils \
        elfutils \
        libc6-dev \
        gdb \
        valgrind \
        strace \
        clang \
        cppcheck \
        patchelf \
        file \
        xxd \
        bsdmainutils \
        python3 \
        ripgrep \
        tree \
        curl \
        ca-certificates \
        git \
        vim \
        nano \
        less \
        man-db \
        fish \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Fail loudly and early if the toolchain or the mmap/mprotect/syscall path is
# broken, instead of debugging an emulation problem as if it were a bug in
# your packer.
COPY check-env.sh /usr/local/bin/check-env
RUN chmod +x /usr/local/bin/check-env

# The packer needs *something* to pack. mktargets builds a small, varied set of
# victim ELF binaries (PIE/no-PIE/static/32-bit) under /workspace/targets so
# there's always something to run `./woody_woodpacker` against.
COPY mktargets.sh /usr/local/bin/mktargets
RUN chmod +x /usr/local/bin/mktargets

# Interactive niceties for fish. Deliberately not the CMD: scripts and `run.sh
# -- cmd` expect a POSIX shell, so bash stays the default and fish is opt-in.
COPY fish/config.fish /root/.config/fish/config.fish

# Empty on purpose — a leak or an invalid-access you suppressed is one you
# still have at defense.
COPY valgrind.supp /etc/valgrind/woody.supp
ENV VALGRIND_OPTS="--suppressions=/etc/valgrind/woody.supp"

CMD ["/bin/bash"]
