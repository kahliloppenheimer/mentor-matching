# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser'
require './lib/preferences'

class Matching
  extend T::Sig

  sig {params(people: T::Array[Person]).void}
  def self.match(people)
    mentees_to_preferences = Preferences.compute_mentee_to_mentor_preferences(people).reject {|person, preferences| preferences.empty?}
    mentors_to_preferences = Preferences.compute_mentor_to_mentee_preferences(people).reject {|person, preferences| preferences.empty?}

    mentors_to_mentees = gale_shapley(proposers: mentees_to_preferences, acceptors: mentors_to_preferences)

    mentees = mentees_to_preferences.select {|_, preferences| !preferences.empty?}.keys
    mentors = mentors_to_preferences.select {|_, preferences| !preferences.empty?}.keys

    puts("\n\n")
    puts("*************RESULTS*************\n\n")

    compute_match_statistics(
      mentees: mentees, 
      mentees_to_preferences: mentees_to_preferences, 
      mentors: mentors, 
      mentors_to_preferences: mentors_to_preferences, 
      mentors_to_mentees: mentors_to_mentees
    )
    puts()

    puts("Mentors -> Mentees:\n\n", mentors_to_mentees.sort.map{|mentor, mentee| "#{mentor},#{mentee}"}.join("\n"))
  end

  sig do
    params(
      mentees: T::Array[String],
      mentees_to_preferences: T::Hash[String, T::Array[String]],
      mentors: T::Array[String],
      mentors_to_preferences: T::Hash[String, T::Array[String]],
      mentors_to_mentees: T::Hash[String, String]
    ).void
  end
  private_class_method def self.compute_match_statistics(
    mentees:, 
    mentees_to_preferences:, 
    mentors:, 
    mentors_to_preferences:, 
    mentors_to_mentees:
  )
    matched_mentees = mentors_to_mentees.values.uniq
    matched_mentors = mentors_to_mentees.keys.uniq

    matched_mentee_count = mentees.select {|mentee| matched_mentees.include?(mentee)}.uniq.size
    matched_mentor_count = mentors.select {|mentor| matched_mentors.include?(mentor)}.uniq.size

    mentee_match_percent = (matched_mentee_count * 100.0 / mentees.uniq.size)
    mentor_match_percent = (matched_mentor_count * 100.0 / mentors.uniq.size)

    mentees_to_mentors = mentors_to_mentees.invert

    mentees_to_ranked_results = matched_mentees.map do |mentee|
      mentor = mentees_to_mentors.fetch(mentee)
      mentee_preferences = mentees_to_preferences.fetch(mentee)
      # Use 1-based indexing to represent first pick is 1
      mentor_rank = T.must(mentee_preferences.find_index(mentor)) + 1
      [mentee, mentor_rank]
    end.to_h

    puts("Mentees to ranked results:")
    mentees_to_ranked_results.values.sort

    puts("# matched mentees: #{matched_mentee_count}")
    puts("# eligible mentees: #{mentees.size}")
    puts("% mentee match: #{mentee_match_percent}%")
    unmatched_mentees = mentees.reject {|mentee| matched_mentees.include?(mentee)}
    puts("\nUnmatched mentees (#{unmatched_mentees.size}): #{unmatched_mentees}\n\n")

    puts("# matched mentors: #{matched_mentor_count}")
    puts ("# eligible mentors: #{mentors.size}")
    puts("% mentor match: #{mentor_match_percent}%")
    unmatched_mentors = mentors.reject {|mentor| matched_mentors.include?(mentor)}
    puts("\nUnmatched mentors (#{unmatched_mentors.size}): #{unmatched_mentors}\n\n")


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
    proposers = T.cast(Marshal.load(Marshal.dump(proposers)), T::Hash[String, T::Array[String]])
    acceptors = T.cast(Marshal.load(Marshal.dump(acceptors)), T::Hash[String, T::Array[String]])

    # Filter out any rankings of proposers/acceptors who did not reciprocally rank the acceptor/proposer.
    proposers = proposers.map {|proposer, preferences| [proposer, preferences.select {|acceptor| acceptors.fetch(acceptor).include?(proposer)}]}.to_h
    acceptors = acceptors.map {|acceptor, preferences| [acceptor, preferences.select {|proposer| proposers.fetch(proposer).include?(acceptor)}]}.to_h

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
