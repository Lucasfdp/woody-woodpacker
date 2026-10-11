# Convenience wrapper around run.sh. Everything here is optional — run.sh
# works alone.
#
# Unlike the ft_ping version there is no native-arch daily driver to pick:
# the mandatory part is x86_64 ELF + NASM, so the only image that exists is
# linux/amd64 — same story as libasm. The 32-bit bonus runs inside that same
# image (it's a format, not a different host arch). The Mach-O bonus is
# built and run natively on macOS, outside Docker entirely — there's no make
# target for it here on purpose.

RUN      := ./run.sh
UNAME_M  := $(shell uname -m)
ifeq ($(filter arm64 aarch64,$(UNAME_M)),)
HOSTNOTE := native x86_64 — no emulation
else
HOSTNOTE := arm64 host — the container runs emulated
endif

.PHONY: help build rebuild shell fish check targets clean fix-perms

help:
	@echo "woody-woodpacker docker environment  ($(HOSTNOTE))"
	@echo
	@echo "  make build         build the x86_64 image"
	@echo "  make rebuild       force a rebuild"
	@echo "  make check         verify the environment    <- run this first"
	@echo "  make targets       build victim ELF binaries to pack against"
	@echo "  make shell         interactive bash shell    <- daily driver"
	@echo "  make fish          interactive fish shell"
	@echo "  make clean         remove the image"
	@echo "  make fix-perms     chown build artifacts back to you (Linux hosts)"
	@echo
	@echo "Mach-O bonus: not here. Build/run it natively on macOS — see README.md."

build:
	@$(RUN) --build -- true

rebuild:
	@$(RUN) --rebuild -- true

shell:
	@$(RUN)

fish:
	@$(RUN) --fish

check:
	@$(RUN) --check

targets:
	@$(RUN) --targets

clean:
	-docker image rm woody-env:amd64 2>/dev/null || true

# On a Linux host the container runs as root, so anything it writes into the
# bind mount ends up root-owned on your machine. macOS/Docker Desktop maps
# ownership for you, so this is a no-op there.
fix-perms:
	@if [ "$$(uname -s)" = "Linux" ]; then \
		sudo chown -R "$$(id -u):$$(id -g)" .. && echo "ownership restored"; \
	else \
		echo "not needed on $$(uname -s)"; \
	fi
