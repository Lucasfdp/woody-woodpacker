---
section: 2
slug: defensive-error-handling
tier: T2
status: not-started
prereqs: [1]
terms: [defensive programming, fail closed, SIGSEGV, errno / perror / strerror, EOF]
---

# Section 2 — Never crash: defensive checks before anything else

**Depth: T2** — this isn't one mechanism to learn once, it's a discipline
that shapes every single checkpoint from here on.
**You'll be able to:** validate input completely, in the right order,
before touching the output file — and explain exactly why the order
matters.

## The idea

The subject's single hardest-sounding rule is actually the simplest to
satisfy once you internalise it: "in no way can your program quit in an
unexpected manner." Not "handle most errors" — *never crash*, on any
input, including hostile or nonsensical input.

The trick isn't writing more error-checking code everywhere. It's
deciding, before you write the happy path, what your program's *default*
is when it doesn't yet know something is safe. If the default is "assume
it's fine unless I specifically catch a problem," you will miss cases you
didn't think of. If the default is "assume it's a problem until I've
specifically confirmed it's fine," you catch cases you didn't think of
too — because the burden of proof is reversed.

## The names for it

**Defensive programming** — writing code that assumes its input might be
wrong, malicious, or malformed, and fails safely instead of trusting it.
Not paranoia for its own sake — it's recognising that `woody_woodpacker`
will be run by an evaluator specifically trying to break it.

**Fail closed** — when something unexpected happens, refuse and exit
cleanly rather than guessing and continuing. The opposite, "fail open,"
would be continuing anyway and hoping — which is how you get a program
that "mostly works" and occasionally corrupts output or crashes on inputs
nobody tested.

**SIGSEGV** — **SIG**nal, **SEG**mentation **V**iolation. The kernel
telling your process it touched memory it isn't allowed to touch. This is
the literal crash the subject forbids, and it's usually the direct result
of the Q-1.4 scenario from § 1 (jumping to, or reading/writing, an address
that was never validated).

**errno / perror / strerror** — `errno` is a number the OS sets after a
*failed* call, saying why it failed — you only check it after a function
has told you (via its return value) that something went wrong. `strerror`
turns that number into a human-readable string. `perror` prints that
string for you directly, prefixed with whatever text you give it — e.g.
`perror("open")` after a failed `open()` prints something like
`open: No such file or directory`.

**EOF** — **E**nd **O**f **F**ile. The signal that there's no more data to
read. On a successful-but-empty read, `read()` returns `0` — this is not
an error (`errno` isn't set), but it's also not "I got the bytes I asked
for," so it needs its own branch, not just an `if (result == -1)` check.

## How it actually works

For `woody_woodpacker`, the validation order that keeps you fail-closed:

1. **Before opening anything for writing:** validate the argument count,
   then open the *input* file read-only and check the return value.
2. **Before trusting any byte of the input as structured data:** read
   just enough to check the magic number (§ 1). If it's wrong, print the
   error and `exit()` — you have created nothing yet, so there's nothing
   to clean up.
3. **Before assuming the file is the architecture you support:** check
   `EI_CLASS` (and later, for the format-abstraction work in § 3, which
   format family this even is). This is where the subject's exact
   message — `File architecture not suported. x86_64 only` — gets
   printed, and only here, before a single byte of `woody` exists.
4. **Only after all of the above have passed** do you open the output
   file for writing. From this point on, if something goes wrong, you
   also need to clean up (close descriptors, and — once you reach later
   sections — `munmap` anything mapped) before exiting, because now
   there *is* a partial file or resource to deal with.

This is the general shape for every later checkpoint too: validate first,
mutate only once validation is complete, clean up on any failure after
that point.

## Known traps

- **Checking `errno` without checking the return value first.** `errno`
  is only meaningful immediately after a call that *told you* (via its
  return value) that it failed. Checking it after a call that succeeded
  can show a stale value from some earlier failed call.
- **Treating `read()` returning `0` as an error.** It isn't — it's EOF,
  a normal and expected condition, especially when you're reading a file
  in chunks and reach the end.
- **Validating in the wrong order** — e.g. opening the output file for
  writing before you've confirmed the input is valid. If validation fails
  afterward, you've already created/truncated a file you now have to
  explicitly delete or leave behind as debris.
- **Assuming a Windows-style mental model** — on Linux, nothing throws an
  exception for you automatically. Every single syscall-backed function
  that can fail will fail *silently* (just a return value) unless you
  check it yourself.

## Checkpoint

Extend the ELF-reading program from § 1 so that it:
1. Prints the subject's exact message and exits cleanly (no crash, no
   partial output) when given a file that isn't a valid ELF file at all.
2. Prints the subject's exact message and exits cleanly when given a
   valid ELF file that isn't `ELFCLASS64`.
3. Handles a missing/unreadable file (bad path, no permissions) the same
   way — check `open()`'s return value, use `perror`, exit cleanly.
4. Does all of this *before* attempting to open or create any output
   file.

Test it against: a text file renamed to look like a binary, a valid
32-bit ELF binary (if you can build one — see § 9), a path that doesn't
exist, and a file you've `chmod 000`'d.

## Questions

Q-2.1 (recall) What does "fail closed" mean, and how is it different from
just wrapping everything in error checks after the fact?

Q-2.2 (application) The subject gives an exact error message for a
non-x86_64 binary. Where in your program's flow does that check have to
happen — before or after you've already started modifying the output
file? Why does the order matter?

Q-2.3 (prediction) If `open()` fails and you don't check its return value
before passing the result to `read()`, what actually happens on Linux
versus what a programmer from an exception-based language might assume
happens?

Q-2.4 (prediction) Your program successfully detects a malformed input but
calls `exit()` without `close()`-ing the file descriptor it opened. Is
this actually a bug, for a program exiting immediately afterward? Why or
why not?

Answers: `ANSWERS.md` § 2
