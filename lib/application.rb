# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser'
require './lib/matching'

csv_file_path = T.let(ARGV[0], T.nilable(String))

if csv_file_path.nil? || csv_file_path.empty?
  raise "Please pass in a CSV file path as input"
end


csv = CsvParser.parse(csv_file_path)
Matching.match(csv)