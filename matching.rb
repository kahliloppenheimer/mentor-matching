# typed: strict
require 'sorbet-runtime'
require './csv_parser'

# Example matching class!
class Matching
  extend T::Sig

  sig {params(csv_path: String).void}
  def self.match(csv_path)
    people = CsvParser.parse(csv_path)
    puts("\nPeople:\n#{people.map(&:serialize).join("\n")}")
  end

end

Matching.match('test-inputs.csv')
