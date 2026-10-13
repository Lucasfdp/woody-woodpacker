---
section: 4
slug: file-io-binary-copying
tier: T1
status: not-started
prereqs: [1, 3]
terms: [O_CREAT / O_TRUNC / O_WRONLY, file mode bits, short write]
---

# Section 4 — Exact byte-for-byte file copying

**Depth: T1** — you already read a whole file in `main.c`; this section is
the missing other half, writing one out, plus the two details that are easy
to get wrong.
**You'll be able to:** produce `woody`, a byte-for-byte copy of the input
binary, as a new executable file with the right permissions — the
foundation every later section modifies instead of rebuilding.

## The idea

You already know how to read a file fully into memory — `main.c` does it
with `open` + `fstat` + `malloc` + `read`. Writing one out is the same shape
in reverse, but two things bite people who haven't done it before: the file
you create needs to say *at creation time* who's allowed to run it, and a
single call to `write()` is not actually guaranteed to write every byte you
asked it to.

## The names for it

**`O_CREAT` / `O_TRUNC` / `O_WRONLY`** — flags passed to `open()`, combined
with `|`. **O**pen flag: **CREAT**e the file if it doesn't exist.
**O**pen flag: **TRUNC**ate it to zero length first if it already does (so
leftover bytes from a previous run don't survive underneath your new,
possibly shorter, content). **O**pen flag: **W**rite **ONLY** — you're not
reading this file back in the same program run.

**File mode bits** — when `O_CREAT` is used, `open()` takes a third
argument, the permission bits the new file is created with (e.g. `0755`):
who can read, write, and — critically here — execute it. Miss this and
`woody` exists but the OS refuses to run it, with no connection in the error
message back to "you forgot the mode argument."

**Short write** — `write()`'s return value is how many bytes it actually
wrote, which is allowed to be *less* than what you asked for, even with no
error. This is rare for a local file and a small buffer, but the subject's
"never crash" rule means you check it, not assume it.

## How it actually works

1. Open the output: `open("woody", O_CREAT | O_TRUNC | O_WRONLY, 0755)`,
   check the return value like every other `open()` call in § 2.
2. Write the buffer you already have in memory, in a loop that keeps going
   until every byte is written:
   ```c
   ssize_t written = 0;
   while (written < total_size)
   {
       ssize_t n = write(fd, buf + written, total_size - written);
       if (n < 0)
       {
           perror("write");
           /* clean up: close both fds; this file may need removing */
           exit(1);
       }
       written += n;
   }
   ```
3. Close both file descriptors. At this stage `woody` should be byte-for-
   byte identical to the input — run `diff original woody` (or `cmp`) to
   confirm, before any later section starts actually changing bytes. This
   identity-copy is the baseline every later checkpoint builds on top of:
   once encryption (§ 6) and entry-point patching (§ 7) exist, you're always
   comparing against "it still runs exactly like this known-good copy did."

## Known traps

- **Forgetting the mode argument, or forgetting it needs the execute bit.**
  `open(path, O_CREAT | O_WRONLY, 0644)` creates a file nobody can execute —
  `./woody` then fails with "Permission denied," which looks like a bug in
  your packing logic but is actually one digit in the mode argument.
- **Treating `write()`'s return value as "all of it or an error."** A
  single `if (write(...) < 0) { error }` with no loop silently drops the
  tail of the file on a short write, producing a `woody` that's truncated —
  and truncated-but-not-crashing is exactly the kind of bug the subject's
  evaluators go looking for.
- **Not truncating an existing `woody` from a previous run.** Without
  `O_TRUNC`, packing a smaller binary after a larger one leaves old bytes
  past the new end of content, corrupting the result in a way that won't
  show up until something tries to run it.

## Checkpoint

Extend your program so that, after the ELF validation from §§ 1–2, it opens
`woody` for writing with the correct flags and mode, writes the entire input
buffer back out in a short-write-safe loop, and closes both descriptors.
Verify with `diff <input> woody` that the output is byte-identical, and
`chmod +x woody && ./woody` confirms it's actually executable and runs like
the original.

## Questions

Q-4.1 (recall) What does `O_TRUNC` do, and what would you observe if you
packed a 10 KB binary, then packed a 2 KB binary to the same output path
without it?

Q-4.2 (application) Write the `open()` call for creating `woody`, with the
correct flags and a mode that makes it executable by its owner only.

Q-4.3 (prediction) Your write loop has `written += n` but you wrote `n =
write(...)` as `int n` instead of `ssize_t n`, on a buffer larger than 2 GB.
What's the realistic failure mode, and why does `ssize_t` exist as a
distinct type from `int` or `size_t`?

Answers: `ANSWERS.md` § 4
