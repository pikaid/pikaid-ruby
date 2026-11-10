# frozen_string_literal: true

require "securerandom"

require_relative "pikaid/version"
require_relative "pikaid/constants"
require_relative "pikaid/errors"
require_relative "pikaid/codec"
require_relative "pikaid/validation"
require_relative "pikaid/id"

# Official Ruby implementation of pikaid.
#
# A pikaid is exactly 26 lowercase ASCII Base36 characters: a seven-character
# whole-second Unix timestamp followed by nineteen characters encoding 96 bits
# of cryptographic randomness. Its binary representation is exactly 17 bytes:
# five big-endian timestamp bytes followed by the same twelve randomness bytes.
#
# The format is immutable and unversioned. See the canonical specification:
# https://github.com/pikaid/pikaid-specs/tree/v1.0.4
module Pikaid
  class << self
    # Generate a new pikaid as a 26-character String.
    #
    # Entropy comes from +SecureRandom.random_bytes(12)+. If the cryptographic
    # source fails, {RandomnessError} is raised; there is no fallback.
    #
    # @param timestamp [Integer, nil] whole Unix seconds, or nil for Time.now
    # @return [String] the canonical text form
    # @raise [InvalidTimestampError] if the timestamp is out of range
    # @raise [RandomnessError] if secure randomness cannot be obtained
    def generate(timestamp: nil)
      build_id(timestamp).to_s
    end

    # Generate a new pikaid as a 17-byte binary String.
    #
    # @param timestamp [Integer, nil] whole Unix seconds, or nil for Time.now
    # @return [String] the canonical binary form
    # @raise [InvalidTimestampError] if the timestamp is out of range
    # @raise [RandomnessError] if secure randomness cannot be obtained
    def generate_binary(timestamp: nil)
      build_id(timestamp).to_binary
    end

    # Strictly parse a text pikaid.
    #
    # Rejects non-String values, non-ASCII bytes, uppercase characters,
    # invalid characters, wrong lengths, and randomness values above 2^96 - 1.
    #
    # @param value [String]
    # @return [Id]
    # @raise [InvalidIdError] if +value+ is not a valid pikaid
    def parse(value)
      unless value.is_a?(String)
        raise InvalidIdError.new(
          "pikaid must be a String, got #{value.class}",
          value: value,
          reason: :not_a_string
        )
      end

      bytes = value.b
      if bytes.bytesize != STRING_LENGTH
        raise InvalidIdError.new(
          "pikaid must be exactly #{STRING_LENGTH} bytes, got #{bytes.bytesize}",
          value: value,
          reason: :invalid_string_length
        )
      end

      unless bytes.match?(/\A[0-9a-z]{26}\z/n)
        raise InvalidIdError.new(
          "pikaid must contain only lowercase ASCII Base36 characters",
          value: value,
          reason: :invalid_character
        )
      end

      timestamp = Codec.decode_base36(bytes.byteslice(0, TIMESTAMP_LENGTH))
      randomness_value = Codec.decode_base36(
        bytes.byteslice(TIMESTAMP_LENGTH, RANDOMNESS_LENGTH)
      )

      if randomness_value > MAX_RANDOMNESS
        raise InvalidIdError.new(
          "pikaid randomness exceeds the 96-bit maximum",
          value: value,
          reason: :randomness_overflow
        )
      end

      Id.new(timestamp, Codec.int_to_bytes(randomness_value, RANDOMNESS_BYTES))
    end

    # Strictly decode a 17-byte binary pikaid.
    #
    # @param value [String] exactly 17 bytes
    # @return [Id]
    # @raise [InvalidIdError] if the length or timestamp is invalid
    def from_binary(value)
      unless value.is_a?(String)
        raise InvalidIdError.new(
          "binary pikaid must be a String, got #{value.class}",
          value: value,
          reason: :not_a_string
        )
      end

      bytes = value.b
      if bytes.bytesize != BINARY_LENGTH
        raise InvalidIdError.new(
          "binary pikaid must be exactly #{BINARY_LENGTH} bytes, got #{bytes.bytesize}",
          value: value,
          reason: :invalid_binary_length
        )
      end

      timestamp = Codec.bytes_to_int(bytes.byteslice(0, TIMESTAMP_BYTES))
      if timestamp > MAX_TIMESTAMP
        raise InvalidIdError.new(
          "binary pikaid timestamp #{timestamp} exceeds the maximum #{MAX_TIMESTAMP}",
          value: value,
          reason: :timestamp_overflow
        )
      end

      Id.new(timestamp, bytes.byteslice(TIMESTAMP_BYTES, RANDOMNESS_BYTES))
    end

    # Full semantic validation of a text pikaid.
    #
    # Unlike {well_formed?}, this also rejects randomness above 2^96 - 1.
    # Returns false for non-String values instead of raising.
    #
    # @param value [Object]
    # @return [Boolean]
    def valid?(value)
      parse(value)
      true
    rescue InvalidIdError
      false
    end

    # Full semantic validation of a binary pikaid.
    #
    # @param value [Object]
    # @return [Boolean]
    def valid_binary?(value)
      from_binary(value)
      true
    rescue InvalidIdError
      false
    end

    # Shape-only check: exactly 26 bytes of [0-9a-z].
    #
    # This deliberately does not check the 96-bit randomness limit. A value can
    # be well formed but not valid; use {valid?} for full validation.
    #
    # @param value [Object]
    # @return [Boolean]
    def well_formed?(value)
      return false unless value.is_a?(String)

      bytes = value.b
      bytes.bytesize == STRING_LENGTH && bytes.match?(/\A[0-9a-z]{26}\z/n)
    end

    # Extract the timestamp from a text id or {Id}.
    #
    # @param value [String, Id]
    # @return [Integer]
    # @raise [InvalidIdError]
    def timestamp(value)
      coerce_id(value).timestamp
    end

    # Extract the 12 randomness bytes from a text id or {Id}.
    #
    # @param value [String, Id]
    # @return [String] ASCII-8BIT String
    # @raise [InvalidIdError]
    def randomness(value)
      coerce_id(value).randomness
    end

    # Compatibility alias for {randomness}.
    def entropy(value)
      randomness(value)
    end

    # Decode a text id or {Id} into [timestamp, randomness bytes].
    #
    # @param value [String, Id]
    # @return [Array(Integer, String)]
    # @raise [InvalidIdError]
    def decode(value)
      id = coerce_id(value)
      [id.timestamp, id.randomness]
    end

    # Convert a text id or {Id} to its 17-byte binary representation.
    #
    # @param value [String, Id]
    # @return [String]
    # @raise [InvalidIdError]
    def to_binary(value)
      coerce_id(value).to_binary
    end

    # Compare two text ids or {Id}s by canonical bytewise order.
    #
    # @param left [String, Id]
    # @param right [String, Id]
    # @return [Integer] -1, 0, or 1
    # @raise [InvalidIdError]
    def compare(left, right)
      coerce_id(left) <=> coerce_id(right)
    end

    private

    def build_id(timestamp)
      value = timestamp.nil? ? Time.now.to_i : timestamp
      Validation.timestamp!(value)
      Id.new(value, secure_random_bytes(RANDOMNESS_BYTES))
    end

    def secure_random_bytes(count)
      bytes = SecureRandom.random_bytes(count)
      unless bytes.is_a?(String) && bytes.bytesize == count
        raise RandomnessError,
              "secure random source returned #{bytes.inspect} instead of #{count} bytes"
      end

      bytes.b
    rescue RandomnessError
      raise
    rescue StandardError, SecurityError => error
      raise RandomnessError,
            "secure randomness unavailable (#{error.class}: #{error.message})"
    end

    def coerce_id(value)
      case value
      when Id
        value
      when String
        parse(value)
      else
        raise InvalidIdError.new(
          "expected a pikaid String or Pikaid::Id, got #{value.class}",
          value: value,
          reason: :not_a_string
        )
      end
    end
  end
end
