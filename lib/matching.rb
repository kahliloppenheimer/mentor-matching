# typed: strict
require 'sorbet-runtime'
require './lib/csv_parser'
require './lib/preferences'
require 'descriptive_statistics'


class Matching
  extend T::Sig

  sig {params(person: Person2025).returns(T::Array[Person2025])}
  def self.multiplicity(person)
    if person.max_num_mentees <= 1
      return [person]
    end

    return (1..person.max_num_mentees).map{|i| person.with(id: "#{person.id}#{i}")}
  end

  sig {params(people: T::Array[Person2025]).void}
  def self.match(people)

    # To handle one mentor with multiple mentees, we create one Person object
    # per relationship of them matching (e.g. 3 mentees means 3 person objects)
    mentors = people.select(&:is_mentor).flat_map{|person| multiplicity(person)}
    mentees = people.select(&:is_mentee)

    mentees_to_preferences = Preferences.compute_mentee_to_mentor_preferences(mentees: mentees, mentors: mentors)
    mentees_with_no_preferences = mentees_to_preferences.select {|_, preferences| preferences.empty?}.keys
    if !mentees_with_no_preferences.empty?
      puts "Filtering out #{mentees_with_no_preferences.size} mentees with no preferences:\n#{mentees_with_no_preferences}"
      mentees_to_preferences = mentees_to_preferences.reject {|_, preferences| preferences.empty?}
    end
    puts "Num mentees: #{people.select(&:is_mentee).group_by(&:email).keys.size}"

    mentors_to_preferences = Preferences.compute_mentor_to_mentee_preferences(mentees: mentees, mentors: mentors)
    mentors_with_no_preferences = mentors_to_preferences.select {|_, preferences| preferences.empty?}.keys
    if !mentors_with_no_preferences.empty?
      puts "Filtering out #{mentors_with_no_preferences.size} mentors with no preferences:\n"
      mentors_to_preferences = mentors_to_preferences.reject {|_, preferences| preferences.empty?}
    end
    puts "Num mentors: #{people.select(&:is_mentor).group_by(&:email).keys.size}"
    puts "Num mentor slots (accounting for multiple mentees per mentor): #{mentors_to_preferences.keys.size}"

    matched_mentors_to_mentees = gale_shapley(proposers: mentees_to_preferences, acceptors: mentors_to_preferences)

    puts("\n\n")
    puts("*************RESULTS*************\n\n")

    compute_match_statistics(
      matched_mentors_to_mentees: matched_mentors_to_mentees,
      mentees: people.select(&:is_mentee), 
      mentors: mentors.select(&:is_mentor), 
      mentees_to_preferences: mentees_to_preferences, 
      mentors_to_preferences: mentors_to_preferences, 
    )

    puts("Mentees -> Mentors:\n\n", matched_mentors_to_mentees.map{|mentor, mentee| "#{mentee.name};#{mentee.email};#{mentor.name};#{mentor.email}"}.sort.join("\n"))
  end

  sig do
    params(
      matched_mentors_to_mentees: T::Hash[Person2025, Person2025],
      mentees: T::Array[Person2025],
      mentees_to_preferences: T::Hash[Person2025, T::Array[Person2025]],
      mentors: T::Array[Person2025],
      mentors_to_preferences: T::Hash[Person2025, T::Array[Person2025]],
    ).void
  end
  private_class_method def self.compute_match_statistics(
    matched_mentors_to_mentees:,
    mentees:, 
    mentees_to_preferences:, 
    mentors:, 
    mentors_to_preferences: 
  )
    matched_mentees = matched_mentors_to_mentees.values.map(&:email).uniq
    matched_mentors = matched_mentors_to_mentees.keys.map(&:email).uniq

    unique_mentees = mentees.map(&:email).uniq
    unique_mentors = mentors.map(&:email).uniq

    mentee_match_percent = (100.0 * matched_mentees.size / unique_mentees.size)
    mentor_match_percent = (100.0 * matched_mentors.size / unique_mentors.size)

    mentees_to_mentors = matched_mentors_to_mentees.invert

    mentees_to_ranked_results = mentees_to_mentors.map do |mentee, mentor|
      mentee_preferences = mentees_to_preferences.fetch(mentee)
      # Use 1-based indexing to represent first pick is 1
      mentor_rank = T.must(mentee_preferences.find_index(mentor)) + 1
      [mentee, mentor_rank]
    end.to_h

    mentors_to_ranked_results = matched_mentors_to_mentees.map do |mentor, mentee|
      mentor_preferences = mentors_to_preferences.fetch(mentor)
      # Use 1-based indexing to represent first pick is 1
      mentee_rank = T.must(mentor_preferences.find_index(mentee)) + 1
      [mentor, mentee_rank]
    end.to_h

    puts("Median mentee # possible mentors = #{DescriptiveStatistics.median(mentees_to_preferences.values.map(&:size))}")
    puts("Median mentee paired mentor rank (e.g. 4 means 4th best) = #{DescriptiveStatistics.median(mentees_to_ranked_results.values)}")
    puts


    puts("Median mentor # possible mentees = #{DescriptiveStatistics.median(mentors_to_preferences.values.map(&:size))}")
    puts("Median mentor paired match rank (e.g. 4 means 4th best) = #{DescriptiveStatistics.median(mentors_to_ranked_results.values)}")
    puts

    puts("# Mentor / Mentee pairs in same state = #{matched_mentors_to_mentees.select {|mentor, mentee| mentor.state == mentee.state}.size} / #{matched_mentors_to_mentees.size}")
    puts("Median seniority difference = #{DescriptiveStatistics.median(matched_mentors_to_mentees.map{|mentor, mentee| mentor.seniority - mentee.seniority})}")
    puts

    puts("# mentors preferring IMG = " \
      "#{mentors.select(&:prefers_mentoring_international).size}")
      
    puts("# IMG mentees = " \
      "#{mentees.select(&:is_international).size}")
    
    puts("# IMG mentees paired w/ mentors preferring IMG = " \
    "#{matched_mentors_to_mentees.select {|mentor, mentee| mentor.prefers_mentoring_international && mentee.is_international}.size}")
    puts

    puts("# matched mentees: #{matched_mentees.count}")
    puts("# eligible mentees: #{unique_mentees.size}")
    puts("% mentee match: #{mentee_match_percent}%")
    unmatched_mentees = mentees.reject {|mentee| matched_mentees.include?(mentee.email)}
    puts("\nUnmatched mentees (#{unmatched_mentees.size}): #{unmatched_mentees.map(&:email).sort}\n\n")

    puts("# matched mentors: #{matched_mentors.size}")
    puts ("# eligible mentors: #{unique_mentors.size}")
    puts("% mentor match: #{mentor_match_percent}%")
    unmatched_mentors = mentors.reject {|mentor| matched_mentors.include?(mentor.email)}.group_by(&:email).map(&:first)
    puts("\nUnmatched mentors (#{unmatched_mentors.size}): #{unmatched_mentors.sort}\n\n")
  end

  # Takes input proposers and accepters as hash from IDs -> List of IDs in order of preference (descending)
  # and performs a basic Gale Shapley stable matching algorithm.
  #
  # Returns Hash mapping proposers -> acceptors.
  sig do
    params(
      proposers: T::Hash[Person2025, T::Array[Person2025]],
      acceptors: T::Hash[Person2025, T::Array[Person2025]],
    ).returns(T::Hash[Person2025, Person2025])
  end
  private_class_method def self.gale_shapley(
    proposers:,
    acceptors:
  )
    proposers = T.cast(Marshal.load(Marshal.dump(proposers)), T::Hash[Person2025, T::Array[Person2025]])
    acceptors = T.cast(Marshal.load(Marshal.dump(acceptors)), T::Hash[Person2025, T::Array[Person2025]])

    # Filter out any rankings of proposers/acceptors who did not reciprocally rank the acceptor/proposer.
    proposers = proposers.map {|proposer, preferences| [proposer, preferences.select {|acceptor| acceptors.fetch(acceptor).include?(proposer)}]}.to_h
    acceptors = acceptors.map {|acceptor, preferences| [acceptor, preferences.select {|proposer| proposers.fetch(proposer).include?(acceptor)}]}.to_h

    matches = T.let({}, T::Hash[Person2025, Person2025])

    proposer = T.let(pick_next_proposer(proposers: proposers, matches: matches), T.nilable(Person2025))

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
      proposers: T::Hash[Person2025, T::Array[Person2025]],
      matches: T::Hash[Person2025, Person2025]
    ).returns(T.nilable(Person2025))
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
      proposer: Person2025,
      proposers: T::Hash[Person2025, T::Array[Person2025]]
    ).returns(Person2025)
  end
  private_class_method def self.get_and_remove_top_choice(proposer, proposers)
    T.must(proposers.fetch(proposer).shift)
  end

  sig do
    params(
      acceptor: Person2025,
      proposer1: Person2025,
      proposer2: Person2025,
      acceptors: T::Hash[Person2025, T::Array[Person2025]]
    ).returns(T::Boolean)
  end
  private_class_method def self.prefers?(acceptor:, proposer1:, proposer2:, acceptors:)
    preferences = acceptors.fetch(acceptor)
    proposer1_preference = preferences.index(proposer1) || -1
    proposer2_preference = preferences.index(proposer2) || -1
    proposer1_preference < proposer2_preference
  end

end
