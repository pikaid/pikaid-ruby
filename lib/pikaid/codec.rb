# frozen_string_literal: true

module Pikaid
  # Internal Base36 and big-endian byte helpers.
  #
  # This module is not part of the stable public API; use the methods on
  # {Pikaid} and {Pikaid::Id} instead.
  module Codec
    module_function

    # Encode a non-negative Integer as fixed-width lowercase Base36.
    def encode_base36(value, width)
      unless value.is_a?(Integer) && value >= 0
        raise ArgumentError, "value must be a non-negative Integer"
      end

      encoded = value.to_s(36)
      if encoded.length > width
        raise RangeError, "#{value} does not fit in #{width} Base36 characters"
      end

      encoded.rjust(width, "0")
    end

    # Decode a Base36 string. Callers must validate the alphabet first.
    def decode_base36(value)
      value.to_i(36)
    end

    # Encode an unsigned Integer as +width+ big-endian bytes.
    def int_to_bytes(value, width)
      unless value.is_a?(Integer) && value >= 0 && value < (1 << (8 * width))
        raise RangeError, "#{value.inspect} does not fit in #{width} bytes"
      end

      bytes = Array.new(width)
      (width - 1).downto(0) do |index|
        bytes[index] = value & 0xff
        value >>= 8
      end
      bytes.pack("C*")
    end

    # Decode big-endian bytes as an unsigned Integer.
    def bytes_to_int(bytes)
      bytes.each_byte.inject(0) { |value, byte| (value << 8) | byte }
    end
  end
end
