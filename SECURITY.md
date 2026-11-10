# Security review packet — CSPRNG source and fail-closed behavior

**Status: `MANUAL_EVIDENCE_REQUIRED`.**

This file is a **reviewer packet**, not a security review record. It contains no
reviewer identity, signature, approval, or evidence JSON. Automated tests
cannot satisfy the two mandatory manual audits, and this repository does not
pretend that they do.

The official suite requires two independent human checks against the exact
production commit:

| Audit | Obligation |
| --- | --- |
| `P-GENERATE-RNG-SOURCE` | Every production generation path obtains 12 fresh bytes from a cryptographically secure source. |
| `P-GENERATE-RNG-FAILURE` | Entropy-source failure aborts generation; there is no predictable fallback, truncation, retry loop, or partial output. |

Until a genuine independent reviewer records and approves both checks for the
release commit, a default suite run exits `3` and the release remains
**NO-GO for the security gate**.

## Implementation identity

- Repository: `pikaid/pikaid-ruby`
- Implementation id: `pikaid/pikaid-ruby`
- Gem version: `1.0.0`
- Specification revision: `1.0.4`
- Official suite revision: `1.0.0`
- Official suite commit: `059780cc0e5b113443812720d95c630649bf3aa3`
- Review commit: **the full 40-character `git rev-parse HEAD` of the release
  candidate that contains this file.** Reviewers must record that exact SHA in
  the evidence record; the suite rejects a commit mismatch.

## Generation path map

There is one production entropy path. Both public generation entry points
converge on it.

| Step | Location | Behavior |
| --- | --- | --- |
| `Pikaid.generate(timestamp:)` | `lib/pikaid.rb` 32–33 | `build_id(timestamp).to_s` |
| `Pikaid.generate_binary(timestamp:)` | `lib/pikaid.rb` 42–43 | `build_id(timestamp).to_binary` |
| Timestamp selection and bounds | `lib/pikaid.rb` 224–226 | `Time.now.to_i` when `nil`; `Validation.timestamp!` rejects non-Integer, negative, and overflow values **before** entropy is requested |
| Entropy request | `lib/pikaid.rb` 227, 230–231 | `secure_random_bytes(RANDOMNESS_BYTES)` → `SecureRandom.random_bytes(12)` |
| Entropy size constant | `lib/pikaid/constants.rb` 20 | `RANDOMNESS_BYTES = 12` |
| Shape check | `lib/pikaid.rb` 232–235 | The value must be a `String` of exactly 12 bytes; otherwise `RandomnessError` |
| Encoding normalization | `lib/pikaid.rb` 237 | `bytes.b` (binary encoding; no truncation or numeric coercion) |
| Error mapping | `lib/pikaid.rb` 238–242 | `RandomnessError` re-raised unchanged; `StandardError` and `SecurityError` wrapped as `RandomnessError` |
| Error contract | `lib/pikaid/errors.rb` 32–36 | `Pikaid::RandomnessError < Pikaid::Error`; documented as fail-closed |
| Value construction | `lib/pikaid.rb` 227; `lib/pikaid/id.rb` 36–50 | `Id.new` validates components, freezes the 12 bytes, and computes both canonical forms |

`Pikaid::Id.new` is a public decoding/validation constructor. It does not call
`SecureRandom` and therefore is not an additional entropy path. `parse`,
`from_binary`, `valid?`, `well_formed?`, `compare`, and the accessors are pure
decoding/validation and never request randomness.

## Audit 1 — `P-GENERATE-RNG-SOURCE`

Review these facts at the pinned commit:

1. Both `generate` and `generate_binary` call `build_id`; no other production
   generation path exists (`lib/pikaid.rb` 32–33, 42–43, 224–228).
2. `build_id` requests exactly `RANDOMNESS_BYTES`, defined as 12, through
   `SecureRandom.random_bytes` (`lib/pikaid.rb` 227, 230–231;
   `lib/pikaid/constants.rb` 20).
3. `SecureRandom` is Ruby's standard-library cryptographic source. It delegates
   to the platform CSPRNG (OpenSSL's `RAND_bytes` when the openssl extension is
   available, otherwise Ruby's OS entropy implementation). No seed, counter,
   `Random`, `rand`, `srand`, UUID, PID, clock, or user-supplied value is used
   as entropy.
4. The returned value is checked for exact size and type before use
   (`lib/pikaid.rb` 232–237). There is no truncation, padding, hashing of a
   short value, or widening of a long value.
5. Explicit timestamps change only the five-byte timestamp; the 12-byte
   randomness request is unchanged (`lib/pikaid.rb` 224–227).
6. A leading-zero randomness value is preserved rather than stripped;
   `test/generation_test.rb` 90–98 proves the 12 bytes survive encoding.
7. `test/generation_test.rb` 78–88 proves repeated generation within one second
   yields distinct, valid identifiers (freshness sanity, not proof of CSPRNG
   quality).

## Audit 2 — `P-GENERATE-RNG-FAILURE`

Review these facts at the pinned commit:

1. `SecureRandom.random_bytes` is called exactly once per generation; there is
   no retry loop (`lib/pikaid.rb` 227, 230–231).
2. Any exception from the source is converted to `Pikaid::RandomnessError`
   (`lib/pikaid.rb` 240–242). `SecurityError` is explicit because it is not a
   `StandardError`.
3. A non-String or wrong-length result raises `RandomnessError` instead of
   being used (`lib/pikaid.rb` 232–235).
4. `RandomnessError` is re-raised without double wrapping, so callers see the
   stable library error (`lib/pikaid.rb` 238–239; `lib/pikaid/errors.rb` 32–36).
5. Failure propagates to both public generation entry points because both call
   `build_id` (`lib/pikaid.rb` 32–33, 42–43).
6. Invalid timestamps raise `InvalidTimestampError` before the source is
   called, so a bad timestamp cannot consume or mask a CSPRNG failure
   (`lib/pikaid.rb` 225–226; `test/generation_test.rb` 100–113).
7. `test/generation_test.rb` 134–148 asserts one source call, a
   `RandomnessError`, and the original exception as `cause`.
8. `test/generation_test.rb` 150–154 covers the binary entry point;
   156–161 covers `SecurityError`; 163–170 covers wrong size and wrong type.

## Reviewer commands

Run at the exact commit under review on a supported Ruby line:

```sh
git rev-parse HEAD

# Focused failure-path and freshness tests.
bundle exec ruby -Ilib -Itest test/generation_test.rb

# Direct fail-closed demonstration (fresh process, test-only stub).
ruby -Ilib -e '
  require "pikaid"
  require "securerandom"
  SecureRandom.singleton_class.prepend(Module.new do
    def random_bytes(_count); raise "CSPRNG offline"; end
  end)
  begin
    Pikaid.generate
    abort "generation unexpectedly succeeded"
  rescue Pikaid::RandomnessError => error
    puts "fail-closed: #{error.message}"
  end
'
```

Official suite, from the pinned `conformance/` directory:

```sh
# Automated layer only: exit 0, explicitly non-certifying.
python tools/run_adapter.py --automated-only -- \
  ruby -I/path/to/pikaid-ruby/lib /path/to/pikaid-ruby/test/support/official_adapter.rb

# Default run without a security evidence record: exit 3.
python tools/run_adapter.py -- \
  ruby -I/path/to/pikaid-ruby/lib /path/to/pikaid-ruby/test/support/official_adapter.rb
echo $?   # 3 while both manual audits are outstanding
```

The adapter's `csprng_failure_injection` capability is test-only. It prepends a
module to `SecureRandom` **inside the adapter process** to raise while the suite
activates the fault; production files are not modified. It proves the library's
own error mapping, not CSPRNG quality (`test/support/official_adapter.rb`
52–73, 117–135).

## Recording genuine evidence

A genuine reviewer must create a JSON document conforming to the suite's
`schemas/security-evidence.schema.json` with:

- `format`: `pikaid-csprng-review-v1`
- `implementation_id`: `pikaid/pikaid-ruby`
- `implementation_commit`: the full 40-character release SHA
- `spec_revision`: `1.0.4`
- `suite_revision`: `1.0.0`
- `reviewed_at_utc`: the reviewer's UTC timestamp
- `reviewer`: the reviewer's real identity
- `checks`: exactly `P-GENERATE-RNG-SOURCE` and `P-GENERATE-RNG-FAILURE`, both
  `PASS`, each with repository-relative paths and line ranges

Then, from the pinned `conformance/` directory:

```sh
python tools/run_adapter.py \
  --security-evidence /path/to/genuine-review.json \
  --implementation-commit <full-40-character-sha> \
  -- ruby -I/path/to/pikaid-ruby/lib /path/to/pikaid-ruby/test/support/official_adapter.rb
```

The runner validates the **record**, not the reviewer's identity or the truth
of the assertions. Approval must happen through the consuming release process.
Do not commit a review record, add a reviewer signature, or inject one into CI
unless a real independent reviewer produced and approved it.

## Current evidence status

- Automated official checks: **PASS** on Ruby 2.6–4.0 (see the release report).
- `P-GENERATE-RNG-SOURCE`: **OUTSTANDING — manual evidence not recorded.**
- `P-GENERATE-RNG-FAILURE`: **OUTSTANDING — manual evidence not recorded.**
- Matching verified security evidence record: **none in this repository.**
- Release security gate: **NO-GO / `MANUAL_EVIDENCE_REQUIRED`.**
