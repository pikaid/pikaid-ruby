# frozen_string_literal: true

# A deliberately independent reference encoder/decoder used as a test oracle.
#
# It does not call Pikaid internals. It derives Base36 digits from a literal
# alphabet and builds binary values with hexadecimal strings, so conversion
# tests are not solely self-referential.
module ReferencePikaid
  ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
  MAX_TIMESTAMP = 78_364_164_095

  def self.encode(value, width)
    raise ArgumentError, "value must be non-negative" if value < 0

    digits = []
    width.times do
      digits.unshift(ALPHABET[value % 36])
      value /= 36
    end
    if value != 0
      raise ArgumentError, "value does not fit in #{width} Base36 characters"
    end

    digits.join
  end

  def self.decode(string)
    string.each_char.inject(0) do |value, character|
      (value * 36) + ALPHABET.index(character)
    end
  end

  def self.id(timestamp, entropy_hex)
    raise ArgumentError, "timestamp out of range" unless timestamp.between?(0, MAX_TIMESTAMP)
    raise ArgumentError, "entropy must be 24 hex characters" unless entropy_hex.match?(/\A[0-9a-f]{24}\z/)

    encode(timestamp, 7) + encode(entropy_hex.to_i(16), 19)
  end

  def self.binary(timestamp, entropy_hex)
    raise ArgumentError, "timestamp out of range" unless timestamp.between?(0, MAX_TIMESTAMP)
    raise ArgumentError, "entropy must be 24 hex characters" unless entropy_hex.match?(/\A[0-9a-f]{24}\z/)

    [format("%010x", timestamp) + entropy_hex].pack("H*")
  end
end
