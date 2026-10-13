---
section: 6
slug: encryption-design
tier: T2
status: not-started
prereqs: [2]
terms: [symmetric encryption, XOR cipher, stream cipher, keystream, PRNG, seed, getrandom, roundtrip, parameterised key]
---

# Section 6 — Stream cipher design, randomness, parameterised key

**Depth: T2** — the mechanism is simple; the discipline around key
handling is where projects at this level actually lose points.
**You'll be able to:** design and implement an encrypt/decrypt pair that
is provably reversible, generate a secure-enough random key when none is
given, and accept a key supplied on the command line instead — producing
exactly the bytes `woody_woodpacker` scrambles at pack time and the stub
unscrambles at run time.

## The idea

Encryption here doesn't need to be unbreakable — the subject explicitly
rules out a trivial cipher (a plain ROT/Caesar shift) but does not ask for
research-grade cryptography. What it actually needs is a scheme with one
property, and one property only, that matters absolutely: applying the
*same operation* to the *same data* with the *same key*, twice, must
return the original bytes exactly. Everything else — how "random-looking"
the result is, how resistant it is to analysis — is a nice-to-have you can
spend more or less effort on, but reversibility is non-negotiable, because
a decrypt that doesn't reproduce the original binary byte-for-byte is a
packed program that corrupts itself before it even runs.

The simplest operation with that property is XOR. If you XOR a byte with
some value once, then XOR the *result* with that same value again, you get
the original byte back — always, for any value. That single fact is the
entire mechanism: generate a stream of bytes the same length as the data
(a **keystream**), XOR the plaintext against it once to encrypt, and XOR
the ciphertext against the *same* keystream again, later, to decrypt.
Nothing about the plaintext itself needs to be understood or parsed for
this to work — which is exactly why it applies uniformly to an entire
binary file, headers and all.

## The names for it

**Symmetric encryption** — a scheme where the same key is used to both
encrypt and decrypt, as opposed to *asymmetric* schemes (public/private
key pairs) that use a different key for each direction. This project is
symmetric: whatever key packs the binary is the exact key the embedded
stub must use to unpack it.

**XOR cipher** — encryption built on the bitwise XOR operation
(`ciphertext = plaintext ^ keystream_byte`), relying on the fact that
`(x ^ k) ^ k == x` for any `x` and `k`. The entire reversibility of this
project's encryption rests on this one bit-level identity.

**Stream cipher** — a cipher that encrypts data one unit (here, one byte)
at a time against a continuously-produced stream of pseudorandom bytes,
rather than encrypting fixed-size blocks all at once (a *block cipher*,
the other major family — not what you're building). The **keystream** is
that produced stream; it needs to be at least as long as the data you're
encrypting.

**PRNG** — **P**seudo-**R**andom **N**umber **G**enerator. An algorithm
that produces a sequence of numbers that *looks* statistically random but
is entirely determined by its starting state — the **seed**. The same
seed, run through the same PRNG, always produces the exact same sequence.
This determinism is not a flaw here, it's the whole point: it's what lets
the stub regenerate the identical keystream at runtime from just the key,
without the keystream itself ever being stored anywhere.

**`getrandom`** — a Linux syscall that fills a buffer with bytes from the
kernel's own randomness source — genuinely unpredictable, unlike a PRNG
seeded from something guessable (the current time, say). The subject's
allowed-function list includes `syscall` directly, so this is reached as
`syscall(SYS_getrandom, buf, len, 0)` rather than calling a wrapper
function the subject didn't explicitly allow. This is what generates the
*key* itself (a short, genuinely random seed) — the much longer keystream
derived *from* that key can then come from an ordinary deterministic PRNG,
because determinism there is required, not a weakness.

**Roundtrip** (test) — encrypting data and then immediately decrypting the
result, and asserting the output is byte-identical to the original input.
This is the correctness test for any reversible transform, and the
checkpoint for this section specifically.

**Parameterised key** — the bonus requirement that the key isn't always
randomly generated; the user can instead supply their own key as a
command-line argument, and the program must use *that* key for both
generation and (implicitly, via the embedded stub) decryption, instead of
calling `getrandom` at all.

## How it actually works

1. **Generate or accept the key.** If no key argument was given, call
   `getrandom`-via-`syscall` for N bytes (pick a fixed length, e.g. 16) and
   print it to stdout exactly as the subject requires. If a key argument
   *was* given, use those bytes directly — validate its length/format
   defensively (§ 2's discipline applies here too: a malformed key argument
   is still an input that must not crash the program).

2. **Derive a keystream from the key, not the key itself as the
   keystream.** The key is short (16 bytes); the data being encrypted is
   the entire input binary, almost certainly much longer. Seed a small,
   deterministic PRNG with the key's bytes (e.g. combine them into an
   integer seed, or use the key bytes to initialize a simple generator
   like an LCG or a key-mixing xorshift), then pull as many keystream
   bytes from it as the data is long. This is what keeps the output from
   having the key's own length as a visible, repeating period (see Known
   traps).

3. **XOR.** `for i in 0..len: ciphertext[i] = plaintext[i] ^ keystream[i]`.
   That's the entire transform, in both directions — encryption and
   decryption are *literally the same function call*, which is one of the
   reasons XOR-based stream ciphers are so common for exactly this kind of
   embedded, must-be-simple-to-implement-twice use case.

4. **The decrypt stub (§§ 7–8) must regenerate the identical keystream at
   runtime.** That means the *key itself* — not the keystream, the key —
   has to travel with the packed binary somehow (embedded as data the stub
   reads, or passed in some other mechanism you design), and the stub runs
   the exact same PRNG-seeding logic you used at pack time. If pack time
   and the stub ever disagree about how the keystream is derived from the
   key, decryption silently produces garbage instead of the original
   bytes — no error, just a `woody` that crashes the moment it tries to
   run its own "decrypted" code.

## Known traps

- **Using the key bytes directly as the keystream, repeated to fill the
  data's length.** This technically satisfies "reversible" — XOR-ing with
  a repeating 16-byte pattern is still undone by XOR-ing with the same
  pattern again — but it produces a visible period: open the output in a
  hex editor and any repeated structure in the original binary (long runs
  of zero bytes are common in ELF files) shows up as the *key itself*,
  repeating, in plain sight. A derived keystream (step 2 above) avoids
  this by not repeating on any fixed period tied to the key's length.
- **Regenerating a "random" key inside the decrypt stub instead of reusing
  the one from pack time.** The stub cannot call `getrandom` and expect to
  get the *same* bytes back — randomness is, by definition, not
  reproducible. The key has to be carried forward from pack time
  explicitly, never re-derived.
- **Forgetting the key must be printed to stdout exactly once, at pack
  time, even in the parameterised-key bonus case.** The subject's
  requirement to print the key doesn't go away just because the user
  supplied it themselves.
- **Treating "non-trivial" as "needs to be cryptographically secure."**
  Spending effort hardening this cipher against real cryptanalysis is
  effort spent in the wrong place for this project — the subject's bar is
  "not a trivial Caesar shift," not "survives a security audit." The
  format-abstraction work (§ 3) and entry-point injection (§ 7) are where
  this project's real difficulty lives.

## Checkpoint

Write a standalone encrypt/decrypt roundtrip test (this can become real
project code, not a throwaway): given a key (random via `getrandom`-
`syscall`, or supplied), derive a keystream, XOR a test buffer (a few
hundred bytes, ideally including some long runs of repeated bytes to
stress-test the "visible period" trap) to produce ciphertext, confirm the
ciphertext differs from the plaintext, then XOR the ciphertext with a
keystream re-derived from the same key and confirm the result is
byte-identical to the original plaintext. Run it with both a freshly
generated key and a hand-supplied one.

## Questions

Q-6.1 (recall) Why does XOR-ing the same data with the same keystream
twice return the original data? What property of the XOR operation makes
this true for *any* keystream value, not just special ones?

Q-6.2 (application) The subject requires the key to be printed to stdout
at pack time. Separately, the decrypt stub needs that same key at runtime
to regenerate the keystream. Name the one thing that must travel from pack
time into the packed binary for this to work, and explain why printing the
key to stdout does *not* satisfy that requirement by itself.

Q-6.3 (prediction) Your keystream is just the 4-byte key repeated to match
a 400-byte plaintext. The plaintext has a 64-byte run of zero bytes in the
middle (common in real ELF files — padding). What does that run look like
in the ciphertext, and why does that happen specifically because the
keystream repeats on a fixed, short period?

Q-6.4 (prediction) Your decrypt stub calls `getrandom` itself at runtime,
reasoning "I'll just generate a fresh key the same way pack time did."
What's the actual result when it tries to decrypt the binary, and why does
"the same way" not mean "the same bytes"?

Answers: `ANSWERS.md` § 6
