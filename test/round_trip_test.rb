# frozen_string_literal: true

require_relative "test_helper"

# Deterministic property/randomized tests. The PRNG is seeded so failures are
# reproducible; the oracle (ReferencePikaid) never calls Pikaid code.
class RoundTripTest < PikaidTest
  def test_randomized_round_trips_against_the_independent_oracle
    random = Random.new(0x5eed_1234)

    500.times do |iteration|
      timestamp = random.rand(0..Pikaid::MAX_TIMESTAMP)
      entropy_hex = Array.new(24) { random.rand(16).to_s(16) }.join

      expected_text = ReferencePikaid.id(timestamp, entropy_hex)
      expected_binary = ReferencePikaid.binary(timestamp, entropy_hex)

      id = Pikaid::Id.new(timestamp, [entropy_hex].pack("H*"))
      assert_equal expected_text, id.to_s, "iteration #{iteration}"
      assert_equal expected_binary, id.to_binary, "iteration #{iteration}"

      parsed = Pikaid.parse(expected_text)
      from_binary = Pikaid.from_binary(expected_binary)

      assert_equal id, parsed, "iteration #{iteration}"
      assert_equal id, from_binary, "iteration #{iteration}"
      assert_equal timestamp, parsed.timestamp, "iteration #{iteration}"
      assert_equal entropy_hex, parsed.randomness_hex, "iteration #{iteration}"
      assert_equal expected_text, from_binary.to_s, "iteration #{iteration}"
      assert_equal expected_binary, parsed.to_binary, "iteration #{iteration}"
      assert_equal expected_binary, Pikaid.to_binary(parsed), "iteration #{iteration}"
      assert_equal expected_binary, Pikaid.to_binary(parsed.to_s), "iteration #{iteration}"
      assert_equal Pikaid.to_binary(id), id.to_binary, "iteration #{iteration}"
    end
  end

  def test_randomized_binary_strings_with_in_range_timestamps_round_trip
    random = Random.new(0xbadc0de)

    500.times do |iteration|
      timestamp = random.rand(0..Pikaid::MAX_TIMESTAMP)
      binary = Array.new(5) { random.rand(256) }.pack("C*") + Array.new(12) { random.rand(256) }.pack("C*")
      binary = [format("%010x", timestamp)].pack("H*") + binary.byteslice(5, 12)

      id = Pikaid.from_binary(binary)
      assert_equal timestamp, id.timestamp, "iteration #{iteration}"
      assert_equal binary, id.to_binary, "iteration #{iteration}"
      assert_equal id, Pikaid.parse(id.to_s), "iteration #{iteration}"
      assert_equal binary, Pikaid.parse(id.to_s).to_binary, "iteration #{iteration}"
      assert_equal id, Pikaid.from_binary(Pikaid.to_binary(id.to_s)), "iteration #{iteration}"
    end
  end

  def test_ordering_is_preserved_across_representations
    random = Random.new(0x0d3e2)

    ids = Array.new(200) do
      timestamp = random.rand(0..Pikaid::MAX_TIMESTAMP)
      entropy_hex = Array.new(24) { random.rand(16).to_s(16) }.join
      Pikaid::Id.new(timestamp, [entropy_hex].pack("H*"))
    end

    sorted_text = ids.sort_by(&:to_s)
    sorted_binary = ids.sort_by(&:to_binary)

    assert_equal sorted_text.map(&:to_s), sorted_binary.map(&:to_s)

    sorted_text.each_cons(2) do |left, right|
      assert_operator left.to_s, :<=, right.to_s
      assert_operator left.to_binary, :<=, right.to_binary
    end
  end

  def test_generated_identifiers_round_trip_and_sort_consistently
    ids = Array.new(100) { Pikaid.generate }
    binaries = ids.map { |id| Pikaid.to_binary(id) }

    ids.zip(binaries).each do |text, binary|
      assert_equal text, Pikaid.from_binary(binary).to_s
      assert_equal binary, Pikaid.parse(text).to_binary
      assert Pikaid.valid?(text)
      assert Pikaid.valid_binary?(binary)
    end

    assert_equal ids.sort, ids.sort_by { |id| Pikaid.from_binary(Pikaid.to_binary(id)).to_s }
    assert_equal ids.map { |id| Pikaid.timestamp(id) }.sort,
                 ids.sort.map { |id| Pikaid.timestamp(id) }
  end

  def test_zero_and_max_boundaries_are_stable_under_repeated_conversion
    cases = [
      [0, "00" * 12],
      [0, "ff" * 12],
      [Pikaid::MAX_TIMESTAMP, "00" * 12],
      [Pikaid::MAX_TIMESTAMP, "ff" * 12],
      [Pikaid::MAX_TIMESTAMP, "7f" * 12],
      [1, "80" + ("00" * 11)]
    ]

    cases.each do |timestamp, entropy_hex|
      id = Pikaid::Id.new(timestamp, [entropy_hex].pack("H*"))
      text = id.to_s
      binary = id.to_binary

      10.times do
        text = Pikaid.from_binary(Pikaid.to_binary(text)).to_s
        binary = Pikaid.parse(Pikaid.from_binary(binary).to_s).to_binary
      end

      assert_equal id.to_s, text, "#{timestamp}/#{entropy_hex}"
      assert_equal id.to_binary, binary, "#{timestamp}/#{entropy_hex}"
    end
  end
end
