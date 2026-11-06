# frozen_string_literal: true

module Pikaid
  # Total length of the canonical text representation, in ASCII characters.
  STRING_LENGTH = 26

  # Total length of the canonical binary representation, in bytes.
  BINARY_LENGTH = 17

  # Width of the timestamp prefix in the text representation.
  TIMESTAMP_LENGTH = 7

  # Width of the randomness suffix in the text representation.
  RANDOMNESS_LENGTH = 19

  # Width of the timestamp field in the binary representation.
  TIMESTAMP_BYTES = 5

  # Width of the randomness field in the binary representation.
  RANDOMNESS_BYTES = 12

  # Largest valid timestamp: 36^7 - 1 (4453-04-05 15:21:35 UTC).
  MAX_TIMESTAMP = 78_364_164_095

  # Largest valid randomness value: 2^96 - 1.
  MAX_RANDOMNESS = 79_228_162_514_264_337_593_543_950_335

  # Permitted alphabet, in ascending digit order.
  ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz".freeze
end
