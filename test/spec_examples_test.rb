# frozen_string_literal: true

require_relative "test_helper"

# Known-answer cases transcribed independently from specification revision 1.0.4,
# section 7. These do not read the PHP fixture.
class SpecExamplesTest < PikaidTest
  CASES = [
    {
      id: "00000000000000000000000000",
      timestamp: 0,
      entropy_hex: "000000000000000000000000",
      binary_hex: "0000000000000000000000000000000000"
    },
    {
      id: "00000010000000000000000001",
      timestamp: 1,
      entropy_hex: "000000000000000000000001",
      binary_hex: "0000000001000000000000000000000001"
    },
    {
      id: "zzzzzzz7oiylpimjg5u2ca1ypr",
      timestamp: 78_364_164_095,
      entropy_hex: "ffffffffffffffffffffffff",
      binary_hex: "123ede3fffffffffffffffffffffffffff"
    }
  ].freeze

  def test_specification_examples_parse_to_exact_components
    CASES.each do |test_case|
      id = Pikaid.parse(test_case.fetch(:id))

      assert_equal test_case.fetch(:timestamp), id.timestamp
      assert_equal test_case.fetch(:entropy_hex), id.randomness_hex
      assert_equal test_case.fetch(:id), id.to_s
      assert_equal [test_case.fetch(:binary_hex)].pack("H*"), id.to_binary
      assert_equal id, Pikaid.from_binary([test_case.fetch(:binary_hex)].pack("H*"))
    end
  end

  def test_specification_invalid_randomness_example
    id = "0000000zzzzzzzzzzzzzzzzzzz"

    assert Pikaid.well_formed?(id)
    refute Pikaid.valid?(id)
    error = assert_raises(Pikaid::InvalidIdError) { Pikaid.parse(id) }
    assert_equal :randomness_overflow, error.reason
  end

  def test_40_bit_binary_timestamp_example_is_rejected
    binary = ["ffffffffff000000000000000000000000"].pack("H*")

    refute Pikaid.valid_binary?(binary)
    error = assert_raises(Pikaid::InvalidIdError) { Pikaid.from_binary(binary) }
    assert_equal :timestamp_overflow, error.reason
  end
end
