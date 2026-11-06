# frozen_string_literal: true

require_relative "test_helper"

class ValidationTest < PikaidTest
  VALID_ZERO = "00000000000000000000000000"
  SHAPE_ONLY_OVERFLOW = "0000000zzzzzzzzzzzzzzzzzzz"

  def test_all_zero_identifier_is_valid
    assert Pikaid.valid?(VALID_ZERO)
    assert Pikaid.well_formed?(VALID_ZERO)
    assert_equal 0, Pikaid.timestamp(VALID_ZERO)
    assert_equal "000000000000000000000000", Pikaid.randomness(VALID_ZERO).unpack("H*")[0]
  end

  def test_wrong_text_lengths_are_rejected
    [VALID_ZERO[0, 25], VALID_ZERO + "0", "", "0"].each do |value|
      refute Pikaid.valid?(value), value.inspect
      refute Pikaid.well_formed?(value), value.inspect
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(value) }
      assert_equal :invalid_string_length, error.reason
      assert_equal value, error.value
    end
  end

  def test_uppercase_and_non_base36_characters_are_rejected
    invalid = [
      "000000A0000000000000000000",
      "000000a000000000000000000Z",
      "000000-0000000000000000000",
      "000000_0000000000000000000",
      "000000 0000000000000000000",
      "000000+0000000000000000000",
      "000000/0000000000000000000",
      "000000.0000000000000000000",
      "0000000000000000000000000\n"
    ]

    invalid.each do |value|
      assert_equal 26, value.bytesize, value.inspect
      refute Pikaid.valid?(value), value.inspect
      refute Pikaid.well_formed?(value), value.inspect
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(value) }
      assert_equal :invalid_character, error.reason
    end
  end

  def test_non_ascii_values_are_rejected_without_coercion
    # 24 ASCII bytes + a two-byte UTF-8 character: 26 bytes, 25 characters.
    non_ascii = ("0" * 24) + "é"
    assert_equal 26, non_ascii.bytesize
    refute Pikaid.valid?(non_ascii)
    refute Pikaid.well_formed?(non_ascii)
    assert_equal :invalid_character,
                 assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(non_ascii) }.reason

    utf16 = VALID_ZERO.encode("UTF-16LE")
    refute Pikaid.valid?(utf16)
    refute Pikaid.well_formed?(utf16)
    assert_equal :invalid_string_length,
                 assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(utf16) }.reason
  end

  def test_non_string_values_are_rejected_not_coerced
    coercible = Object.new
    def coercible.to_str
      "00000000000000000000000000"
    end

    [nil, 123, :symbol, [], {}, coercible].each do |value|
      refute Pikaid.valid?(value), value.inspect
      refute Pikaid.well_formed?(value), value.inspect
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(value) }
      assert_equal :not_a_string, error.reason
      if value.nil?
        assert_nil error.value
      else
        assert_equal value, error.value
      end
    end
  end

  def test_well_formed_is_intentionally_weaker_than_valid
    assert Pikaid.well_formed?(SHAPE_ONLY_OVERFLOW)
    refute Pikaid.valid?(SHAPE_ONLY_OVERFLOW)

    error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(SHAPE_ONLY_OVERFLOW) }
    assert_equal :randomness_overflow, error.reason

    just_below_overflow = "0000000" + "7oiylpimjg5u2ca1ypq"
    assert Pikaid.valid?(just_below_overflow)
  end

  def test_binary_values_must_be_exactly_17_bytes
    [0, 1, 16, 18, 34].each do |length|
      binary = "\x00".b * length
      refute Pikaid.valid_binary?(binary), "length #{length}"
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.from_binary(binary) }
      assert_equal :invalid_binary_length, error.reason
      assert_equal length, error.value.bytesize
    end
  end

  def test_binary_timestamp_overflow_is_rejected
    overflows = [
      [format("%010x", Pikaid::MAX_TIMESTAMP + 1) + ("00" * 12)].pack("H*"),
      ["ffffffffff" + ("00" * 12)].pack("H*"),
      "\xff".b * 17
    ]

    overflows.each do |binary|
      assert_equal 17, binary.bytesize
      refute Pikaid.valid_binary?(binary)
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.from_binary(binary) }
      assert_equal :timestamp_overflow, error.reason
    end
  end

  def test_binary_non_string_values_are_rejected
    [nil, 17, :binary, Object.new].each do |value|
      refute Pikaid.valid_binary?(value), value.inspect
      error = assert_raises(Pikaid::InvalidIdError) { Pikaid.from_binary(value) }
      assert_equal :not_a_string, error.reason
    end
  end

  def test_binary_boundary_values_are_valid
    max_binary = [format("%010x", Pikaid::MAX_TIMESTAMP) + ("ff" * 12)].pack("H*")
    id = Pikaid.from_binary(max_binary)

    assert Pikaid.valid_binary?(max_binary)
    assert_equal Pikaid::MAX_TIMESTAMP, id.timestamp
    assert_equal "ff" * 12, id.randomness_hex
    assert_equal "zzzzzzz7oiylpimjg5u2ca1ypr", id.to_s
  end

  def test_binary_encoding_does_not_change_byte_semantics
    binary = ["006553f10000112233445566778899aabb"].pack("H*").force_encoding("UTF-8")
    id = Pikaid.from_binary(binary)

    assert_equal 1_700_000_000, id.timestamp
    assert_equal "00112233445566778899aabb", id.randomness_hex
    assert_equal "0s44we8002loz3po6mcf6vsn23", id.to_s
    assert_equal binary.b, id.to_binary
  end

  def test_id_constructor_validates_components
    assert_equal VALID_ZERO, Pikaid::Id.new(0, "\x00".b * 12).to_s

    timestamp_error = assert_raises(Pikaid::InvalidTimestampError) do
      Pikaid::Id.new(-1, "\x00".b * 12)
    end
    assert_equal :negative, timestamp_error.reason

    timestamp_error = assert_raises(Pikaid::InvalidTimestampError) do
      Pikaid::Id.new(Pikaid::MAX_TIMESTAMP + 1, "\x00".b * 12)
    end
    assert_equal :overflow, timestamp_error.reason

    timestamp_error = assert_raises(Pikaid::InvalidTimestampError) do
      Pikaid::Id.new("0", "\x00".b * 12)
    end
    assert_equal :not_an_integer, timestamp_error.reason

    randomness_error = assert_raises(Pikaid::InvalidIdError) do
      Pikaid::Id.new(0, "\x00".b * 11)
    end
    assert_equal :invalid_randomness_length, randomness_error.reason

    randomness_error = assert_raises(Pikaid::InvalidIdError) do
      Pikaid::Id.new(0, nil)
    end
    assert_equal :not_a_string, randomness_error.reason
  end

  def test_error_hierarchy_and_attributes
    id_error = Pikaid::InvalidIdError.new("bad", value: "x", reason: :invalid_character)
    timestamp_error = Pikaid::InvalidTimestampError.new("bad", timestamp: -1, reason: :negative)
    randomness_error = Pikaid::RandomnessError.new("bad")

    assert_kind_of Pikaid::Error, id_error
    assert_kind_of Pikaid::Error, timestamp_error
    assert_kind_of Pikaid::Error, randomness_error
    assert_kind_of StandardError, randomness_error
    assert_equal "x", id_error.value
    assert_equal :invalid_character, id_error.reason
    assert_equal(-1, timestamp_error.timestamp)
    assert_equal :negative, timestamp_error.reason
  end
end
