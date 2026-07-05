# typed: strict
require 'sorbet-runtime'
require 'csv'
require 'set'

# Parses a CSV of previous-year matches into a set of pair-keys, used to stop
# the same mentor/mentee pairing from repeating in a later year's match.
#
# Expects the same columns this program's own match export produces:
# `mentor_email` and `mentee_email` (any other columns, e.g. names, are ignored).
class PreviousMatches
  extend T::Sig

  MentorEmailCol = 'mentor_email'
  MenteeEmailCol = 'mentee_email'

  # Order-independent: a pairing is excluded regardless of which person is the
  # mentor vs. mentee this year.
  sig { params(mentor_email: String, mentee_email: String).returns(String) }
  def self.pair_key(mentor_email, mentee_email)
    [mentor_email.downcase.strip, mentee_email.downcase.strip].sort.join('|')
  end

  sig { params(csv_path: String).returns(T::Set[String]) }
  def self.parse(csv_path)
    rows = T.let(CSV.read(csv_path), T::Array[T::Array[T.nilable(String)]])
    headers = T.must(rows[0]).map { |h| h&.downcase&.strip }

    schema = T.let({}, T::Hash[String, Integer])
    [MentorEmailCol, MenteeEmailCol].each do |col|
      index = headers.index(col)
      if index.nil?
        raise "Previous matches CSV is missing a `#{col}` column. Expected headers: #{MentorEmailCol}, #{MenteeEmailCol}."
      end
      schema[col] = index
    end

    T.must(rows[1..]).reject { |row| row.all?(&:nil?) }.map do |row|
      pair_key(T.must(row[schema.fetch(MentorEmailCol)]), T.must(row[schema.fetch(MenteeEmailCol)]))
    end.to_set
  end
end
