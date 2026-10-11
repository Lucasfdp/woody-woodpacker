# CLAUDE.md — woody-woodpacker

42 outer-core project **woody-woodpacker** — an x86_64 ELF packer (encrypt +
self-decrypting stub), extended with 32-bit, Mach-O, a parameterised key,
LZSS compression and an asm-optimised decrypt loop. This is a learning
project: Lucas writes all the code himself.

## Hard rules

1. **Do not write implementation code for this project.** The point of this
   repo is that the owner writes it. Explain, diagram, give pseudocode,
   write a failing test, point at the exact line of a bug — but do not
   produce the implementation. *Exception:* throwaway snippets used to
   demonstrate a behaviour, clearly marked as not part of the deliverable.
2. **Do not spoil sections not yet reached.** Read `learn/PROGRESS.md` for
   the current section before answering anything conceptual. Answer at
   that section's depth tier. Don't read ahead into later section files to
   answer. If a question belongs to a later section, say which one and
   give the short version now.
3. **Never paste from `learn/ANSWERS.md`** unless the owner has attempted
   the question or explicitly asks for the answer.
4. **Project constraints:** 64-bit ELF mandatory (reject anything else with
   the subject's exact message); allowed functions only — open, close,
   exit, fputs, fflush, lseek, mmap, munmap, mprotect, perror, strerror,
   syscall, printf family, libft-authorised read/write/malloc/free; must
   never crash; bonuses only count if the mandatory part is perfect.

## Read these, in this order

1. `CLAUDE.md` (this file)
2. `learn/PROGRESS.md` — current section, gates passed, review queue
3. `learn/NN-<current>.md` — the active section
4. `DECISIONS.md` — why things are the way they are

## Where information lives

| Question | File |
|---|---|
| What is X and why does it work that way? | `learn/NN-*.md` |
| What does this term/flag mean? | `learn/GLOSSARY.md` |
| Why was it built this way and not the obvious way? | `DECISIONS.md` |
| What has been learned so far / what's next? | `learn/PROGRESS.md` |

## Commands

```bash
# C side (mandatory + most bonuses)
make                                # builds woody_woodpacker
./woody_woodpacker <target_elf>     # produces ./woody

# ASM side (decrypt stub, asm-optimised loop bonus)
nasm -f elf64 stub.s -o stub.o

python3 scripts/check_learn.py      # verify learn/ and learn_es/ integrity
```

## After you change something

- New decision → add an entry to `DECISIONS.md`
- New term introduced → `learn/GLOSSARY.md` **and** `learn_es/GLOSSARY.md`
- Section finished → update `learn/PROGRESS.md`
- Before ending a session that touched `learn/` → run `scripts/check_learn.py`
