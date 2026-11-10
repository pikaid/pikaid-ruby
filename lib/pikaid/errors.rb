# frozen_string_literal: true

module Pikaid
  # Base class for every error raised by pikaid.
  class Error < StandardError; end

  # Raised when a text or binary value is not a valid pikaid.
  #
  # +reason+ is a stable machine-readable symbol describing the first failed
  # check. +value+ is the rejected input (not included in the message).
  class InvalidIdError < Error
    attr_reader :value, :reason

    def initialize(message = "invalid pikaid", value: nil, reason: nil)
      @value = value
      @reason = reason
      super(message)
    end
  end

  # Raised when a timestamp cannot be generated or represented.
  class InvalidTimestampError < Error
    attr_reader :timestamp, :reason

    def initialize(message = "invalid pikaid timestamp", timestamp: nil, reason: nil)
      @timestamp = timestamp
      @reason = reason
      super(message)
    end
  end

  # Raised when secure randomness cannot be obtained or has the wrong size.
  #
  # Generation fails closed: this error is never replaced by a non-cryptographic
  # fallback.
  class RandomnessError < Error; end
end
