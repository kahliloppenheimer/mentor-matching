# typed: strict
require 'sorbet-runtime'
require './csv_parser'
require './preferences'

# Example matching class!
class Matching
  extend T::Sig

  sig {params(csv_path: String).void}
  def self.match(csv_path)
    people = CsvParser.parse(csv_path)
    mentee_to_mentor_preferences = Preferences.compute_mentee_to_mentor_preferences(people)
    mentor_to_mentee_preferences = Preferences.compute_mentor_to_mentee_preferences(people)

    puts("\nMentee -> Mentor (preferences):\n#{mentee_to_mentor_preferences.map {|mentee, mentors| "#{mentee.name} -> #{mentors.map(&:name)}"}.join("\n")}")
    puts("\nMentor -> Mentee (preferences):\n#{mentor_to_mentee_preferences.map {|mentor, mentees| "#{mentor.name} -> #{mentees.map(&:name)}"}.join("\n")}")
  end

end

Matching.match('test-inputs.csv')
