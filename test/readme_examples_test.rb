# frozen_string_literal: true

require_relative "test_helper"

# Executes the concrete examples published in README.md so documentation cannot
# drift from behaviour without a test failure.
class ReadmeExamplesTest < PikaidTest
  def test_generation_examples
    id = Pikaid.generate

    assert_instance_of String, id
    assert_equal 26, id.bytesize
    assert Pikaid.valid?(id)
    assert_equal 26, Pikaid.generate(timestamp: 1_700_000_000).bytesize
    assert_equal 17, Pikaid.generate_binary(timestamp: 1_700_000_000).bytesize
  end

  def test_parse_and_decode_examples
    parsed = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")

    assert_equal 1_700_000_000, parsed.timestamp
    assert_equal ["00112233445566778899aabb"].pack("H*"), parsed.randomness
    assert_equal "00112233445566778899aabb", parsed.randomness_hex
    assert_equal parsed.randomness, parsed.entropy
    assert_equal "0s44we8002loz3po6mcf6vsn23", parsed.to_s
    assert_equal 17, parsed.to_binary.bytesize
    assert_equal "006553f10000112233445566778899aabb", parsed.to_binary.unpack("H*")[0]
    assert_equal parsed, Pikaid.from_binary(parsed.to_binary)
  end

  def test_validation_and_helper_examples
    parsed = Pikaid.parse("0s44we8002loz3po6mcf6vsn23")

    assert Pikaid.valid?("0s44we8002loz3po6mcf6vsn23")
    assert Pikaid.valid_binary?(parsed.to_binary)
    assert Pikaid.well_formed?("0000000zzzzzzzzzzzzzzzzzzz")
    refute Pikaid.valid?("0000000zzzzzzzzzzzzzzzzzzz")

    assert_equal 1_700_000_000, Pikaid.timestamp(parsed)
    assert_equal parsed.randomness, Pikaid.randomness("0s44we8002loz3po6mcf6vsn23")
    assert_equal [1_700_000_000, parsed.randomness], Pikaid.decode(parsed)
    assert_equal parsed.to_binary, Pikaid.to_binary(parsed)
    assert_equal 0, Pikaid.compare(parsed, parsed)
  end

  def test_error_example
    error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse("not-a-pikaid") }

    assert_equal :invalid_string_length, error.reason
    assert_equal "not-a-pikaid", error.value
  end
end
