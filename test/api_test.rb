# frozen_string_literal: true

require_relative "test_helper"

# Public API surface, value-object semantics, and documented error behaviour.
class ApiTest < PikaidTest
  def test_constants_describe_the_wire_format
    assert_equal 26, Pikaid::STRING_LENGTH
    assert_equal 17, Pikaid::BINARY_LENGTH
    assert_equal 7, Pikaid::TIMESTAMP_LENGTH
    assert_equal 19, Pikaid::RANDOMNESS_LENGTH
    assert_equal 5, Pikaid::TIMESTAMP_BYTES
    assert_equal 12, Pikaid::RANDOMNESS_BYTES
    assert_equal 78_364_164_095, Pikaid::MAX_TIMESTAMP
    assert_equal((2**96) - 1, Pikaid::MAX_RANDOMNESS)
    assert_equal "0123456789abcdefghijklmnopqrstuvwxyz", Pikaid::ALPHABET
    assert_equal 7, Pikaid::MAX_TIMESTAMP.to_s(36).length
  end

  def test_module_methods_exist_with_the_documented_arity
    %i[
      generate generate_binary parse from_binary valid? valid_binary?
      well_formed? timestamp randomness entropy decode to_binary compare
    ].each do |name|
      assert_respond_to Pikaid, name, name.to_s
    end

    assert_equal(-1, Pikaid.method(:generate).arity)
    assert_equal(-1, Pikaid.method(:generate_binary).arity)
    assert_equal [[:key, :timestamp]], Pikaid.method(:generate).parameters
    assert_equal [[:key, :timestamp]], Pikaid.method(:generate_binary).parameters
    assert_equal 1, Pikaid.method(:parse).arity
    assert_equal 1, Pikaid.method(:from_binary).arity
    assert_equal 1, Pikaid.method(:valid?).arity
    assert_equal 1, Pikaid.method(:valid_binary?).arity
    assert_equal 1, Pikaid.method(:well_formed?).arity
    assert_equal 1, Pikaid.method(:timestamp).arity
    assert_equal 1, Pikaid.method(:randomness).arity
    assert_equal 1, Pikaid.method(:entropy).arity
    assert_equal 1, Pikaid.method(:decode).arity
    assert_equal 1, Pikaid.method(:to_binary).arity
    assert_equal 2, Pikaid.method(:compare).arity
  end

  def test_generate_supports_keyword_and_default_timestamps
    entropy = [("00" * 11) + "01"].pack("H*")

    with_random_bytes(entropy) do
      assert_equal "00000010000000000000000001", Pikaid.generate(timestamp: 1)
    end

    Time.stub(:now, Time.at(1)) do
      with_random_bytes(entropy) do
        assert_equal "00000010000000000000000001", Pikaid.generate
      end
    end

    assert_raises(ArgumentError) { Pikaid.generate(1) }
  end

  def test_id_value_object_is_immutable
    id = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")

    assert id.frozen?
    assert id.to_s.frozen?
    assert id.to_binary.frozen?
    assert id.randomness.frozen?

    assert_raises(FrozenError) { id.to_s << "0" }
    assert_raises(FrozenError) { id.to_binary << "\x00" }
    assert_raises(FrozenError) { id.randomness << "\x00" }
  end

  def test_value_equality_hash_and_use_as_hash_key
    text = "0s44we8002loz3po6mcf6vsn23"
    parsed = Pikaid.parse(text)
    binary = Pikaid.from_binary(Pikaid.to_binary(text))
    regenerated = Pikaid::Id.new(parsed.timestamp, parsed.randomness)

    [binary, regenerated].each do |other|
      assert_equal parsed, other
      assert other == parsed
      assert parsed.eql?(other)
      assert_equal parsed.hash, other.hash
    end

    refute_equal parsed, Pikaid.parse("00000000000000000000000000")
    refute_equal parsed, text
    refute_equal parsed, nil
    refute parsed.eql?(text)

    table = { parsed => :found }
    assert_equal :found, table[binary]
    assert_equal :found, table[regenerated]
  end

  def test_hash_contract_holds_for_subclasses
    text = "0s44we8002loz3po6mcf6vsn23"
    parsed = Pikaid.parse(text)
    subclass = Class.new(Pikaid::Id)
    subclassed = subclass.new(parsed.timestamp, parsed.randomness)

    assert_equal parsed, subclassed
    assert parsed.eql?(subclassed)
    assert_equal parsed.hash, subclassed.hash

    table = { parsed => :found }
    assert_equal :found, table[subclassed]
  end

  def test_inspect_is_compact_and_unambiguous
    id = Pikaid.parse("00000000000000000000000000")

    assert_equal '#<Pikaid::Id "00000000000000000000000000">', id.inspect
  end

  def test_decode_returns_fresh_randomness_strings
    text = "0s44we8002loz3po6mcf6vsn23"
    timestamp, randomness = Pikaid.decode(text)

    assert_equal 1_700_000_000, timestamp
    assert_equal "00112233445566778899aabb", randomness.unpack("H*")[0]
    assert_equal randomness, Pikaid.randomness(text)
    assert_equal randomness, Pikaid.entropy(text)
  end

  def test_module_helpers_accept_ids_and_text_interchangeably
    text = "0s44we8002loz3po6mcf6vsn23"
    id = Pikaid.parse(text)
    binary = Pikaid.to_binary(id)

    [text, id].each do |value|
      assert_equal 1_700_000_000, Pikaid.timestamp(value)
      assert_equal "00112233445566778899aabb", Pikaid.randomness(value).unpack("H*")[0]
      assert_equal binary, Pikaid.to_binary(value)
      assert_equal [1_700_000_000, Pikaid.randomness(value)], Pikaid.decode(value)
      assert_equal 0, Pikaid.compare(value, text)
    end
  end

  def test_validation_predicates_return_false_instead_of_raising
    [nil, 1, :id, Object.new, "", "x" * 25, "X" * 26].each do |value|
      assert_equal false, Pikaid.valid?(value)
      assert_equal false, Pikaid.well_formed?(value)
    end

    [nil, 1, :binary, Object.new, "", "\x00" * 16, "\x00" * 18].each do |value|
      assert_equal false, Pikaid.valid_binary?(value)
    end
  end

  def test_helpers_raise_clear_errors_for_invalid_input
    [
      -> { Pikaid.timestamp("nope") },
      -> { Pikaid.randomness("nope") },
      -> { Pikaid.entropy("nope") },
      -> { Pikaid.decode("nope") },
      -> { Pikaid.to_binary("nope") },
      -> { Pikaid.compare("nope", "00000000000000000000000000") },
      -> { Pikaid.compare("00000000000000000000000000", "nope") },
      -> { Pikaid.timestamp(Object.new) }
    ].each do |call|
      error = assert_raises(Pikaid::InvalidIdError, &call)
      assert error.reason
      refute_empty error.message
    end
  end

  def test_version_is_a_pre_release_string
    assert_match(/\A\d+\.\d+\.\d+\z/, Pikaid::VERSION)
    assert_equal "0.1.0", Pikaid::VERSION
  end
end
