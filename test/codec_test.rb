# frozen_string_literal: true

require_relative "test_helper"

# Internal codec checks. These pin down the low-level helpers that the public
# API relies on, including padding and byte-order behaviour.
class CodecTest < PikaidTest
  CODEC = Pikaid::Codec

  def test_encode_base36_pads_and_matches_the_oracle
    {
      0 => "0000000",
      1 => "0000001",
      35 => "000000z",
      36 => "0000010",
      1_000 => "00000rs",
      1_700_000_000 => "0s44we8",
      Pikaid::MAX_TIMESTAMP => "zzzzzzz"
    }.each do |value, expected|
      assert_equal expected, CODEC.encode_base36(value, 7)
      assert_equal ReferencePikaid.encode(value, 7), CODEC.encode_base36(value, 7)
    end
  end

  def test_encode_base36_rejects_negative_and_non_integer_values
    [-1, "1", 1.0, nil, :one].each do |value|
      assert_raises(ArgumentError, value.inspect) { CODEC.encode_base36(value, 7) }
    end
  end

  def test_encode_base36_rejects_values_that_do_not_fit
    assert_raises(RangeError) { CODEC.encode_base36(36**7, 7) }
    assert_raises(RangeError) { CODEC.encode_base36(36**19, 19) }
    assert_equal "z" * 19, CODEC.encode_base36((36**19) - 1, 19)
  end

  def test_decode_base36_inverts_encoding
    values = [0, 1, 35, 36, 1_299, 1_700_000_000, Pikaid::MAX_TIMESTAMP]

    values.each do |value|
      encoded = CODEC.encode_base36(value, 7)
      assert_equal value, CODEC.decode_base36(encoded)
      assert_equal value, ReferencePikaid.decode(encoded)
    end
  end

  def test_int_to_bytes_is_unsigned_big_endian
    assert_equal "\x00", CODEC.int_to_bytes(0, 1)
    assert_equal [0xff].pack("C"), CODEC.int_to_bytes(255, 1)
    assert_equal [0x01, 0x00].pack("C*"), CODEC.int_to_bytes(256, 2)
    assert_equal [0x00, 0x00, 0x00, 0x00, 0x01].pack("C*"), CODEC.int_to_bytes(1, 5)
    assert_equal [0x12, 0x3e, 0xde, 0x3f].pack("C*"), CODEC.int_to_bytes(0x123ede3f, 4)
    assert_equal("\xff".b * 5, CODEC.int_to_bytes((2**40) - 1, 5))
  end

  def test_int_to_bytes_rejects_out_of_range_values
    [-1, 256, 2**32].each do |value|
      assert_raises(RangeError, value.inspect) { CODEC.int_to_bytes(value, 1) }
    end

    assert_raises(RangeError) { CODEC.int_to_bytes(2**40, 5) }
    assert_raises(RangeError) { CODEC.int_to_bytes("1", 5) }
  end

  def test_bytes_to_int_inverts_int_to_bytes
    random = Random.new(42)

    200.times do
      width = random.rand(1..17)
      value = random.rand(0...(2**(8 * width)))

      bytes = CODEC.int_to_bytes(value, width)
      assert_equal width, bytes.bytesize
      assert_equal "ASCII-8BIT", bytes.encoding.name
      assert_equal value, CODEC.bytes_to_int(bytes)
      assert_equal bytes, [format("%0#{width * 2}x", value)].pack("H*")
    end
  end

  def test_bytes_to_int_handles_empty_and_high_bit_bytes
    assert_equal 0, CODEC.bytes_to_int("")
    assert_equal 0x80, CODEC.bytes_to_int("\x80".b)
    assert_equal 0xdeadbeef, CODEC.bytes_to_int("\xde\xad\xbe\xef".b)
  end
end
