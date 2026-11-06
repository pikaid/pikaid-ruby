# frozen_string_literal: true

require_relative "test_helper"

class GenerationTest < PikaidTest
  ZERO_ENTROPY = ("\x00".b * 12)

  def test_generate_with_zero_timestamp_and_zero_entropy
    with_random_bytes(ZERO_ENTROPY) do
      assert_equal "00000000000000000000000000", Pikaid.generate(timestamp: 0)
    end
  end

  def test_generate_with_timestamp_one_and_entropy_one
    with_random_bytes(("\x00".b * 11) + "\x01") do
      assert_equal "00000010000000000000000001", Pikaid.generate(timestamp: 1)
    end
  end

  def test_generate_with_sample_timestamp_and_entropy
    entropy = ["00112233445566778899aabb"].pack("H*")
    with_random_bytes(entropy) do
      assert_equal "0s44we8002loz3po6mcf6vsn23", Pikaid.generate(timestamp: 1_700_000_000)
    end
  end

  def test_generate_at_maximum_timestamp_and_entropy
    with_random_bytes("\xff".b * 12) do
      assert_equal "zzzzzzz7oiylpimjg5u2ca1ypr",
                   Pikaid.generate(timestamp: Pikaid::MAX_TIMESTAMP)
    end
  end

  def test_generate_binary_matches_the_text_representation
    entropy = ["00112233445566778899aabb"].pack("H*")
    with_random_bytes(entropy) do
      binary = Pikaid.generate_binary(timestamp: 1_700_000_000)

      assert_equal 17, binary.bytesize
      assert_equal "006553f10000112233445566778899aabb", binary.unpack("H*")[0]
      assert_equal "0s44we8002loz3po6mcf6vsn23", Pikaid.from_binary(binary).to_s
    end
  end

  def test_generate_binary_at_boundaries
    with_random_bytes(ZERO_ENTROPY) do
      assert_equal "0000000000000000000000000000000000",
                   Pikaid.generate_binary(timestamp: 0).unpack("H*")[0]
    end

    with_random_bytes("\xff".b * 12) do
      assert_equal "123ede3fffffffffffffffffffffffffff",
                   Pikaid.generate_binary(timestamp: Pikaid::MAX_TIMESTAMP).unpack("H*")[0]
    end
  end

  def test_default_timestamp_uses_current_whole_seconds
    Time.stub(:now, Time.at(1_700_000_000)) do
      with_random_bytes(ZERO_ENTROPY) do
        assert_equal "0s44we80000000000000000000", Pikaid.generate
        assert_equal "006553f100000000000000000000000000",
                     Pikaid.generate_binary.unpack("H*")[0]
      end
    end
  end

  def test_generated_identifier_has_a_current_timestamp
    before = Time.now.to_i
    id = Pikaid.generate
    after = Time.now.to_i

    assert_operator Pikaid.timestamp(id), :>=, before
    assert_operator Pikaid.timestamp(id), :<=, after
    assert Pikaid.valid?(id)
    assert_equal 12, Pikaid.randomness(id).bytesize
  end

  def test_generated_identifiers_are_valid_and_distinct_within_one_second
    ids = Array.new(200) { Pikaid.generate(timestamp: 1_700_000_000) }

    assert_equal 200, ids.uniq.length
    ids.each do |id|
      assert_equal 26, id.bytesize
      assert_match(/\A[0-9a-z]{26}\z/, id)
      assert_equal 1_700_000_000, Pikaid.timestamp(id)
      assert_equal 12, Pikaid.randomness(id).bytesize
    end
  end

  def test_randomness_leading_zeroes_are_preserved
    entropy = ("\x00".b * 11) + "\x2a"
    with_random_bytes(entropy) do
      id = Pikaid.generate(timestamp: 0)

      assert_equal "00000000000000000000000016", id
      assert_equal "00000000000000000000002a", Pikaid.randomness(id).unpack("H*")[0]
    end
  end

  def test_invalid_timestamps_are_rejected_before_entropy_is_requested
    invalid = [-1, Pikaid::MAX_TIMESTAMP + 1, 1.0, "1", :one, true, Object.new]

    invalid.each do |timestamp|
      calls = 0
      SecureRandom.stub(:random_bytes, ->(_count) { calls += 1; ZERO_ENTROPY }) do
        error = assert_raises(Pikaid::InvalidTimestampError, timestamp.inspect) do
          Pikaid.generate(timestamp: timestamp)
        end
        refute_nil error.reason
      end
      assert_equal 0, calls, timestamp.inspect
    end
  end

  def test_timestamp_error_reasons
    error = assert_raises(Pikaid::InvalidTimestampError) { Pikaid.generate(timestamp: -1) }
    assert_equal :negative, error.reason
    assert_equal(-1, error.timestamp)

    error = assert_raises(Pikaid::InvalidTimestampError) do
      Pikaid.generate(timestamp: Pikaid::MAX_TIMESTAMP + 1)
    end
    assert_equal :overflow, error.reason

    error = assert_raises(Pikaid::InvalidTimestampError) { Pikaid.generate(timestamp: 1.5) }
    assert_equal :not_an_integer, error.reason

    error = assert_raises(Pikaid::InvalidTimestampError) do
      Pikaid.generate_binary(timestamp: -1)
    end
    assert_equal :negative, error.reason
  end

  def test_secure_random_failure_fails_closed_without_retry
    calls = 0
    failing = lambda do |_count|
      calls += 1
      raise "CSPRNG offline"
    end

    SecureRandom.stub(:random_bytes, failing) do
      error = assert_raises(Pikaid::RandomnessError) { Pikaid.generate }
      assert_match(/CSPRNG offline/, error.message)
      assert_kind_of RuntimeError, error.cause
    end

    assert_equal 1, calls
  end

  def test_binary_generation_also_fails_closed
    SecureRandom.stub(:random_bytes, ->(_count) { raise "no entropy" }) do
      assert_raises(Pikaid::RandomnessError) { Pikaid.generate_binary }
    end
  end

  def test_security_error_from_the_crypto_source_is_wrapped
    SecureRandom.stub(:random_bytes, ->(_count) { raise SecurityError, "blocked" }) do
      error = assert_raises(Pikaid::RandomnessError) { Pikaid.generate }
      assert_match(/SecurityError: blocked/, error.message)
    end
  end

  def test_wrong_entropy_size_or_type_is_rejected
    [nil, 12, "", "\x00".b * 11, "\x00".b * 13].each do |entropy|
      SecureRandom.stub(:random_bytes, entropy) do
        error = assert_raises(Pikaid::RandomnessError, entropy.inspect) { Pikaid.generate }
        assert_match(/instead of 12 bytes/, error.message)
      end
    end
  end

  def test_generated_text_is_ascii_only
    id = Pikaid.generate
    assert id.ascii_only?, id.inspect
    assert_equal id.bytesize, id.length
  end
end
