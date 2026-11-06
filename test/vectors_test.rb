# frozen_string_literal: true

require_relative "test_helper"
require "digest"

# Runs every applicable vector from the official PHP v1.2.0 fixture.
class VectorsTest < PikaidTest
  FIXTURE_CHECKSUMS = {
    "pikaid-v1.json" => "b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500",
    "pikaid-v1.schema.json" => "4441d4dbaa6c5450ae9cbfb2438c53bc0421bba2b7fcc9ef9b158e5d1de0759e"
  }.freeze

  def test_vendored_fixtures_match_the_recorded_checksums
    FIXTURE_CHECKSUMS.each do |name, expected|
      path = File.expand_path("vectors/#{name}", __dir__)
      assert_equal expected, Digest::SHA256.hexdigest(File.binread(path)), name
    end
  end

  def test_fixture_meta_matches_the_canonical_constants
    meta = VECTORS.fetch("meta")

    assert_equal "pikaid", meta["project"]
    assert_equal Pikaid::STRING_LENGTH, meta["string_length"]
    assert_equal "base36-lower", meta.dig("timestamp", "encoding")
    assert_equal Pikaid::TIMESTAMP_LENGTH, meta.dig("timestamp", "chars")
    assert_equal 0, meta.dig("timestamp", "min")
    assert_equal Pikaid::MAX_TIMESTAMP, meta.dig("timestamp", "max")
    assert_equal Pikaid::RANDOMNESS_BYTES, meta.dig("entropy", "bytes")
    assert_equal "base36-lower", meta.dig("entropy", "encoding")
    assert_equal Pikaid::RANDOMNESS_LENGTH, meta.dig("entropy", "chars")
    assert_equal Pikaid::BINARY_LENGTH, meta.dig("binary", "bytes")
    assert_equal "[5 bytes timestamp big-endian][12 bytes entropy]", meta.dig("binary", "layout")
    assert_equal "1.0.4", meta["spec_revision"]
    assert_equal "immutable and unversioned", meta["identifier_format"]
  end

  def test_every_official_valid_vector_decodes_and_reencodes
    VECTORS.fetch("valid").each do |vector|
      name = vector.fetch("name")
      binary = [vector.fetch("bin_hex")].pack("H*")

      assert_equal 26, vector.fetch("id").bytesize, name
      assert_equal 17, binary.bytesize, name
      assert_equal vector.fetch("id"), ReferencePikaid.id(
        vector.fetch("timestamp"), vector.fetch("entropy_hex")
      ), "#{name}: reference text encoding"
      assert_equal binary, ReferencePikaid.binary(
        vector.fetch("timestamp"), vector.fetch("entropy_hex")
      ), "#{name}: reference binary encoding"

      id = Pikaid.parse(vector.fetch("id"))
      assert_equal vector.fetch("timestamp"), id.timestamp, name
      assert_equal vector.fetch("entropy_hex"), id.randomness_hex, name
      assert_equal vector.fetch("entropy_hex"), id.randomness.unpack("H*")[0], name
      assert_equal 12, id.randomness.bytesize, name
      assert_equal vector.fetch("id"), id.to_s, name
      assert_equal binary, id.to_binary, name

      decoded = Pikaid.from_binary(binary)
      assert_equal id, decoded, name
      assert_equal vector.fetch("timestamp"), decoded.timestamp, name
      assert_equal vector.fetch("entropy_hex"), decoded.randomness_hex, name
      assert_equal vector.fetch("id"), decoded.to_s, name
      assert_equal binary, decoded.to_binary, name

      assert Pikaid.valid?(vector.fetch("id")), name
      assert Pikaid.well_formed?(vector.fetch("id")), name
      assert Pikaid.valid_binary?(binary), name
      assert_equal binary, Pikaid.to_binary(vector.fetch("id")), name
      assert_equal binary, Pikaid.to_binary(id), name
      assert_equal vector.fetch("timestamp"), Pikaid.timestamp(vector.fetch("id")), name
      assert_equal vector.fetch("entropy_hex"), Pikaid.randomness(vector.fetch("id")).unpack("H*")[0], name
      assert_equal vector.fetch("entropy_hex"), Pikaid.entropy(id).unpack("H*")[0], name
      assert_equal [vector.fetch("timestamp"), id.randomness], Pikaid.decode(vector.fetch("id")), name
      assert_equal 0, Pikaid.compare(vector.fetch("id"), id), name
      assert_equal vector.fetch("id"), Pikaid.from_binary(binary).to_s, name
    end
  end

  def test_every_official_invalid_string_is_rejected
    VECTORS.fetch("invalid").fetch("string").each do |vector|
      name = vector.fetch("name")

      refute Pikaid.valid?(vector.fetch("id")), name
      error = assert_raises(Pikaid::InvalidIdError, name) do
        Pikaid.parse(vector.fetch("id"))
      end
      refute_empty error.message, name

      expected_shape = name == "entropy-overflow"
      assert_equal expected_shape, Pikaid.well_formed?(vector.fetch("id")),
                   "#{name}: shape-only result"
    end
  end

  def test_every_official_invalid_binary_is_rejected
    VECTORS.fetch("invalid").fetch("binary").each do |vector|
      name = vector.fetch("name")
      binary = [vector.fetch("bin_hex")].pack("H*")

      refute Pikaid.valid_binary?(binary), name
      error = assert_raises(Pikaid::InvalidIdError, name) do
        Pikaid.from_binary(binary)
      end

      expected_reason = name.start_with?("timestamp-overflow") ? :timestamp_overflow : :invalid_binary_length
      assert_equal expected_reason, error.reason, name
    end
  end

  def test_fixture_structure_satisfies_the_published_schema_constraints
    schema = JSON.parse(
      File.read(File.expand_path("vectors/pikaid-v1.schema.json", __dir__))
    )

    assert_equal %w[meta valid invalid], schema.fetch("required")
    assert_equal schema.fetch("required").sort, VECTORS.keys.sort

    valid_required = schema.dig("properties", "valid", "items", "required")
    VECTORS.fetch("valid").each do |vector|
      assert_equal valid_required.sort, vector.keys.sort
      assert_kind_of Integer, vector.fetch("timestamp")
      assert_operator vector.fetch("timestamp"), :>=, 0
      assert_match(/\A[0-9a-f]{24}\z/, vector.fetch("entropy_hex"))
      assert_match(/\A[0-9a-z]{26}\z/, vector.fetch("id"))
      assert_match(/\A[0-9a-f]{34}\z/, vector.fetch("bin_hex"))
    end

    string_required = schema.dig("properties", "invalid", "properties", "string", "items", "required")
    VECTORS.dig("invalid", "string").each do |vector|
      assert_equal string_required.sort, vector.keys.sort
      assert_kind_of String, vector.fetch("id")
    end

    binary_required = schema.dig("properties", "invalid", "properties", "binary", "items", "required")
    VECTORS.dig("invalid", "binary").each do |vector|
      assert_equal binary_required.sort, vector.keys.sort
      assert_match(/\A([0-9a-f]{2})*\z/, vector.fetch("bin_hex"))
    end
  end
end
