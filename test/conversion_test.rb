# frozen_string_literal: true

require_relative "test_helper"

# Conversion invariants: text <-> binary must be lossless, including leading
# zeroes and the upper boundaries of both fields.
class ConversionTest < PikaidTest
  def test_text_to_binary_for_every_official_vector
    VECTORS.fetch("valid").each do |vector|
      id = Pikaid.parse(vector.fetch("id"))
      expected = [vector.fetch("bin_hex")].pack("H*")

      assert_equal expected, id.to_binary, vector.fetch("name")
      assert_equal expected, Pikaid.to_binary(vector.fetch("id"))
      assert_equal vector.fetch("id"), Pikaid.from_binary(expected).to_s
    end
  end

  def test_binary_to_text_for_every_official_vector
    VECTORS.fetch("valid").each do |vector|
      binary = [vector.fetch("bin_hex")].pack("H*")

      assert_equal vector.fetch("id"), Pikaid.from_binary(binary).to_s
      assert_equal vector.fetch("id"), Pikaid.parse(vector.fetch("id")).to_s
    end
  end

  def test_time_of_day_round_trip_preserves_timestamp_and_entropy
    timestamps = [
      0, 1, 59, 60, 3_600, 86_399, 86_400,
      1_000_000_000, 1_700_000_000, 2_147_483_647,
      4_294_967_295, 4_294_967_296,
      Pikaid::MAX_TIMESTAMP - 1, Pikaid::MAX_TIMESTAMP
    ]
    entropies = [
      "00" * 12,
      "00" * 11 + "01",
      "00" * 11 + "ff",
      "ff" * 11 + "00",
      "ff" * 12,
      "00112233445566778899aabb",
      "800000000000000000000000"
    ]

    timestamps.each do |timestamp|
      entropies.each do |entropy_hex|
        expected_text = ReferencePikaid.id(timestamp, entropy_hex)
        expected_binary = ReferencePikaid.binary(timestamp, entropy_hex)

        id = Pikaid::Id.new(timestamp, [entropy_hex].pack("H*"))
        assert_equal expected_text, id.to_s, "#{timestamp}/#{entropy_hex}"
        assert_equal expected_binary, id.to_binary, "#{timestamp}/#{entropy_hex}"
        assert_equal id, Pikaid.parse(expected_text)
        assert_equal id, Pikaid.from_binary(expected_binary)
        assert_equal expected_text, Pikaid.from_binary(expected_binary).to_s
        assert_equal expected_binary, Pikaid.parse(expected_text).to_binary
      end
    end
  end

  def test_leading_zero_entropy_is_not_truncated
    id = Pikaid::Id.new(0, ("\x00".b * 11) + "\x2a")
    text = id.to_s

    assert_equal "00000000000000000000000016", text
    assert_equal 26, text.bytesize
    assert_equal "00000000000000000000002a", id.randomness_hex
    assert_equal id, Pikaid.parse(text)
  end

  def test_leading_zero_timestamp_is_zero_padded_to_seven_characters
    id = Pikaid::Id.new(1, "\x00".b * 12)

    assert_equal "0000001", id.to_s[0, 7]
    assert_equal "0000000001", id.to_binary.unpack("H*")[0][0, 10]
    assert_equal id, Pikaid.from_binary(id.to_binary)
  end

  def test_binary_layout_is_five_timestamp_bytes_then_twelve_entropy_bytes
    entropy_hex = "00112233445566778899aabb"
    timestamp = 1_700_000_000
    binary = Pikaid::Id.new(timestamp, [entropy_hex].pack("H*")).to_binary

    assert_equal 17, binary.bytesize
    assert_equal format("%010x", timestamp), binary.byteslice(0, 5).unpack("H*")[0]
    assert_equal entropy_hex, binary.byteslice(5, 12).unpack("H*")[0]
    assert_equal "ASCII-8BIT", binary.encoding.name
  end

  def test_randomness_and_entropy_accessors_agree
    id = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")

    assert_equal id.randomness, id.entropy
    assert_equal "00112233445566778899aabb", id.randomness_hex
    assert_equal id.randomness_hex, id.entropy_hex
    assert_equal 12, id.randomness.bytesize
    assert_equal "ASCII-8BIT", id.randomness.encoding.name
    assert id.randomness.frozen?
  end

  def test_timestamp_extraction_matches_prefix_decoding
    VECTORS.fetch("valid").each do |vector|
      id = Pikaid.parse(vector.fetch("id"))

      assert_equal vector.fetch("timestamp"), Pikaid.timestamp(id)
      assert_equal vector.fetch("timestamp"), Pikaid.timestamp(vector.fetch("id"))
      assert_equal vector.fetch("timestamp"), ReferencePikaid.decode(vector.fetch("id")[0, 7])
    end
  end
end
