# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser_2025'
require './lib/matching'

csv_file_path = T.let(ARGV[0], T.nilable(String))

if csv_file_path.nil? || csv_file_path.empty?
  raise "Please pass in a CSV file path as input"
end

people = CsvParser2025.parse(csv_file_path)

puts("Num mentors: #{people.select(&:is_mentor).size}")
puts("Num mentees: #{people.select(&:is_mentee).size}")

Matching.match(people)