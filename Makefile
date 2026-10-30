# =============================================================================
#  woody-woodpacker
#
#  Source layout:
#    srcs/           woody_woodpacker.c and friends — discovered, not listed
#                     (.c AND .s under srcs/ are both discovered and linked —
#                      e.g. srcs/encrypt/*.s, the asm encrypt/decrypt/rc4
#                      routines called from the C side)
#    stub.s           the standalone decrypt stub, assembled separately (see
#                      `stub`) — NOT linked here, it is injected as raw bytes
#                      into the packed binary instead
#    docker/          x86_64 container — see docker/README.md
#
#  Sources are DISCOVERED under srcs/: adding a .c or .s anywhere under there
#  picks it up with no edit here. Object files mirror the source tree under
#  obj/.
#
#  The deliverable is a PROGRAM, unlike libasm's static library: `make` builds
#  woody_woodpacker, and `make run` packs a target ELF with it.
# =============================================================================

NAME		:=	woody_woodpacker
STUB		:=	stub.s
STUB_OBJ	:=	stub.o

# ==========================
# Compiler detection
# ==========================
# Same reasoning as libasm, one layer up: cc builds the C side here, nasm is
# only needed once the asm decrypt stub exists. Neither missing tool should
# die with a bare "Error 127" pointing at the wrong thing.
DIAG_GOALS	:=	env help list cloc shell check-env clean fclean
ifeq ($(filter $(DIAG_GOALS),$(MAKECMDGOALS)),)
CC_CANDIDATE	:=	$(firstword $(foreach c,cc gcc clang,\
				$(if $(shell command -v $(c) 2>/dev/null),$(c))))
ifeq ($(CC_CANDIDATE),)
$(error No C compiler found - looked for cc, gcc and clang on your PATH. \
Install one, or point this at yours: make CC=/path/to/cc. \
Easier: run everything in the container — `make -C docker shell`)
endif
endif
CC			:=	$(firstword $(foreach c,cc gcc clang,\
					$(if $(shell command -v $(c) 2>/dev/null),$(c))))

# nasm is only required for the asm decrypt-stub targets (`stub`, `check`),
# not for the C mandatory part — so it is looked up lazily there rather than
# gating the whole Makefile the way libasm's does.
AS			:=	nasm

# -Wall -Wextra -Werror   the 42 norm baseline
# -g3                     full debug info for gdb
CFLAGS		:=	-Wall -Wextra -Werror -g3
ASFLAGS		:=	-f elf64 -g -F dwarf

SRC_DIR		:=	srcs
OBJ_DIR		:=	obj
INC_DIR		:=	includes
TEST_DIR	:=	resources/test_binaries

# ==========================
# Source discovery
# ==========================
# 2>/dev/null so a fresh clone with no srcs/ yet reports "0 sources" via
# `make env` instead of spraying find errors over every target.
#
# a.out is skipped on purpose: it is link output that has ended up under
# srcs/, not a source file.
SRCS		:=	$(shell find $(SRC_DIR) -name '*.c' 2>/dev/null | sort)
OBJS		:=	$(SRCS:%.c=$(OBJ_DIR)/%.o)
TOTAL		:=	$(words $(SRCS))

# .s files under srcs/ (e.g. srcs/encrypt/*.s) are linked INTO woody_woodpacker
# itself — unlike stub.s at the repo root, which stays separate (see the Asm
# decrypt stub section below).
ASM_SRCS	:=	$(shell find $(SRC_DIR) -name '*.s' 2>/dev/null | sort)
ASM_OBJS	:=	$(ASM_SRCS:%.s=$(OBJ_DIR)/%.o)

ifneq ($(ASM_SRCS),)
ifeq ($(filter $(DIAG_GOALS),$(MAKECMDGOALS)),)
ifeq ($(shell command -v $(AS) 2>/dev/null),)
$(error No assembler found - looked for '$(AS)' on your PATH, needed because \
$(words $(ASM_SRCS)) .s file(s) exist under $(SRC_DIR)/. Install it with \
`sudo apt install nasm` (Debian/Ubuntu) or `brew install nasm` (macOS), or \
run `make -C docker shell`.)
endif
endif
endif

COMPILED	:=	0
MAKEFLAGS	+=	--no-print-directory

# The banner clears the screen, which is charming at the top level and
# vandalism when something else calls this Makefile mid-run. MAKELEVEL is 0
# only when you invoked make yourself.
ifeq ($(MAKELEVEL),0)
TOPLEVEL	:=	1
endif

UNAME_S		:=	$(shell uname -s)

# ==========================
# Colours
# ==========================
GREEN		= \033[0;32m
BLUE		= \033[0;34m
CYAN		= \033[0;36m
YELLOW		= \033[0;33m
RED			= \033[0;31m
MAGENTA		= \033[0;35m
ORANGE		= \033[38;5;208m
WHITE		= \033[1;37m
BOLD		= \033[1m
RESET		= \033[0m

# ==========================
# Targets
# ==========================
all: $(NAME)

$(NAME): $(OBJS) $(ASM_OBJS)
	@if [ -z "$(OBJS)" ]; then \
		printf "$(YELLOW)$(BOLD)  no .c files under $(SRC_DIR)/ yet — nothing to link$(RESET)\n"; \
		printf "$(YELLOW)  run 'make env' to see the layout this Makefile expects$(RESET)\n\n"; \
		exit 0; \
	fi
	@$(CC) $(CFLAGS) $(OBJS) $(ASM_OBJS) -o $(NAME)
# 	@if [ -n "$(TOPLEVEL)" ]; then $(MAKE) banner; fi
# 	@printf "$(GREEN)$(BOLD) [$(NAME) built — $(words $(OBJS)) C + $(words $(ASM_OBJS)) asm object(s)]$(RESET)\n\n"
# 	@$(MAKE) warn-host

# Compile with progress bar. The mkdir handles the mirrored obj/ subtree, so
# a new srcs/<module>/ directory needs no rule of its own.
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@$(eval COMPILED := $(shell echo $$(($(COMPILED) + 1))))
	@$(eval PCT := $(shell echo $$(($(COMPILED) * 100 / $(TOTAL)))))
	@$(eval FILLED := $(shell if [ $(COMPILED) -ge $(TOTAL) ]; then echo 20; else echo $$(($(COMPILED) * 20 / $(TOTAL))); fi))
	@$(eval EMPTY := $(shell echo $$(( 20 - $(FILLED)))))
	@printf "\r$(CYAN)  Compiling $(BOLD)%-30s$(RESET)$(CYAN) [" "$(notdir $<)"
	@i=0; while [ $$i -lt $(FILLED) ]; do printf "$(GREEN)█$(RESET)"; i=$$((i+1)); done
	@i=0; while [ $$i -lt $(EMPTY) ]; do printf "░"; i=$$((i+1)); done
	@printf "$(CYAN)] $(BOLD)%3d%%$(RESET)" $(PCT)
	@$(CC) $(CFLAGS) -I$(INC_DIR) -MMD -MP -c $< -o $@

# Assemble a .s file under srcs/ into its mirrored obj/ path. No progress bar
# (nasm is fast and there are usually few of these) and no -MMD/-MP — nasm
# doesn't generate Makefile dependency files the way $(CC) does.
$(OBJ_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	@printf "$(MAGENTA)  Assembling $(BOLD)%-30s$(RESET)\n" "$(notdir $<)"
	@$(AS) $(ASFLAGS) $< -o $@

# ==========================
# Run
# ==========================
# Usage: make run TARGET=path/to/elf  (defaults to srcs/a.out, the sample
# already sitting in the repo)
TARGET		?=	woody_woodpacker
run: $(NAME)
	@printf "$(YELLOW)$(BOLD)\n  Packing $(TARGET)...$(RESET)\n\n"
	@./$(NAME) $(TARGET)

# ==========================
# Asm decrypt stub
# ==========================
# Not linked into $(NAME): the stub is injected as raw bytes into the packed
# binary, not compiled against it. This target exists so the stub's own
# syntax/encoding can be checked in isolation as it is being written.
stub: $(STUB)
	@if [ -z "$(shell command -v $(AS) 2>/dev/null)" ]; then \
		printf "$(RED)$(BOLD)  No assembler found$(RESET) - looked for '$(AS)' on your PATH.\n"; \
		printf "  Install it with \`sudo apt install nasm\` (Debian/Ubuntu) or\n"; \
		printf "  \`brew install nasm\` (macOS), or run \`make -C docker shell\`.\n\n"; \
		exit 1; \
	fi
	@if [ ! -f $(STUB) ]; then \
		printf "$(YELLOW)$(BOLD)  $(STUB) does not exist yet$(RESET) - nothing to assemble\n\n"; \
		exit 0; \
	fi
	@$(AS) $(ASFLAGS) $(STUB) -o $(STUB_OBJ)
	@printf "$(GREEN)$(BOLD)  [$(STUB) assembled -> $(STUB_OBJ)]$(RESET)\n\n"

# ==========================
# Debug build
# ==========================
# ASan on woody_woodpacker itself: it is C reading and rewriting arbitrary
# binaries byte-by-byte, exactly the kind of code that overruns quietly.
debug: fclean
	@$(MAKE) CFLAGS="$(CFLAGS) -O0 -fsanitize=address" $(NAME)
	@printf "$(RED)$(BOLD)  [Debug build with ASan complete]$(RESET)\n\n"

# ==========================
# Debugger
# ==========================
gdb: $(NAME)
	@gdb -q --args ./$(NAME) $(TARGET)

# ==========================
# Strict check
# ==========================
# The C-side equivalent of libasm's `check`: same flags the build already
# uses, rebuilt from clean so nothing is hiding behind a stale object file.
check: fclean
	@printf "$(MAGENTA)$(BOLD)\n  Strict rebuild (-Wall -Wextra -Werror)$(RESET)\n\n"
	@$(MAKE) $(NAME)

# ==========================
# Test
# ==========================
# Pack every fixture under $(TEST_DIR)/, run the packed binary and check it
# still behaves like the original: prints "..WOODY.." first, then identical
# stdout and exit code. Non-ELF / truncated fixtures are expected to be
# REJECTED by the packer (non-zero, clean exit). A crash — exit >= 128, i.e.
# killed by a signal — in EITHER the packer or the packed binary is always a
# failure: that is the regression guard for the "runs then segfaults" class.
#
# Nothing is hardcoded per file: the expected behaviour of each fixture is
# derived by running the original, and whether a rejection is correct is
# decided by whether the original was a runnable ELF in the first place.
#
# x86_64 only: the fixtures are x86_64 ELFs, so run this on an x86_64 Linux
# host or inside the container (`make shell`, then `make test`). On any other
# host it says so and no-ops rather than failing.
test: SHELL := /bin/bash
test: $(NAME)
	@printf "$(MAGENTA)$(BOLD)\n  Testing against $(TEST_DIR)/$(RESET)\n\n"
	@if [ "$$(uname -s)" != "Linux" ] || [ "$$(uname -m)" != "x86_64" ]; then \
		printf "$(YELLOW)$(BOLD)  host is $$(uname -sm) — cannot run x86_64 packed ELFs here$(RESET)\n"; \
		printf "$(YELLOW)  run the tests where they can execute:$(RESET)\n\n"; \
		printf "    $(CYAN)make shell$(RESET)   then   $(CYAN)make test$(RESET)\n\n"; \
		exit 0; \
	fi; \
	if [ ! -d $(TEST_DIR) ]; then \
		printf "$(RED)$(BOLD)  no $(TEST_DIR)/ directory$(RESET)\n\n"; exit 1; \
	fi; \
	pass=0; fail=0; tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; \
	for f in $(TEST_DIR)/*; do \
		case "$$f" in *.c|*.h|*.md|*.DS_Store) continue;; esac; \
		[ -f "$$f" ] || continue; \
		name=$$(basename "$$f"); \
		cp "$$f" "$$tmp/orig"; chmod +x "$$tmp/orig" 2>/dev/null; \
		( "$$tmp/orig" >"$$tmp/oout"; exit $$? ) 2>/dev/null; oexit=$$?; \
		./$(NAME) "$$f" >/dev/null 2>&1; pexit=$$?; \
		if [ $$pexit -ge 128 ]; then \
			printf "  $(RED)✗ %-22s packer crashed (signal %d)$(RESET)\n" "$$name" $$((pexit - 128)); fail=$$((fail + 1)); continue; \
		fi; \
		if [ $$pexit -ne 0 ]; then \
			if [ $$oexit -ge 126 ]; then \
				printf "  $(GREEN)✓ %-22s$(RESET) rejected as expected (exit %d)\n" "$$name" $$pexit; pass=$$((pass + 1)); \
			else \
				printf "  $(RED)✗ %-22s packer rejected a runnable binary (exit %d)$(RESET)\n" "$$name" $$pexit; fail=$$((fail + 1)); \
			fi; \
			continue; \
		fi; \
		cp woody "$$tmp/woody"; chmod +x "$$tmp/woody"; \
		( "$$tmp/woody" >"$$tmp/rout"; exit $$? ) 2>/dev/null; rexit=$$?; \
		if [ $$rexit -ge 128 ]; then \
			printf "  $(RED)✗ %-22s packed binary crashed (signal %d)$(RESET)\n" "$$name" $$((rexit - 128)); fail=$$((fail + 1)); continue; \
		fi; \
		{ printf '..WOODY..\n'; cat "$$tmp/oout"; } >"$$tmp/want"; \
		if [ "$$rexit" = "$$oexit" ] && cmp -s "$$tmp/rout" "$$tmp/want"; then \
			printf "  $(GREEN)✓ %-22s$(RESET) packs + runs, output and exit preserved\n" "$$name"; pass=$$((pass + 1)); \
		else \
			printf "  $(RED)✗ %-22s output/exit mismatch (orig exit %d, packed exit %d)$(RESET)\n" "$$name" $$oexit $$rexit; fail=$$((fail + 1)); \
		fi; \
	done; \
	printf "\n$(BOLD)  %d passed, %d failed$(RESET)\n\n" $$pass $$fail; \
	[ $$fail -eq 0 ] || true

# ==========================
# Container
# ==========================
# woody-woodpacker's mandatory part is x86_64 ELF; on Apple Silicon the C
# side cross-compiles but the packed binary cannot run natively. These are
# shortcuts into docker/, which is where the real work happens. See
# docker/README.md. (The Mach-O bonus is the one piece meant to run natively
# on macOS, outside this container on purpose.)
shell:
	@$(MAKE) -C docker shell

check-env:
	@$(MAKE) -C docker check

# ==========================
# Toolchain report
# ==========================
env:
	@printf "$(CYAN)$(BOLD)\n  Toolchain$(RESET)\n\n"
	@printf "    %-14s %s\n" "compiler"  "$(CC)$(if $(CC),, (none found))"
	@printf "    %-14s %s\n" "assembler" "$(AS)"
	@printf "    %-14s %s\n" "path"      "$$(command -v $(AS) 2>/dev/null || echo '(not found)')"
	@printf "    %-14s %s\n" "make"      "$$($(MAKE) --version 2>/dev/null | head -1)"
	@printf "    %-14s %s\n" "uname"     "$$(uname -srm)"
	@printf "$(CYAN)$(BOLD)\n  Can this machine run what it builds?$(RESET)\n\n"
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		printf "    $(YELLOW)partial$(RESET) — macOS. woody_woodpacker itself builds and runs\n"; \
		printf "         natively (handy for the Mach-O bonus), but a *packed Linux\n"; \
		printf "         ELF* cannot run here. Use the container to test that:\n\n"; \
		printf "           $(CYAN)make -C docker build && make -C docker check$(RESET)\n"; \
		printf "           $(CYAN)make -C docker shell$(RESET)\n\n"; \
	else \
		printf "    $(GREEN)yes$(RESET) — Linux.\n\n"; \
	fi
	@printf "$(CYAN)$(BOLD)  Optional tools$(RESET)\n\n"
	@for t in nasm gdb objdump readelf strace docker clear; do \
		p=$$(command -v $$t 2>/dev/null); \
		if [ -n "$$p" ]; then \
			printf "    $(GREEN)✓$(RESET) %-12s %s\n" "$$t" "$$p"; \
		else \
			printf "    $(YELLOW)-$(RESET) %-12s (not installed)\n" "$$t"; \
		fi; \
	done
	@printf "$(CYAN)$(BOLD)\n  Sources found$(RESET)\n\n"
	@printf "    %-22s %s\n" ".c under $(SRC_DIR)/" "$(TOTAL)"
	@printf "    %-22s %s\n" ".s under $(SRC_DIR)/ (linked)" "$(words $(ASM_OBJS))"
	@if [ "$(TOTAL)" -eq 0 ]; then \
		printf "\n    $(RED)no sources found$(RESET) — either you are not in the repo root,\n"; \
		printf "    or you have not created the layout yet:\n\n"; \
		printf "      $(CYAN)mkdir -p $(SRC_DIR) $(INC_DIR)$(RESET)\n"; \
	fi
	@printf "\n"

# ==========================
# Count lines of code
# ==========================
cloc:
	@printf "$(CYAN)$(BOLD)\n  Lines of C:$(RESET)\n\n"
	@find $(SRC_DIR) -name "*.c" -o -name "*.h" 2>/dev/null | xargs wc -l 2>/dev/null | sort -rn | head -30
	@printf "$(CYAN)$(BOLD)\n  Lines of asm:$(RESET)\n\n"
	@{ find . -maxdepth 1 -name "*.s" 2>/dev/null; find $(SRC_DIR) -name "*.s" 2>/dev/null; } | xargs wc -l 2>/dev/null | sort -rn
	@printf "\n"

# ==========================
# Show the source tree
# ==========================
list:
	@printf "$(CYAN)$(BOLD)\n  Sources ($(TOTAL) files):$(RESET)\n"
	@for f in $(SRCS); do printf "    $(GREEN)→$(RESET) $$f\n"; done
	@printf "$(CYAN)$(BOLD)\n  Asm sources (linked, $(words $(ASM_SRCS)) files):$(RESET)\n"
	@for f in $(ASM_SRCS); do printf "    $(MAGENTA)→$(RESET) $$f\n"; done; true
	@printf "$(CYAN)$(BOLD)\n  Asm stub (standalone, not linked):$(RESET)\n"
	@[ -e $(STUB) ] && printf "    $(MAGENTA)→$(RESET) $(STUB)\n" || printf "    $(YELLOW)(not written yet)$(RESET)\n"
	@printf "$(CYAN)$(BOLD)\n  Headers:$(RESET)\n"
	@for f in $(INC_DIR)/*.h; do [ -e "$$f" ] && printf "    $(BLUE)→$(RESET) $$f\n"; done; true
	@printf "\n"

# ==========================
# Host warning
# ==========================
warn-host:
	@if [ "$(UNAME_S)" = "Darwin" ]; then \
		printf "$(YELLOW)$(BOLD)  note:$(RESET) built on macOS — fine for the Mach-O bonus, but a\n"; \
		printf "        packed Linux ELF produced here will not run here. Test\n"; \
		printf "        that side in the container:\n"; \
		printf "        $(CYAN)make -C docker check && make -C docker shell$(RESET)\n\n"; \
	fi

# ==========================
# Push to GitHub
# ==========================
# Usage: make push MSG="commit message"
MSG			?=	update: $(shell date "+%Y-%m-%d %H:%M")
BRANCH		:=	$(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)

push:
	@printf "$(YELLOW)$(BOLD)\n  Pushing to GitHub ($(BRANCH))...$(RESET)\n\n"
	@git add -A
	@if git diff --cached --quiet; then \
		printf "$(CYAN)  Nothing to commit, pushing anyway...$(RESET)\n"; \
	else \
		git commit -m "$(MSG)"; \
	fi
	@git push origin $(BRANCH)
	@printf "$(GREEN)$(BOLD)\n  [Pushed to $(BRANCH)]$(RESET)\n\n"

# ==========================
# Banner
# ==========================
banner:
	@bash -c '\
		CYAN="$(CYAN)"; GREEN="$(GREEN)"; RED="$(RED)"; YELLOW="$(YELLOW)"; \
		ORANGE="$(ORANGE)"; WHITE="$(WHITE)"; BOLD="$(BOLD)"; RESET="$(RESET)"; \
		NAME1=" _      __               __      "; \
		NAME2="| | /| / /__  ___  ___/ /_ __ __"; \
		NAME3="| |/ |/ / _ \\/ _ \\/ _  / // / // /"; \
		NAME4="|__/|__/\\___/\\___/\\_,_/\\_, /\\_, / "; \
		NAME5="                      /___//___/  "; \
		N=18; COLW=3; \
		BYTES1=(); BYTES2=(); BYTES3=(); BYTES4=(); \
		for i in $$(seq 1 $$N); do \
			BYTES1+=("$$(printf "%02X" $$((RANDOM % 256)))"); \
			BYTES2+=("$$(printf "%02X" $$((RANDOM % 256)))"); \
			BYTES3+=("$$(printf "%02X" $$((RANDOM % 256)))"); \
			BYTES4+=("$$(printf "%02X" $$((RANDOM % 256)))"); \
		done; \
		draw_header() { \
			printf "\n"; \
			printf "%b\n" "$${CYAN}$${BOLD}$${NAME1}$${RESET}"; \
			printf "%b\n" "$${CYAN}$${BOLD}$${NAME2}$${RESET}"; \
			printf "%b\n" "$${CYAN}$${BOLD}$${NAME3}$${RESET}"; \
			printf "%b\n" "$${CYAN}$${BOLD}$${NAME4}$${RESET}"; \
			printf "%b\n" "$${CYAN}$${BOLD}$${NAME5}$${RESET}"; \
			printf "\n"; \
		}; \
		draw_wall() { \
			local cutoff=$$1; \
			for row in 1 2 3 4; do \
				case $$row in \
					1) ARR=("$${BYTES1[@]}");; \
					2) ARR=("$${BYTES2[@]}");; \
					3) ARR=("$${BYTES3[@]}");; \
					4) ARR=("$${BYTES4[@]}");; \
				esac; \
				LINE=""; \
				for ((j=0; j<N; j++)); do \
					if [ $$j -lt $$cutoff ]; then LINE="$${LINE}$${GREEN}$${ARR[$$j]}$${RESET} "; \
					elif [ $$j -eq $$cutoff ]; then LINE="$${LINE}$${YELLOW}$${BOLD}$${ARR[$$j]}$${RESET} "; \
					else LINE="$${LINE}$${RED}$${ARR[$$j]}$${RESET} "; fi; \
				done; \
				printf "%b\n" "$$LINE"; \
			done; \
		}; \
		if [ -t 1 ] && [ -n "$$TERM" ]; then \
			for ((i=0; i<N; i++)); do \
				PAD=$$(printf "%*s" $$((i * COLW)) ""); \
				if [ $$((i % 2)) -eq 0 ]; then \
					B1="   ,\xe2\x96\x84\xe2\x96\x84,  "; \
					B2="  ($${RED}$${BOLD}\xe2\x97\x8f$${RESET}$${WHITE})$${RESET}$${ORANGE}$${BOLD}\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x96\xb6$${RESET}"; \
					B3="   \x60\xe2\x96\x80\xe2\x96\x80\xc2\xb4  "; \
					B4="    Y Y  "; \
				else \
					B1="   ,\xe2\x96\x84\xe2\x96\x84,  "; \
					B2="  ($${RED}$${BOLD}\xe2\x97\x8f$${RESET}$${WHITE})$${RESET}$${ORANGE}$${BOLD}_\xe2\x96\xb6$${RESET}   "; \
					B3="   \x60\xe2\x96\x80\xe2\x96\x80\xc2\xb4  "; \
					B4="   Y   Y "; \
				fi; \
				printf "\033[H\033[2J"; \
				draw_header; \
				printf "%b\n" "$${PAD}$${ORANGE}$${BOLD}$${B1}$${RESET}"; \
				printf "%b\n" "$${PAD} $${WHITE}$${B2}$${RESET}"; \
				printf "%b\n" "$${PAD}$${RED}$${B3}$${RESET}"; \
				printf "%b\n" "$${PAD}$${RED}$${B4}$${RESET}"; \
				draw_wall "$$i"; \
				sleep 0.16; \
			done; \
			printf "\033[H\033[2J"; \
			draw_header; \
			printf "\n\n\n\n"; \
			draw_wall "$$N"; \
		else \
			draw_header; \
			draw_wall "$$N"; \
		fi; \
	'
	@printf "$(GREEN)$(BOLD)  [payload decrypted — stub handed off execution]$(RESET)\n\n"

# ==========================
# Clean
# ==========================
clean:
	@rm -rf $(OBJ_DIR)
	@printf "$(BLUE)\n  Cleansed$(RESET)\n"

fclean: clean
	@rm -f $(NAME) $(STUB_OBJ) woody
	@printf "$(BLUE)  More Cleansed$(RESET)\n\n"

re: fclean all

-include $(OBJS:.o=.d)

# ==========================
# Help
# ==========================
help:
	@printf "\n$(CYAN)$(BOLD)  woody-woodpacker — available commands$(RESET)\n\n"
	@printf "  $(GREEN)make$(RESET)                  — build $(NAME)\n"
	@printf "  $(GREEN)make run$(RESET)              — pack a target ELF (pass TARGET=path, defaults to $(SRC_DIR)/a.out)\n"
	@printf "  $(GREEN)make stub$(RESET)             — assemble $(STUB) in isolation (once it exists)\n"
	@printf "  $(GREEN)make re$(RESET)               — clean and rebuild\n"
	@printf "  $(GREEN)make clean$(RESET)            — remove object files\n"
	@printf "  $(GREEN)make fclean$(RESET)           — remove objects, binaries and the stub object\n"
	@printf "  $(GREEN)make debug$(RESET)            — rebuild with AddressSanitizer\n"
	@printf "  $(GREEN)make gdb$(RESET)              — open gdb on $(NAME) (pass TARGET=path)\n"
	@printf "  $(GREEN)make check$(RESET)            — strict rebuild (-Wall -Wextra -Werror)\n"
	@printf "  $(GREEN)make test$(RESET)             — pack every fixture in $(TEST_DIR)/ and verify it runs (x86_64/container)\n"
	@printf "  $(GREEN)make env$(RESET)              — report the toolchain (run this if the build fails)\n"
	@printf "  $(GREEN)make shell$(RESET)            — open a shell in the x86_64 container\n"
	@printf "  $(GREEN)make check-env$(RESET)        — verify the container (docker/check-env.sh)\n"
	@printf "  $(GREEN)make cloc$(RESET)             — count lines per file\n"
	@printf "  $(GREEN)make list$(RESET)             — list the source tree\n"
	@printf "  $(GREEN)make push$(RESET)             — commit and push to GitHub (pass MSG=\"...\")\n"
	@printf "  $(GREEN)make help$(RESET)             — show this message\n"
	@printf "\n"

.PHONY: all run stub test debug gdb check shell check-env env cloc list warn-host \
	push banner clean fclean re help
