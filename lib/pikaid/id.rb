# frozen_string_literal: true

module Pikaid
  # Immutable value object for a decoded pikaid.
  #
  # The canonical text and binary representations are computed once at
  # construction. Use {Pikaid.parse} or {Pikaid.from_binary} to decode an
  # existing value; use {Pikaid.generate} for new identifiers.
  #
  #   id = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")
  #   id.timestamp        #=> 1700000000
  #   id.randomness       #=> "\x00\x11\"3DUfw\x88\x99\xAA\xBB"
  #   id.randomness_hex   #=> "00112233445566778899aabb"
  #   id.to_binary.bytesize #=> 17
  class Id
    include Comparable

    # Unix timestamp in whole seconds.
    attr_reader :timestamp

    # Exactly 12 bytes of randomness, as an ASCII-8BIT String.
    attr_reader :randomness

    # Compatibility alias for the canonical conceptual name +randomness+.
    alias entropy randomness

    # Build an identifier from decoded components.
    #
    # This constructor validates its inputs but does not generate randomness.
    # Prefer {Pikaid.generate} for creating new identifiers.
    #
    # @param timestamp [Integer] whole Unix seconds in 0..MAX_TIMESTAMP
    # @param randomness [String] exactly 12 bytes
    # @raise [InvalidTimestampError] if the timestamp is out of range
    # @raise [InvalidIdError] if the randomness is not exactly 12 bytes
    def initialize(timestamp, randomness)
      @timestamp = Validation.timestamp!(timestamp)
      @randomness = Validation.randomness!(randomness).b.freeze

      @string = (
        Codec.encode_base36(@timestamp, TIMESTAMP_LENGTH) +
        Codec.encode_base36(Codec.bytes_to_int(@randomness), RANDOMNESS_LENGTH)
      ).freeze

      @binary = (
        Codec.int_to_bytes(@timestamp, TIMESTAMP_BYTES) + @randomness
      ).freeze

      freeze
    end

    # The canonical 26-character lowercase Base36 identifier.
    #
    # @return [String] a frozen String
    def to_s
      @string
    end

    # The canonical 17-byte binary representation.
    #
    # Layout: five big-endian timestamp bytes followed by the original twelve
    # randomness bytes.
    #
    # @return [String] a frozen ASCII-8BIT String
    def to_binary
      @binary
    end

    # The randomness field as 24 lowercase hexadecimal characters.
    #
    # @return [String]
    def randomness_hex
      @randomness.unpack("H*")[0]
    end

    # Compatibility alias for {#randomness_hex}.
    alias entropy_hex randomness_hex

    # Compare two identifiers by canonical bytewise order.
    #
    # Identifiers with different timestamps sort chronologically. Identifiers
    # generated within the same second sort by their random suffix, not by
    # generation order.
    #
    # @param other [Object]
    # @return [Integer, nil] -1, 0, 1, or nil when +other+ is not an Id
    def <=>(other)
      return nil unless other.is_a?(Id)

      @string.b <=> other.to_s.b
    end

    # Value equality for identifiers.
    def ==(other)
      other.is_a?(Id) && @string.b == other.to_s.b
    end

    alias eql? ==

    # Hash consistent with {#==} and {#eql?}.
    #
    # Equality is defined by the canonical value, not by the concrete class, so
    # the hash must be derived from the value alone. Including +self.class+
    # would let a subclass instance compare equal to a base instance while
    # hashing differently, breaking Hash lookup for equal values.
    def hash
      @string.hash
    end

    def inspect
      "#<#{self.class} #{@string.inspect}>"
    end
  end
end
