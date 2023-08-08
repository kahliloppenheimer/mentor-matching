# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser'
require './lib/preferences'

class Matching
  extend T::Sig

  sig {params(csv_path: String).void}
  def self.match(csv_path)
    people = CsvParser.parse(csv_path)

    mentees_to_preferences = Preferences.compute_mentee_to_mentor_preferences(people).reject {|person, preferences| preferences.empty?}
    mentors_to_preferences = Preferences.compute_mentor_to_mentee_preferences(people).reject {|person, preferences| preferences.empty?}

    puts("Mentees:\n#{mentees_to_preferences}")
    puts("Mentors:\n#{mentors_to_preferences}")

    mentees_to_mentors = gale_shapley(proposers: mentees_to_preferences, acceptors: mentors_to_preferences)

    puts("Mentees -> Mentors:\n", mentees_to_mentors)
  end

  # Takes input proposers and accepters as hash from IDs -> List of IDs in order of preference (descending)
  # and performs a basic Gale Shapley stable matching algorithm.
  #
  # Returns Hash mapping proposers -> acceptors.
  sig do
    params(
      proposers: T::Hash[String, T::Array[String]],
      acceptors: T::Hash[String, T::Array[String]]
    ).returns(T::Hash[String, String])
  end
  private_class_method def self.gale_shapley(
    proposers:,
    acceptors:
  )
    proposers = proposers.dup
    acceptors = acceptors.dup

    matches = T.let({}, T::Hash[String, String])

    proposer = T.let(pick_next_proposer(proposers: proposers, matches: matches), T.nilable(String))

    # While we have an active proposer with options, we continue.
    while !proposer.nil?

      top_choice = get_and_remove_top_choice(proposer, proposers)

      existing_match = matches[top_choice]
      if existing_match.nil?
        matches[top_choice] = proposer
      else
        if prefers?(acceptor: top_choice, proposer1: proposer, proposer2: existing_match, acceptors: acceptors)
          matches[top_choice] = proposer
        end
      end

      proposer = pick_next_proposer(proposers: proposers, matches: matches)
    end

    matches
  end

  sig do
    params(
      proposers: T::Hash[String, T::Array[String]],
      matches: T::Hash[String, String]
    ).returns(T.nilable(String))
  end
  private_class_method def self.pick_next_proposer(proposers:, matches:)
    with_choices = proposers
      # only select proposers who have potential acceptors left.
      .select {|proposer, choices| !choices.empty?}
      # only select proposers who haven't already been matched.
      .select {|proposer, _| !matches.values.include?(proposer)}

    with_choices.keys.first
  end

  sig do
    params(
      proposer: String,
      proposers: T::Hash[String, T::Array[String]]
    ).returns(String)
  end
  private_class_method def self.get_and_remove_top_choice(proposer, proposers)
    T.must(proposers.fetch(proposer).shift)
  end

  sig do
    params(
      acceptor: String,
      proposer1: String,
      proposer2: String,
      acceptors: T::Hash[String, T::Array[String]]
    ).returns(T::Boolean)
  end
  private_class_method def self.prefers?(acceptor:, proposer1:, proposer2:, acceptors:)
    preferences = acceptors.fetch(acceptor)
    proposer1_preference = preferences.index(proposer1) || -1
    proposer2_preference = preferences.index(proposer2) || -1
    proposer1_preference < proposer2_preference
  end

end

Matching.match('test-inputs.csv')
