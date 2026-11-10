# frozen_string_literal: true

require_relative "test_helper"
require "digest"

# Cross-implementation conformance matrix for the pikaid v1.0.4 wire format.
#
# Every expected text and binary value below is written out literally. They were
# derived independently from the specification (fixed-width lower-case Base36
# for a 7-character timestamp followed by a 19-character 96-bit randomness
# field, and five big-endian timestamp bytes followed by the twelve randomness
# bytes) and cross-checked against the official PHP v1.2.0 fixture. A regression
# in an encoder, decoder, or validator cannot pass by comparing Pikaid with
# itself.
class ConformanceTest < PikaidTest
  SPEC_REVISION = "1.0.4"
  SPEC_COMMIT = "17014d76f568c3ac9f9ce2927c1a018fdbc36d1d"
  PHP_RELEASE = "v1.2.0"
  PHP_COMMIT = "e3f843edeb5157a5d2d25196cac0d69580810a95"
  FIXTURE_SHA256 = "b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500"

  # [name, timestamp, entropy_hex, canonical_text, canonical_binary_hex]
  CANONICAL_CASES = [
    ["all-zero", 0, "000000000000000000000000",
     "00000000000000000000000000",
     "0000000000000000000000000000000000"],
    ["timestamp-one-entropy-one", 1, "000000000000000000000001",
     "00000010000000000000000001",
     "0000000001000000000000000000000001"],
    ["max-values", 78_364_164_095, "ffffffffffffffffffffffff",
     "zzzzzzz7oiylpimjg5u2ca1ypr",
     "123ede3fffffffffffffffffffffffffff"],
    ["sample-1700000000", 1_700_000_000, "00112233445566778899aabb",
     "0s44we8002loz3po6mcf6vsn23",
     "006553f10000112233445566778899aabb"],
    ["leading-zero-entropy", 0, "00000000000000000000002a",
     "00000000000000000000000016",
     "000000000000000000000000000000002a"],
    ["max-entropy-zero-timestamp", 0, "ffffffffffffffffffffffff",
     "00000007oiylpimjg5u2ca1ypr",
     "0000000000ffffffffffffffffffffffff"],
    ["max-timestamp-zero-entropy", 78_364_164_095, "000000000000000000000000",
     "zzzzzzz0000000000000000000",
     "123ede3fff000000000000000000000000"],
    ["max-timestamp-minus-one-max-entropy", 78_364_164_094, "ffffffffffffffffffffffff",
     "zzzzzzy7oiylpimjg5u2ca1ypr",
     "123ede3ffeffffffffffffffffffffffff"],
    ["mid-1234567890", 1_234_567_890, "deadbeefcafebabe00112233",
     "0kf12oi6oj7k6n2wcap1wzk3lf",
     "00499602d2deadbeefcafebabe00112233"],
    ["uint32-max-timestamp", 4_294_967_295, "000000000000000000000001",
     "1z141z30000000000000000001",
     "00ffffffff000000000000000000000001"],
    ["uint32-plus-one-timestamp", 4_294_967_296, "7fffffffffffffffffffffff",
     "1z141z43u9haurb9q2x1650zcv",
     "01000000007fffffffffffffffffffffff"],
    ["timestamp-36", 36, "000000000000000000000001",
     "00000100000000000000000001",
     "0000000024000000000000000000000001"],
    ["timestamp-35-max-entropy", 35, "ffffffffffffffffffffffff",
     "000000z7oiylpimjg5u2ca1ypr",
     "0000000023ffffffffffffffffffffffff"],
    ["max-timestamp-minus-two-msb", 78_364_164_093, "800000000000000000000000",
     "zzzzzzx3u9haurb9q2x1650zcw",
     "123ede3ffd800000000000000000000000"],
    ["same-second-later", 1_700_000_001, "000000000000000000000000",
     "0s44we90000000000000000000",
     "006553f101000000000000000000000000"],
    # Seeded with Python's random.Random(0x5eed), so these are deterministic and
    # reproducible but were not chosen to hit a particular implementation path.
    ["seeded-0", 58_468_606_939, "6df9b7dccea71b88471b8163",
     "quyp5uj3askgd1u0eedouhm99f",
     "0d9d0023db6df9b7dccea71b88471b8163"],
    ["seeded-1", 44_616_136_526, "b87c31d7746e018e693a7c37",
     "khvan9q5j9zrq224igkqfajm0n",
     "0a6354374eb87c31d7746e018e693a7c37"],
    ["seeded-2", 47_219_391_279, "b84be169f66c05e3637b6364",
     "lox7fhr5j2nkftczha099m34h0",
     "0afe7ebb2fb84be169f66c05e3637b6364"],
    ["seeded-3", 38_396_817_520, "ab4046b9937840a98aafced8",
     "hn0h20g54zd73riqnw0pcmxbko",
     "08f0a0f070ab4046b9937840a98aafced8"],
    ["seeded-4", 28_018_791_603, "8785bccb10a1853337914683",
     "cvdnxyr42e01s9ai9b8qg8oebn",
     "06860cd4b38785bccb10a1853337914683"]
  ].freeze

  # [name, rejected value, expected error reason]
  STRING_REJECTIONS = [
    ["nil", nil, :not_a_string],
    ["integer", 1, :not_a_string],
    ["symbol", :pikaid, :not_a_string],
    ["object", Object.new, :not_a_string],
    ["empty", "", :invalid_string_length],
    ["25-characters", "0" * 25, :invalid_string_length],
    ["27-characters", "0" * 27, :invalid_string_length],
    ["26-multibyte-characters", "\u00e9" * 26, :invalid_string_length],
    ["uppercase-timestamp", "A" + ("0" * 25), :invalid_character],
    ["uppercase-entropy", ("0" * 8) + "A" + ("0" * 17), :invalid_character],
    ["dash", "000000-0000000000000000000", :invalid_character],
    ["underscore", "000000_0000000000000000000", :invalid_character],
    ["space", "000000 0000000000000000000", :invalid_character],
    ["newline", ("0" * 25) + "\n", :invalid_character],
    ["nul-byte", ("0" * 25) + "\u0000", :invalid_character],
    ["non-ascii-byte", ("0" * 24) + "\u00e9", :invalid_character],
    ["trailing-uppercase", "0s44we8002loz3po6mcf6vsn2A", :invalid_character],
    ["randomness-overflow-fixture", "0000000zzzzzzzzzzzzzzzzzzz", :randomness_overflow],
    ["randomness-overflow-2-pow-96", "00000007oiylpimjg5u2ca1yps", :randomness_overflow],
    ["randomness-overflow-all-z", ("0" * 7) + ("z" * 19), :randomness_overflow]
  ].freeze

  # [name, rejected value, expected error reason]
  BINARY_REJECTIONS = [
    ["nil", nil, :not_a_string],
    ["integer", 1, :not_a_string],
    ["symbol", :pikaid, :not_a_string],
    ["object", Object.new, :not_a_string],
    ["empty", "".b, :invalid_binary_length],
    ["16-bytes", ("\u0000" * 16).b, :invalid_binary_length],
    ["18-bytes", ("\u0000" * 18).b, :invalid_binary_length],
    ["32-hex-characters", ["00" * 16].pack("H*"), :invalid_binary_length],
    ["36-hex-characters", ["00" * 18].pack("H*"), :invalid_binary_length],
    ["timestamp-overflow-one", ["123ede4000" + ("00" * 12)].pack("H*"), :timestamp_overflow],
    ["timestamp-overflow-40-bit-max", ["ffffffffff" + ("00" * 12)].pack("H*"), :timestamp_overflow]
  ].freeze

  def test_provenance_is_pinned_to_the_spec_and_the_official_php_fixture
    assert_equal SPEC_REVISION, VECTORS.dig("meta", "spec_revision")
    assert_match(/\Av\d+\.\d+\.\d+\z/, PHP_RELEASE)

    assert_match(/\A[0-9a-f]{40}\z/, SPEC_COMMIT)
    assert_match(/\A[0-9a-f]{40}\z/, PHP_COMMIT)

    fixture = File.expand_path("vectors/pikaid-v1.json", __dir__)
    assert_equal FIXTURE_SHA256, Digest::SHA256.hexdigest(File.binread(fixture))

    # The recorded provenance note must agree with the constants above, so a
    # silently swapped fixture or a stale pin is visible in the diff.
    note = File.binread(File.expand_path("vectors/README.md", __dir__))

    assert_includes note, SPEC_REVISION
    assert_includes note, PHP_RELEASE
    assert_includes note, PHP_COMMIT
    assert_includes note, FIXTURE_SHA256
    assert_match(/[0-9a-f]{64}  pikaid-v1\.schema\.json/, note)
  end

  def test_every_canonical_case_matches_the_literal_matrix
    CANONICAL_CASES.each do |name, timestamp, entropy_hex, text, binary_hex|
      binary = [binary_hex].pack("H*")
      entropy = [entropy_hex].pack("H*")

      assert_equal 26, text.bytesize, "#{name}: text width"
      assert_equal 17, binary.bytesize, "#{name}: binary width"
      assert_equal 24, entropy_hex.length, "#{name}: entropy hex width"

      # The independent oracle must agree with the literal matrix, so a typo in
      # the table is caught before it is used to judge Pikaid.
      assert_equal text, ReferencePikaid.id(timestamp, entropy_hex), "#{name}: oracle text"
      assert_equal binary, ReferencePikaid.binary(timestamp, entropy_hex), "#{name}: oracle binary"

      from_components = Pikaid::Id.new(timestamp, entropy)
      assert_equal text, from_components.to_s, "#{name}: Id#to_s"
      assert_equal binary, from_components.to_binary, "#{name}: Id#to_binary"
      assert_equal entropy_hex, from_components.randomness_hex, "#{name}: Id#randomness_hex"

      parsed = Pikaid.parse(text)
      assert_equal timestamp, parsed.timestamp, "#{name}: parse timestamp"
      assert_equal entropy_hex, parsed.randomness_hex, "#{name}: parse randomness"
      assert_equal entropy, parsed.randomness, "#{name}: parse randomness bytes"
      assert_equal text, parsed.to_s, "#{name}: parse round trip"
      assert_equal binary, parsed.to_binary, "#{name}: parse binary"

      decoded = Pikaid.from_binary(binary)
      assert_equal text, decoded.to_s, "#{name}: from_binary text"
      assert_equal timestamp, decoded.timestamp, "#{name}: from_binary timestamp"
      assert_equal entropy_hex, decoded.randomness_hex, "#{name}: from_binary randomness"
      assert_equal binary, decoded.to_binary, "#{name}: from_binary round trip"

      assert Pikaid.valid?(text), "#{name}: valid text"
      assert Pikaid.well_formed?(text), "#{name}: well-formed text"
      assert Pikaid.valid_binary?(binary), "#{name}: valid binary"
      assert_equal timestamp, Pikaid.timestamp(text), "#{name}: module timestamp"
      assert_equal entropy, Pikaid.randomness(text), "#{name}: module randomness"
      assert_equal entropy, Pikaid.entropy(text), "#{name}: module entropy alias"
      assert_equal [timestamp, entropy], Pikaid.decode(text), "#{name}: module decode"
      assert_equal binary, Pikaid.to_binary(text), "#{name}: module to_binary"
      assert_equal 0, Pikaid.compare(text, decoded), "#{name}: module compare"
    end
  end

  def test_generation_uses_the_same_wire_format_for_every_canonical_case
    CANONICAL_CASES.each do |name, timestamp, entropy_hex, text, binary_hex|
      entropy = [entropy_hex].pack("H*")

      with_random_bytes(entropy) do
        assert_equal text, Pikaid.generate(timestamp: timestamp), "#{name}: generate"
        assert_equal binary_hex, Pikaid.generate_binary(timestamp: timestamp).unpack("H*")[0],
                     "#{name}: generate_binary"
      end
    end
  end

  def test_official_php_fixture_valid_vectors_are_covered_by_the_matrix
    expected = CANONICAL_CASES.each_with_object({}) do |(name, timestamp, entropy_hex, text, binary_hex), memo|
      memo[name] = [timestamp, entropy_hex, text, binary_hex]
    end

    assert_equal 4, VECTORS.fetch("valid").length
    VECTORS.fetch("valid").each do |vector|
      name = vector.fetch("name")
      # Fixture names differ from matrix labels for one vector; compare values,
      # not names, and require an exact match somewhere in the matrix.
      assert_includes expected.values,
                      [vector.fetch("timestamp"), vector.fetch("entropy_hex"),
                       vector.fetch("id"), vector.fetch("bin_hex")],
                      name
    end
  end

  def test_the_string_negative_corpus_is_rejected_with_the_documented_reason
    STRING_REJECTIONS.each do |name, value, reason|
      refute Pikaid.valid?(value), "#{name}: valid?"

      error = assert_raises(Pikaid::InvalidIdError, name) { Pikaid.parse(value) }
      assert_equal reason, error.reason, name
      assert_equal value, error.value, name unless value.nil?
      refute_empty error.message, name

      shape = reason == :randomness_overflow
      assert_equal shape, Pikaid.well_formed?(value), "#{name}: shape-only result"
    end
  end

  def test_the_binary_negative_corpus_is_rejected_with_the_documented_reason
    BINARY_REJECTIONS.each do |name, value, reason|
      refute Pikaid.valid_binary?(value), "#{name}: valid_binary?"

      error = assert_raises(Pikaid::InvalidIdError, name) { Pikaid.from_binary(value) }
      assert_equal reason, error.reason, name
      assert_equal value, error.value, name unless value.nil?
      refute_empty error.message, name
    end
  end

  def test_96_bit_and_40_bit_boundaries_are_accepted_exactly_once
    max_suffix = "7oiylpimjg5u2ca1ypr"
    just_over_suffix = "7oiylpimjg5u2ca1yps"
    max_timestamp_prefix = "zzzzzzz"

    assert Pikaid.valid?("0000000" + max_suffix)
    assert_equal Pikaid::MAX_RANDOMNESS, Pikaid.parse("0000000" + max_suffix).randomness.unpack("H*")[0].to_i(16)
    refute Pikaid.valid?("0000000" + just_over_suffix)
    assert Pikaid.well_formed?("0000000" + just_over_suffix)

    assert Pikaid.valid?(max_timestamp_prefix + ("0" * 19))
    assert_equal Pikaid::MAX_TIMESTAMP, Pikaid.timestamp(max_timestamp_prefix + ("0" * 19))
    refute Pikaid.valid_binary?(["123ede4000" + ("00" * 12)].pack("H*"))
    refute Pikaid.valid_binary?(["ffffffffff" + ("00" * 12)].pack("H*"))
  end

  def test_generation_rejects_timestamps_outside_the_representable_range
    [
      -1,
      Pikaid::MAX_TIMESTAMP + 1,
      2**40,
      1.5,
      "1700000000",
      :now
    ].each do |timestamp|
      error = assert_raises(Pikaid::InvalidTimestampError, timestamp.inspect) do
        Pikaid.generate(timestamp: timestamp)
      end
      refute_nil error.reason, timestamp.inspect
    end
  end

  def test_canonical_order_is_identical_in_text_and_binary
    ordered = CANONICAL_CASES.sort_by { |(_name, timestamp, entropy_hex, _text, _binary_hex)| [timestamp, entropy_hex] }
    texts = ordered.map { |(_name, _timestamp, _entropy_hex, text, _binary_hex)| text }
    binaries = ordered.map { |(_name, _timestamp, _entropy_hex, _text, binary_hex)| [binary_hex].pack("H*") }

    assert_equal texts, texts.sort
    assert_equal binaries, binaries.sort

    ordered.each_cons(2) do |left, right|
      left_text = left[3]
      right_text = right[3]
      assert_operator left_text, :<, right_text
      assert_operator Pikaid.parse(left_text), :<, Pikaid.parse(right_text)
      assert_operator [left[4]].pack("H*"), :<, [right[4]].pack("H*")
    end
  end

  def test_decoded_values_do_not_alias_mutable_input_strings
    text = +"0s44we8002loz3po6mcf6vsn23"
    entropy = ["00112233445566778899aabb"].pack("H*")
    binary = ["006553f10000112233445566778899aabb"].pack("H*")

    parsed_text = Pikaid.parse(text)
    parsed_binary = Pikaid.from_binary(binary)
    from_components = Pikaid::Id.new(1_700_000_000, entropy)

    text.replace("ffffffffffffffffffffffffff")
    entropy.setbyte(0, 0xff)
    binary.setbyte(0, 0xff)

    assert_equal "0s44we8002loz3po6mcf6vsn23", parsed_text.to_s
    assert_equal "0s44we8002loz3po6mcf6vsn23", parsed_binary.to_s
    assert_equal "0s44we8002loz3po6mcf6vsn23", from_components.to_s
    assert_equal "00112233445566778899aabb", parsed_text.randomness_hex
    assert_equal "00112233445566778899aabb", from_components.randomness_hex

    refute parsed_text.to_s.equal?(text)
    refute parsed_binary.to_binary.equal?(binary)
    refute from_components.randomness.equal?(entropy)
  end

  def test_generation_is_thread_safe_and_uses_fresh_entropy_per_call
    timestamp = 1_700_000_000
    threads = Array.new(8) do
      Thread.new { Array.new(25) { Pikaid.generate(timestamp: timestamp) } }
    end
    results = threads.flat_map(&:value)

    assert_equal 200, results.length
    assert_equal 200, results.uniq.length
    results.each do |text|
      assert_equal 26, text.bytesize
      assert_equal timestamp, Pikaid.timestamp(text)
      assert Pikaid.valid?(text)
    end
  end

  def test_a_backwards_clock_step_is_encoded_verbatim_and_caches_nothing
    entropy = "\u0000".b * 12

    with_random_bytes(entropy) do
      later = nil
      Time.stub(:now, Time.at(1_700_000_010)) { later = Pikaid.generate }
      earlier = nil
      Time.stub(:now, Time.at(1_700_000_000)) { earlier = Pikaid.generate }

      assert_equal 1_700_000_010, Pikaid.timestamp(later)
      assert_equal 1_700_000_000, Pikaid.timestamp(earlier)
      assert_operator earlier, :<, later

      # No cached clock or counter: the same instant and entropy re-encode
      # identically instead of drifting forward.
      Time.stub(:now, Time.at(1_700_000_000)) do
        assert_equal earlier, Pikaid.generate
      end
    end
  end

  def test_timestamps_convert_to_the_documented_utc_instant
    cases = {
      0 => "1970-01-01T00:00:00Z",
      1_234_567_890 => "2009-02-13T23:31:30Z",
      1_700_000_000 => "2023-11-14T22:13:20Z",
      Pikaid::MAX_TIMESTAMP => "4453-04-05T15:21:35Z"
    }

    cases.each do |timestamp, formatted|
      id = Pikaid::Id.new(timestamp, "\u0000".b * 12)
      assert_equal formatted, Time.at(id.timestamp).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
    end
  end
end
