# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser_2025'
require './lib/matching'
require './lib/previous_matches'
require 'set'

csv_file_path = T.let(ARGV[0], T.nilable(String))
previous_matches_csv_path = T.let(ARGV[1], T.nilable(String))

if csv_file_path.nil? || csv_file_path.empty?
  raise "Please pass in a CSV file path as input"
end

people = CsvParser2025.parse(csv_file_path)

previously_matched = T.let(Set.new, T::Set[String])
if !previous_matches_csv_path.nil? && !previous_matches_csv_path.empty?
  previously_matched = PreviousMatches.parse(previous_matches_csv_path)
end

Matching.match(people, previously_matched: previously_matched)