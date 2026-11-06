# frozen_string_literal: true

require_relative "test_helper"

# Ordering guarantees: canonical bytewise order is chronological across
# different seconds, and within one second follows randomness (never
# generation order).
class OrderingTest < PikaidTest
  def test_text_order_is_lexicographic_ascii
    ordered = %w[
      00000000000000000000000000
      00000000000000000000000001
      0000000000000000000000000z
      00000000000000000000000010
      000000000000000000000000z0
      00000010000000000000000000
      00000017oiylpimjg5u2ca1ypr
      000000z0000000000000000000
      0s44we8002loz3po6mcf6vsn23
      zzzzzzz7oiylpimjg5u2ca1ypr
    ]

    assert_equal ordered, ordered.sort
    ordered.each_cons(2) do |left, right|
      assert_operator left, :<, right
      assert_operator Pikaid.compare(left, right), :<, 0
      assert_operator Pikaid.compare(right, left), :>, 0
      assert_equal 0, Pikaid.compare(left, left)
    end
  end

  def test_binary_order_matches_text_order
    text_ids = [
      "00000000000000000000000000",
      "00000000000000000000000001",
      "000000z0000000000000000000",
      "0s44we8002loz3po6mcf6vsn23",
      "zzzzzzz7oiylpimjg5u2ca1ypr"
    ]

    binaries = text_ids.map { |id| Pikaid.to_binary(id) }
    assert_equal binaries, binaries.sort
    assert_equal text_ids.sort, binaries.map { |binary| Pikaid.from_binary(binary).to_s }

    text_ids.each_with_index do |left, left_index|
      text_ids.each_with_index do |right, right_index|
        expected = left_index <=> right_index
        assert_equal expected, Pikaid.compare(left, right),
                     "#{left} vs #{right}: text order"
        assert_equal expected, (Pikaid.to_binary(left) <=> Pikaid.to_binary(right)),
                     "#{left} vs #{right}: binary order"
      end
    end
  end

  def test_different_seconds_sort_chronologically
    timestamps = [0, 1, 2, 35, 36, 1_000, 1_700_000_000, Pikaid::MAX_TIMESTAMP - 1, Pikaid::MAX_TIMESTAMP]
    entropy = [0xff].pack("C") * 12
    ids = timestamps.map { |timestamp| Pikaid::Id.new(timestamp, entropy) }

    assert_equal timestamps, ids.sort.map(&:timestamp)
    assert_equal ids, ids.sort
    ids.each_cons(2) do |earlier, later|
      assert_operator earlier.to_s, :<, later.to_s
      assert_operator earlier.to_binary, :<, later.to_binary
    end
  end

  def test_same_second_order_follows_randomness_not_generation_time
    # These two share a timestamp. If ordering tracked generation time, the
    # second one would sort last; instead it sorts by its random suffix.
    low = Pikaid::Id.new(1_700_000_000, ("\x00".b * 11) + "\x01")
    high = Pikaid::Id.new(1_700_000_000, ("\x00".b * 11) + "\xff")

    generated_in_this_order = [high, low]
    assert_equal [low, high], generated_in_this_order.sort
    refute_equal generated_in_this_order, generated_in_this_order.sort

    assert_operator Pikaid.compare(high, low), :>, 0
    assert_operator high.to_s, :>, low.to_s
    assert_operator high.to_binary, :>, low.to_binary
  end

  def test_generation_within_one_second_is_not_monotonic
    ids = Array.new(50) { Pikaid.generate(timestamp: 1_700_000_000) }

    assert_equal 50, ids.uniq.length
    refute_equal ids, ids.sort,
                 "50 random same-second identifiers must not coincidentally be sorted"
    assert_equal ids.sort, ids.sort
  end

  def test_comparable_value_object_behaviour
    earlier = Pikaid.parse("00000000000000000000000000")
    later = Pikaid.parse("00000000000000000000000001")

    assert earlier < later
    assert later > earlier
    assert earlier <= earlier
    assert earlier >= earlier
    assert_equal 1, (later <=> earlier)
    assert_equal 0, (earlier <=> earlier)
    assert_nil(earlier <=> "00000000000000000000000001")
    assert_nil(earlier <=> nil)
    assert_nil(earlier <=> Object.new)
  end
end
