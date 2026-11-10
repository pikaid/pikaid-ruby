# frozen_string_literal: true

module Pikaid
  # Internal strict validation shared by generation and value objects.
  module Validation
    module_function

    # Ensure +timestamp+ is an Integer in 0..MAX_TIMESTAMP.
    def timestamp!(timestamp)
      unless timestamp.is_a?(Integer)
        raise InvalidTimestampError.new(
          "timestamp must be an Integer, got #{timestamp.class}",
          timestamp: timestamp,
          reason: :not_an_integer
        )
      end

      if timestamp < 0
        raise InvalidTimestampError.new(
          "timestamp must not be negative, got #{timestamp}",
          timestamp: timestamp,
          reason: :negative
        )
      end

      return timestamp if timestamp <= MAX_TIMESTAMP

      raise InvalidTimestampError.new(
        "timestamp #{timestamp} exceeds the maximum #{MAX_TIMESTAMP}",
        timestamp: timestamp,
        reason: :overflow
      )
    end

    # Ensure +randomness+ is exactly 12 bytes.
    def randomness!(randomness)
      unless randomness.is_a?(String)
        raise InvalidIdError.new(
          "randomness must be a 12-byte String, got #{randomness.class}",
          value: randomness,
          reason: :not_a_string
        )
      end

      return randomness if randomness.bytesize == RANDOMNESS_BYTES

      raise InvalidIdError.new(
        "randomness must be exactly #{RANDOMNESS_BYTES} bytes, got #{randomness.bytesize}",
        value: randomness,
        reason: :invalid_randomness_length
      )
    end
  end
end
