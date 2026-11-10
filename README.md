<p align="center">
  <img src="https://raw.githubusercontent.com/pikaid/pikaid-specs/v1.0.4/logo.png" alt="pikaid" width="300" />
</p>

<p align="center">
  <strong>Small · Sortable · Secure ID generator</strong>
</p>

# pikaid — Official Ruby Implementation

**Status: stable `1.0.0` — release prepared. Not yet published to RubyGems.**

This is the official Ruby implementation of [pikaid](https://github.com/pikaid): a
compact, chronologically sortable identifier for databases, APIs, and distributed
systems. The pikaid identifier format is immutable and unversioned:
**26 lowercase Base36 characters** with a **17-byte binary representation**.

The normative definition is
[pikaid specification revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4).
Official PHP v1.2.0 vectors are used as independent interoperability fixtures.

## Requirements

- Ruby **2.6 or newer** (`required_ruby_version >= 2.6.0`).
- No runtime dependencies beyond the Ruby standard library
  (`securerandom` is the only cryptographic dependency).

### Support policy

Version `1.0.0` declares MRI/YARV **2.6 through 4.0** and is verified on every
minor line from 2.6 to 4.0. Ruby 2.6 and 2.7 are end-of-life upstream: they
remain in the declared range, in CI, and in the verification matrix because the
gemspec still accepts them, but they are **compatibility-only** and no newer
language features are used. Ruby 4.0 is the newest stable line; preview and RC
releases are not supported.

The full native suite and the pinned official adapter were executed on Linux
containers for Ruby 2.6.10, 2.7.8, 3.0.7, 3.1.7, 3.2.11, 3.3.13, 3.4.12, and
4.0.9; the host macOS run used Ruby 2.6.10. The push-triggered GitHub Actions
workflow is configured to test Ruby 2.6 on `ubuntu-22.04`, Ruby 2.7 through 4.0
on `ubuntu-latest`, and Ruby 4.0 on `macos-latest` and `windows-latest`. A
separate job installs the built gem into an isolated `GEM_HOME` and exercises
it from a consumer script, and verifies the packaged file inventory, so
packaging regressions are caught outside the checkout.

## Installation

Version `1.0.0` is prepared but the gem is **not published** to RubyGems yet, so
`gem install pikaid` does not apply. Install it from source:

```sh
git clone https://github.com/pikaid/pikaid-ruby.git
cd pikaid-ruby
bundle install
bundle exec rake test
```

To build and install a local gem:

```sh
gem build pikaid.gemspec
gem install ./pikaid-1.0.0.gem
```

The built package contains only `lib/**/*.rb`, `README.md`, `LICENSE`, and
`CHANGELOG.md`. Local `.ai/` workspace artifacts, tests, CI configuration, and
build leftovers are never packaged.

## Usage

```ruby
require "pikaid"

# Generate using the current whole second.
id = Pikaid.generate            #=> "0s44we8..." (26 characters)
id.class                        #=> String
id.bytesize                     #=> 26

# Generate with an explicit Unix timestamp (whole seconds).
Pikaid.generate(timestamp: 1_700_000_000)   #=> 26-character String

# Generate the 17-byte binary form directly.
Pikaid.generate_binary(timestamp: 1_700_000_000).bytesize  #=> 17

# Parse and decode.
parsed = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")
parsed.timestamp        #=> 1700000000
parsed.randomness       #=> "\x00\x11\"3DUfw\x88\x99\xAA\xBB"
parsed.randomness_hex   #=> "00112233445566778899aabb"
parsed.entropy          #=> same bytes as #randomness
parsed.to_s             #=> "0s44we8002loz3po6mcf6vsn23"
parsed.to_binary.bytesize  #=> 17
parsed.to_binary.unpack("H*")[0]
#=> "006553f10000112233445566778899aabb"

# Pikaid stores whole Unix seconds, not a timezone. Time.at(...).utc is the
# explicit UTC conversion; no timezone is implied by the identifier itself.
Time.at(parsed.timestamp).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
#=> "2023-11-14T22:13:20Z"

# Binary round trip.
Pikaid.from_binary(parsed.to_binary) == parsed   #=> true

# Strict validation.
Pikaid.valid?("0s44we8002loz3po6mcf6vsn23")      #=> true
Pikaid.valid_binary?(parsed.to_binary)           #=> true
Pikaid.well_formed?("0000000zzzzzzzzzzzzzzzzzzz") #=> true (shape only)
Pikaid.valid?("0000000zzzzzzzzzzzzzzzzzzz")       #=> false (96-bit overflow)

# Helper functions accept either a String or a Pikaid::Id.
Pikaid.timestamp(parsed)                 #=> 1700000000
Pikaid.randomness("0s44we8...")          #=> 12-byte String
Pikaid.decode(parsed)                    #=> [1700000000, "..."]
Pikaid.to_binary(parsed)                 #=> 17-byte String
Pikaid.compare(parsed, another_id)       #=> -1, 0, or 1
```

### Errors

All errors inherit from `Pikaid::Error`:

```ruby
begin
  Pikaid.parse("not-a-pikaid")
rescue Pikaid::InvalidIdError => error
  error.reason  #=> :invalid_string_length or :invalid_character, ...
  error.value   #=> the rejected input
end
```

- `Pikaid::InvalidIdError` — text or binary input is not a valid pikaid.
- `Pikaid::InvalidTimestampError` — a supplied timestamp is negative, out of
  range, or not an Integer.
- `Pikaid::RandomnessError` — the cryptographic source failed or returned the
  wrong number of bytes. Generation fails closed; there is no fallback.

## Format

| Property | Value |
| --- | --- |
| Text length | 26 lowercase ASCII Base36 characters (`0-9a-z`) |
| Timestamp | 7 fixed-width Base36 digits, unsigned Unix seconds |
| Timestamp range | `0..78_364_164_095` (`36^7 - 1`) |
| Randomness | 19 fixed-width Base36 digits encoding exactly 96 bits |
| Binary length | 17 bytes |
| Binary layout | 5-byte unsigned big-endian timestamp + 12 entropy bytes |

Text and binary forms are lossless round trips. Timestamp and randomness are
extracted without coercion, and leading zeroes are preserved.

## Ordering and security

- Canonical bytewise/ASCII lexicographic order is chronological **across
  different seconds**.
- Identifiers generated within the **same second are not monotonic**. Their
  order is determined by their random suffix, not by generation time.
- The timestamp has **whole-second precision only**; there is no sub-second
  ordering guarantee.
- Randomness comes from `SecureRandom.random_bytes(12)`. pikaid is **not** an
  authentication token, does not provide secrecy, and does not guarantee
  uniqueness. Treat it as a compact, sortable identifier, not as a capability
  or a security credential.

## Development

```sh
bundle exec rake syntax    # ruby -c over lib, test, Rakefile, gemspec
bundle exec rake test      # Minitest suite
bundle exec rake coverage  # stdlib line coverage; fails below 90%
gem build pikaid.gemspec   # build the gem
```

The test suite covers every official PHP v1.2.0 vector, specification
known-answer cases, malformed and overflow inputs, boundary values, randomized
round trips against an independent oracle, generated-ID sanity checks, and
cryptographic failure paths.

## Conformance

The official cross-language suite is
[pikaid-specs `1.0.0`](https://github.com/pikaid/pikaid-specs/tree/059780cc0e5b113443812720d95c630649bf3aa3/conformance),
pinned to the immutable commit `059780cc0e5b113443812720d95c630649bf3aa3`
(specification revision `1.0.4`). `test/support/official_adapter.rb` is a
test-only JSON-Lines bridge: every operation calls the real public `Pikaid`
API, the file is not packaged in the gem, and it advertises only capabilities
the library genuinely provides. `parse_datetime` is omitted because the Ruby
API exposes whole-second timestamps rather than a datetime accessor.

```sh
# Run from the pinned suite's conformance/ directory.
python tools/run_adapter.py --automated-only \
  -- ruby -I/path/to/pikaid-ruby/lib /path/to/pikaid-ruby/test/support/official_adapter.rb
```

An `--automated-only` run exiting `0` means the automated checks passed. It is
**not** a conformance or security certification. A default run (without
`--automated-only`) exits `3` while the two manual CSPRNG review obligations,
`P-GENERATE-RNG-SOURCE` and `P-GENERATE-RNG-FAILURE`, remain outstanding.
Those require independent human review of the entropy source and of the
failure path, and no automated run can satisfy them. The
`Official conformance (pinned suite)` CI job executes the automated subset
only.

## Specification and license

- [pikaid specification revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4)
- [Security review packet](https://github.com/pikaid/pikaid-ruby/blob/main/SECURITY.md) — CSPRNG source and fail-closed audit map
- [Changelog](CHANGELOG.md)
- [MIT License](LICENSE) · Copyright (c) 2026 larananas (Lara G.)
