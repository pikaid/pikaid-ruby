# pikaid-ruby — Official Ruby Implementation

- **Repository:** `pikaid/pikaid-ruby` (`origin https://github.com/pikaid/pikaid-ruby.git`, branch `main`, base commit `bb35b31`)
- **Normative specification:** pikaid specification revision 1.0.4, commit `17014d76f568c3ac9f9ce2927c1a018fdbc36d1d`
- **Interoperability fixtures:** official PHP v1.2.0 vectors/schema, commit `e3f843edeb5157a5d2d25196cac0d69580810a95`
- **Date:** 2026-11-06 22:04 CET
- **Working tree:** changes are intentionally uncommitted; nothing was pushed, tagged, or published.

## Summary

Implemented the official Ruby gem for pikaid from an empty repository state: a
stdlib-only library (`Pikaid` module plus immutable `Pikaid::Id` value object)
that encodes and decodes the 26-character Base36 / 17-byte binary identifier
defined by specification 1.0.4, generates identifiers from
`SecureRandom.random_bytes(12)` and fails closed when secure randomness is
unavailable, and rejects malformed, non-canonical, or overflowing input instead
of coercing it.

The implementation is backed by 10 Minitest suites (81 runs, 12,085 assertions)
covering every official PHP v1.2.0 vector, specification known-answer cases,
malformed/overflow/boundary inputs, randomized round trips against an
independent in-test oracle, generated-identifier round trips, and cryptographic
failure paths. Measured line coverage of `lib/` is 171/171 statements (100.00%)
against a 90% gate. The gem builds and loads in isolation, and a CI workflow is
included but was **not executed** (no push was authorized and no GitHub Actions
runner was available locally).

Local verdict: `PASS`. CI and the non-local platform/Ruby matrix are reported as
`NOT RUN`, not as passing.

## Requirement Coverage

### REQ-1 — Target identity and normative references are correct

- Verified `origin` is `https://github.com/pikaid/pikaid-ruby.git`, branch
  `main`, base commit `bb35b31`.
- Read and pinned the normative spec revision 1.0.4 at commit
  `17014d76f568c3ac9f9ce2927c1a018fdbc36d1d`; no edits were made to the spec or
  to any other repository.
- Vendored the official PHP v1.2.0 fixture and schema at commit
  `e3f843edeb5157a5d2d25196cac0d69580810a95` as test-only fixtures, with their
  SHA-256 values recorded and asserted by a test:
  - `pikaid-v1.json` = `b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500`
  - `pikaid-v1.schema.json` = `4441d4dbaa6c5450ae9cbfb2438c53bc0421bba2b7fcc9ef9b158e5d1de0759e`
- Evidence: `test/vectors_test.rb#test_vendored_fixtures_match_the_recorded_checksums`
  (`PASS`).

### REQ-2 — Wire format conforms to specification 1.0.4

- Text: exactly 26 lowercase ASCII Base36 characters, 7-digit zero-padded
  timestamp followed by 19 digits encoding exactly 96 bits of randomness.
- Binary: exactly 17 bytes — 5-byte unsigned big-endian timestamp + 12 entropy
  bytes.
- Constants pinned: `STRING_LENGTH=26`, `BINARY_LENGTH=17`,
  `TIMESTAMP_LENGTH=7`, `RANDOMNESS_LENGTH=19`, `TIMESTAMP_BYTES=5`,
  `RANDOMNESS_BYTES=12`, `MAX_TIMESTAMP=78_364_164_095`, `MAX_RANDOMNESS=2**96-1`.
- Evidence: `test/api_test.rb#test_constants_describe_the_wire_format`,
  `test/conversion_test.rb#test_binary_layout_is_five_timestamp_bytes_then_twelve_entropy_bytes`,
  `test/vectors_test.rb` (all 14 vectors), `PASS`.

### REQ-3 — Secure generation fails closed

- `Pikaid.generate` / `Pikaid.generate_binary` use
  `SecureRandom.random_bytes(12)`; the timestamp is the current whole second or
  an explicit `timestamp:` keyword.
- Any `StandardError` or `SecurityError` from the cryptographic source is wrapped
  in `Pikaid::RandomnessError`; there is no fallback, retry with weak entropy, or
  silent coercion.
- Evidence: `test/generation_test.rb` (deterministic stubbing of
  `SecureRandom.random_bytes`, plus `RuntimeError` and `SecurityError` failure
  paths), `PASS`.

### REQ-4 — Strict validation; no coercion or normalization

- Text validation rejects wrong length, uppercase, non-Base36 characters,
  non-String input, and randomness values exceeding 96 bits
  (`:randomness_overflow`). `well_formed?` is deliberately weaker (shape only)
  and is documented as such.
- Binary validation rejects wrong byte length (`:invalid_binary_length`) and
  5-byte timestamp values above `MAX_TIMESTAMP` (`:timestamp_overflow`).
- Timestamps must be `Integer` in `0..MAX_TIMESTAMP`; otherwise
  `Pikaid::InvalidTimestampError` (`:not_an_integer`, `:negative`,
  `:timestamp_overflow`).
- All errors inherit from `Pikaid::Error`; `InvalidIdError` exposes `value` and
  `reason`, `InvalidTimestampError` exposes `timestamp` and `reason`.
- Evidence: `test/validation_test.rb`, `test/api_test.rb`,
  `test/generation_test.rb`, `PASS`.

### REQ-5 — Lossless round trips and correct ordering semantics

- Text↔binary conversion is lossless including leading zeroes and both field
  maxima; verified against an independent oracle (`test/support/reference.rb`)
  that does not call library code.
- Ordering: canonical bytewise/ASCII order is chronological only across
  different seconds; within one second it follows the random suffix and is not
  monotonic. This limitation is stated in the README and asserted by tests.
- No authentication, secrecy, or uniqueness guarantee is claimed anywhere.
- Evidence: `test/conversion_test.rb`, `test/round_trip_test.rb`,
  `test/ordering_test.rb`, `PASS`.

### REQ-6 — Idiomatic, minimal-dependency Ruby gem

- `pikaid.gemspec` + `Gemfile` + `Rakefile` (`syntax`, `test`, `coverage`,
  default `syntax,test`); `required_ruby_version >= 2.6.0`; MIT license;
  `rubygems_mfa_required` metadata; no runtime dependencies beyond stdlib
  (`securerandom`).
- `lib/` split into `pikaid.rb`, `version.rb`, `constants.rb`, `errors.rb`,
  `codec.rb`, `validation.rb`, `id.rb`.
- README preserves the pikaid logo/branding and documents the
  source-only pre-release status (`0.1.0`, unpublished).
- Evidence: `gem build pikaid.gemspec` (`PASS`), isolated unpack + `require`
  (`PASS`), `test/readme_examples_test.rb` (`PASS`).

### REQ-7 — Comprehensive tests and ≥90% coverage

- 10 suites, 81 runs, 12,085 assertions, 0 failures, 0 errors, 0 skips.
- Every official vector is executed (4 valid, 6 invalid strings, 4 invalid
  binaries), plus independent known-answer, malformed, overflow, boundary,
  zero-padding, randomized-property, generated-ID, and error-path tests.
- Line coverage: 171/171 (100.00%) across all 7 `lib/` files, gated at 90% by
  `test/coverage_runner.rb`; the runner also fails if any `lib/` file is left
  uninstrumented.
- Evidence: `bundle exec rake test`, `bundle exec rake coverage` (`PASS`).

### REQ-8 — CI covers build/test/static checks with a justified matrix

- `.github/workflows/ci.yml`: Ubuntu × Ruby 2.7–3.5, Ruby 2.6 pinned to
  `ubuntu-22.04` (Ruby 2.6 predates OpenSSL 3), macOS and Windows for Ruby 3.5,
  plus a Ruby 3.4 coverage job. Each job runs `rake syntax`, a `ruby -w` load
  check, `rake test`, and `gem build`.
- Workflow YAML parses locally, but the workflow has **never executed**
  (no push authorized) → `NOT RUN`. No `PASS` is claimed for CI.

### REQ-9 — No publication or destructive repository actions; report delivered

- No commit, push, tag, release, gem publication, force-push, or change to
  unrelated files, the specification, or other repositories occurred. All work
  is uncommitted by design.
- This report is written to `.ai/reports/` and mirrored byte-for-byte to Tohru
  Drive; delivery is verified by SHA-256 comparison and reported separately from
  the task result.
- Evidence: `git status`, `git diff --check`, checksum comparison (`PASS`).

## Root Cause or Technical Approach

There was no existing Ruby implementation to repair, so the work was
greenfield construction against a fixed wire format. The approach was to treat
the specification as the only source of truth and to keep the family of
representations (text, binary, value object) provably equivalent.

1. **Single decode/encode path.** `Pikaid::Codec` owns Base36 encode/decode and
   unsigned big-endian integer conversion. All public entry points funnel
   through it, so padding, byte order, and overflow behaviour exist in one
   place.
2. **Validation separate from construction.** `Pikaid::Validation` performs the
   strict timestamp/randomness checks and raises typed errors with machine-usable
   `reason` symbols. `Id.new` re-checks invariants, so a value object cannot be
   constructed in an invalid state even by bypassing the parsers.
3. **Immutability.** `Pikaid::Id` freezes itself, its string form, its binary
   form, and its randomness bytes; equality/hash are value-based so identifiers
   work as hash keys, and `Comparable` is mixed in.
4. **Fail-closed randomness.** Generation has a single entropy call wrapped so
   that any crypto failure becomes `Pikaid::RandomnessError`, preserving the
   "never silently degrade" requirement.
5. **Independent oracle testing.** `test/support/reference.rb` re-implements
   encoding/decoding with a different algorithm shape (`String#to_i(36)`,
   `pack("N")`, manual hex) so a shared bug in library and test helper is
   unlikely. Randomized tests are seeded for reproducibility.
6. **Coverage integrity.** `test/coverage_runner.rb` starts stdlib `Coverage`
   before the library loads, re-instruments files preloaded by the gemspec under
   `bundle exec` (the gemspec reads `Pikaid::VERSION`, so `version.rb` was
   otherwise loaded before instrumentation), and fails the run if any `lib/` file
   remains unmeasured — preventing a silently incomplete coverage number.

## Files Changed

Modified:

- `README.md` — rewritten as the official gem README: branding, specification
  and vector provenance, source-only install, verified usage, format table,
  ordering/security caveats, Ruby support, and development commands. All
  published examples are executable and covered by `test/readme_examples_test.rb`.

Added (library):

- `lib/pikaid.rb` — public module API: `generate`, `generate_binary`, `parse`,
  `from_binary`, `valid?`, `valid_binary?`, `well_formed?`, `timestamp`,
  `randomness`/`entropy`, `decode`, `to_binary`, `compare`.
- `lib/pikaid/version.rb` — `Pikaid::VERSION = "0.1.0"`.
- `lib/pikaid/constants.rb` — frozen format constants and alphabet.
- `lib/pikaid/errors.rb` — `Error`, `InvalidIdError`, `InvalidTimestampError`,
  `RandomnessError`.
- `lib/pikaid/codec.rb` — Base36 and big-endian byte helpers.
- `lib/pikaid/validation.rb` — strict timestamp/randomness validation.
- `lib/pikaid/id.rb` — immutable `Pikaid::Id` value object.

Added (build/packaging):

- `pikaid.gemspec` — metadata, `required_ruby_version >= 2.6.0`, MIT license,
  bounded development dependencies, shipped file list.
- `Gemfile` — `gemspec` + rubygems source.
- `Rakefile` — `syntax`, `test` (warnings on), `coverage`, default task.
- `LICENSE` — MIT.
- `.gitignore` — Bundler, packaging, coverage, and local `.ai/` artifacts.
- `.github/workflows/ci.yml` — CI matrix and checks (not executed).

Added (tests and fixtures):

- `test/test_helper.rb` — fixture loading, `SecureRandom` stubbing helper.
- `test/support/reference.rb` — independent encode/decode oracle.
- `test/coverage_runner.rb` — stdlib line-coverage runner with 90% gate and
  instrumentation-integrity check.
- `test/vectors/pikaid-v1.json`, `test/vectors/pikaid-v1.schema.json`,
  `test/vectors/README.md` — vendored official PHP v1.2.0 fixtures with
  provenance and checksums (not shipped in the gem).
- `test/vectors_test.rb`, `test/spec_examples_test.rb`,
  `test/validation_test.rb`, `test/generation_test.rb`,
  `test/conversion_test.rb`, `test/ordering_test.rb`,
  `test/round_trip_test.rb`, `test/api_test.rb`, `test/codec_test.rb`,
  `test/readme_examples_test.rb`.

## Validation

Environment: `ruby 2.6.10p210 (2022-04-12 revision 67958) [universal.arm64e-darwin26]`,
Bundler 1.17.2, Rake 12.3.3, Minitest 5.11.3, macOS (darwin26, Apple silicon).

| # | Command | Result | Details |
| --- | --- | --- | --- |
| 1 | `bundle install --local` | `PASS` | Resolved rake 12.3.3, bundler 1.17.2, minitest 5.11.3, pikaid 0.1.0 (path). |
| 2 | `bundle exec rake syntax` | `PASS` | `ruby -c` over 7 `lib/` files, 13 `test/` files, `Rakefile`, `pikaid.gemspec`; all `Syntax OK`; exit 0. |
| 3 | `bundle exec rake test` | `PASS` | 81 runs, 12,085 assertions, 0 failures, 0 errors, 0 skips (warnings enabled by the rake task). |
| 4 | `bundle exec rake coverage` | `PASS` | 100.00% line coverage, 171/171 statements across all 7 `lib/` files; threshold 90%; all files individually 100%. |
| 5 | `ruby -Ilib -Itest test/coverage_runner.rb` | `PASS` | Independent of Bundler: same 171/171 (100.00%). |
| 6 | `ruby -w -Ilib -e 'require "pikaid"; Pikaid.generate'` | `PASS` | Exit 0, no warnings on stderr. |
| 7 | `gem build pikaid.gemspec` | `PASS` | Built `pikaid-0.1.0.gem`; no gem-build warnings. |
| 8 | `gem unpack` + `ruby -Ilib -e 'require "pikaid"; ...'` in an isolated directory | `PASS` | Package contains exactly 9 files (`LICENSE`, `README.md`, `lib/pikaid.rb`, `lib/pikaid/{codec,constants,errors,id,validation,version}.rb`); generates `0s44we81boktm8vdi0amrlnvaz`, parses timestamp `1700000000`, `VERSION == "0.1.0"`. |
| 9 | `gem specification pikaid-0.1.0.gem --yaml` | `PASS` | `name=pikaid`, `version=0.1.0`, `required_ruby_version=>= 2.6.0`, `license=MIT`, `files=9`. |
| 10 | Vector checksum assertions in `test/vectors_test.rb` | `PASS` | SHA-256 of both vendored fixtures matches the recorded upstream digests. |
| 11 | `git diff --check` and trailing-whitespace scan over tracked file types | `PASS` | No whitespace errors; `git status` shows only the intended `README.md` modification and the new gem files. |
| 12 | YAML parse of `.github/workflows/ci.yml` | `PASS` | Workflow YAML parses. |
| 13 | GitHub Actions workflow execution | `NOT RUN` | No push authorized; no CI run exists. **Not** claimed as passing. |
| 14 | Ruby 2.7, 3.0, 3.1, 3.2, 3.3, 3.4, 3.5 test runs | `NOT RUN` | Only Ruby 2.6.10 is installed locally. |
| 15 | macOS Ruby 3.5 and Windows Ruby 3.5 runs | `NOT RUN` | Not available in this environment. |
| 16 | Branch coverage / mutation testing | `NOT RUN` | Only line coverage via stdlib `Coverage` is measured. |

## Deviations and Unresolved Issues

- **CI has never run.** The workflow is committed only in the working tree and
  parses locally, but there is no runner evidence. Every CI cell (Ruby versions,
  macOS/Windows) is `NOT RUN`, including the Ruby 2.6 → `ubuntu-22.04` pin,
  which is an untested assumption about `ruby/setup-ruby` availability.
- **Local validation is single-platform.** Ruby 2.6.10 on macOS is the only
  environment exercised; the `>= 2.6.0` claim for newer Rubies rests on CI
  configuration, not on execution.
- **Coverage is line coverage only**, measured with stdlib `Coverage`; there is
  no branch or mutation coverage. A `lib/` file silently escaping instrumentation
  is now a hard failure, but statement coverage can still mask untested branches
  on covered lines.
- **Coverage normalization.** Under `bundle exec`, the gemspec loads
  `lib/pikaid/version.rb` before `Coverage.start`; the runner re-loads such
  preloaded files so both invocation paths measure 171/171. This is a
  measurement normalization, not a change to library behaviour.
- **Source-only, unpublished.** Gem version `0.1.0` is a pre-release and was not
  published to RubyGems; the README states this explicitly. No tag or release was
  created.
- **Uncommitted work.** Nothing was committed or pushed; the repository has one
  tracked modification (`README.md`) and the new files listed above.
- **`Pikaid::Id#<=>` returns `nil`** for non-`Id` values (standard `Comparable`
  behaviour); comparisons against raw strings are not defined on the value object
  — use `Pikaid.compare` for mixed inputs.
- **No email in gem metadata.** `spec.email` is intentionally omitted rather than
  inventing an unverified address; `authors` is set.
- **Ordering caveat is inherent to the format**, not a defect: identifiers from
  the same second are ordered by randomness, so generation order is not
  recoverable within a second.

## Final Status

The official Ruby implementation is complete locally and passes every check that
could be executed in this environment: syntax, 81 tests / 12,085 assertions,
100.00% (171/171) line coverage, warning-free load, gem build, isolated gem load,
and vector checksum verification. CI and the non-local Ruby/platform matrix were
not executed and are recorded as `NOT RUN`. Work is uncommitted and unpublished by
design. Delivery: an identical copy was written to
`$TOHRU_DRIVE_ROOT/pikaid-ruby/reports/` with the same filename; the two files
were verified byte-identical with `diff -q` and matching SHA-256 digests. This
report is the authoritative copy.

```text
task_result: PASS
```
