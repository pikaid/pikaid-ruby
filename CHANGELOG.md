# Changelog

All notable changes to the official Ruby implementation of pikaid are
documented in this file.

The pikaid **identifier format** is immutable and unversioned. Entries here
version the Ruby library only.

## [1.0.0] - 2026-11-07

First stable release of the Ruby implementation. The release is prepared in the
repository; the gem has **not** been published to RubyGems yet.

### Added

- `Pikaid::Id`, an immutable value object with `timestamp`, `randomness`,
  `entropy`, `randomness_hex`, `to_s`, and `to_binary`.
- Module API: `generate`, `generate_binary`, `parse`, `from_binary`, `valid?`,
  `valid_binary?`, `well_formed?`, `timestamp`, `randomness`, `entropy`,
  `decode`, `to_binary`, and `compare`.
- Strict validation that rejects malformed, non-canonical, and overflowing
  input instead of coercing, truncating, or wrapping it.
- `Pikaid::InvalidIdError`, `Pikaid::InvalidTimestampError`, and
  `Pikaid::RandomnessError`, all inheriting from `Pikaid::Error`.
- Vendored official PHP v1.2.0 conformance vectors, byte-for-byte pinned by
  SHA-256, plus an independent reference oracle for conversion tests.
- Installed-gem consumer smoke test and packaged-file inventory check in CI.

### Fixed

- `Pikaid::Id#hash` now derives from the canonical value only. It previously
  included `self.class`, so a subclass instance that compares equal to a
  `Pikaid::Id` hashed differently and broke `Hash` lookups.
- Vector fixtures are forced to LF in the working tree, so their recorded
  SHA-256 digests hold on Windows checkouts with `core.autocrlf`.
- The Windows CI cell uses Ruby 3.4; `ruby/setup-ruby` does not publish a Ruby
  3.5 build for `windows-2025`. Ubuntu and macOS still exercise Ruby 3.5.

### Security

- Generation fails closed when `SecureRandom.random_bytes(12)` raises or
  returns the wrong number of bytes. There is no fallback entropy source.
- pikaid is an identifier, not an authentication token or capability.
