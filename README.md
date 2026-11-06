<p align="center">
  <img src="https://raw.githubusercontent.com/pikaid/pikaid-specs/v1.0.4/logo.png" alt="pikaid" width="300" />
</p>

<p align="center">
  <strong>Small · Sortable · Secure ID generator</strong>
</p>

# pikaid — Official Ruby Implementation

**Status: source-only pre-release (`0.1.0`). Not published to RubyGems.**

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

The library is tested locally on Ruby 2.6.10 (macOS, universal ARM64). GitHub
Actions is configured to test MRI/YARV Ruby 2.6 through 3.5 on Ubuntu, plus
macOS and Windows for Ruby 3.5.

## Installation

This gem is **not published** yet. Install it from source:

```sh
git clone https://github.com/pikaid/pikaid-ruby.git
cd pikaid-ruby
bundle install
bundle exec rake test
```

To build and install a local gem:

```sh
gem build pikaid.gemspec
gem install ./pikaid-0.1.0.gem
```

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

## Specification and license

- [pikaid specification revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4)
- [MIT License](LICENSE) · Copyright (c) 2026 larananas (Lara G.)
