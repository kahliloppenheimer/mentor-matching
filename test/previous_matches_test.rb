# typed: false
require 'minitest/autorun'
require 'tempfile'
require './lib/previous_matches'

class PreviousMatchesTest < Minitest::Test
  def test_pair_key_is_order_independent
    assert_equal(
      PreviousMatches.pair_key('a@example.com', 'b@example.com'),
      PreviousMatches.pair_key('b@example.com', 'a@example.com')
    )
  end

  def test_pair_key_normalizes_case_and_whitespace
    assert_equal(
      PreviousMatches.pair_key('A@Example.com', 'b@example.com'),
      PreviousMatches.pair_key(' a@example.com ', ' B@Example.COM ')
    )
  end

  def test_parse_builds_pair_keys_from_csv
    with_csv("mentor_email,mentee_email\nmentor@example.com,mentee@example.com\n") do |path|
      pairs = PreviousMatches.parse(path)
      assert_equal(1, pairs.size)
      assert(pairs.include?(PreviousMatches.pair_key('mentor@example.com', 'mentee@example.com')))
    end
  end

  def test_parse_raises_on_missing_column
    with_csv("mentor_email,other_col\nmentor@example.com,foo\n") do |path|
      assert_raises(RuntimeError) { PreviousMatches.parse(path) }
    end
  end

  private

  def with_csv(contents)
    file = Tempfile.new(['previous_matches', '.csv'])
    file.write(contents)
    file.close
    yield file.path
  ensure
    file&.unlink
  end
end
