# typed: strict
require 'sorbet-runtime'
require './lib/person'
require 'pry-byebug'

class Preferences

  extend T::Sig

  sig {params(mentees: T::Array[Person2025], mentors: T::Array[Person2025]).returns(T::Hash[Person2025, T::Array[Person2025]])} 
  def self.compute_mentor_to_mentee_preferences(mentees:, mentors:)
    preferences = T.let({}, T::Hash[Person2025, T::Array[Person2025]])

    if !mentees.all?(&:is_mentee)
      raise "Found non mentees!"
    end

    if !mentors.all?(&:is_mentor)
      raise "Found non mentors!"
    end

    mentors.each do |mentor|

      if !mentor.is_mentor
        puts "Filtering out non-mentor #{mentor.name}"
        preferences[mentor] = []
        next
      end

      potential_mentees = mentees
        # Only keep people who want to be mentees.
        .select {|other_person| other_person.is_mentee}
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentor == other_person}
        # Only keep potential mentees who are more junior.
        .select {|other_person| other_person.seniority < mentor.seniority}

      if potential_mentees.size == 0
        puts "Could not find any potential mentees for #{mentor.name}"
      end

      # Perform a cascading comparison where we sort based on adjacent seniority, city, state, then region
      # (in descending order of priority).
      preferred_mentees = potential_mentees.sort do |p1, p2|
        comparisons = [
          compare_international_preference_for_mentor(mentor: mentor, p1: p1, p2: p2),
          compare_mentee_seniority_allowlist(mentor: mentor, p1: p1, p2: p2),
          compare_preferring_target(target: mentor.state, a: p1.state, b: p2.state),
          compare_rank(target_rank: mentor.seniority, p1_rank: p1.seniority, p2_rank: p2.seniority),
        ]

        final_comparison = sort_by_comparison_list(comparisons)

        # We want to sort in descending order (aka most preferred mentor first).
        -1 * final_comparison
      end

      preferences[mentor] = preferred_mentees
    end

    preferences
  end

  sig {params(mentees: T::Array[Person2025], mentors: T::Array[Person2025]).returns(T::Hash[Person2025, T::Array[Person2025]])}
  def self.compute_mentee_to_mentor_preferences(mentees:, mentors:)
    preferences = T.let({}, T::Hash[Person2025, T::Array[Person2025]])

    if !mentees.all?(&:is_mentee)
      raise "Found non mentees!"
    end

    if !mentors.all?(&:is_mentor)
      raise "Found non mentors!"
    end

    mentees.each do |mentee|
      potential_mentors = mentors
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentee == other_person}
        # Only keep potential mentors who are more senior
        .select {|other_person| other_person.seniority > mentee.seniority}

      # Perform a cascading comparison where we sort (from most to least important):
      # - difference in seniority (prefer closeness)
      # - state (prefer closeness)
      preferred_mentors = potential_mentors.sort do |p1, p2|
        comparisons = [
          compare_international_preference_for_mentee(mentee: mentee, p1: p1, p2: p2),
          compare_preferring_target(target: mentee.state, a: p1.state, b: p2.state),
          compare_rank(target_rank: mentee.seniority, p1_rank: p1.seniority, p2_rank: p2.seniority),
        ]

        final_comparison = sort_by_comparison_list(comparisons)

        # We want to sort in descending order (aka most preferred mentor first).
        -1 * final_comparison
      end

      preferences[mentee] = preferred_mentors
    end

    preferences
  end

  # Performing a cascading comparison where we return the first non-zero value (aka
  # the tie-breaker), or 0 if there is none.
  sig {params(comparisons: T::Array[Integer]).returns(Integer)}
  private_class_method def self.sort_by_comparison_list(comparisons)
    comparisons.each_with_index do |comparison, idx|
      if comparison != 0
        return comparison
      end
    end
    0
  end

    sig do
    params(
      mentee: Person2025,
      p1: Person2025,
      p2: Person2025
    ).returns(Integer)
  end
  private_class_method def self.compare_international_preference_for_mentee(mentee:, p1:, p2:)
    if !mentee.is_international
      return 0
    end

    if p1.prefers_mentoring_international && !p2.prefers_mentoring_international
      return 1
    end

    if !p1.prefers_mentoring_international && p2.prefers_mentoring_international
      return -1
    end

    return 0
  end

  sig do
    params(
      mentor: Person2025,
      p1: Person2025,
      p2: Person2025
    ).returns(Integer)
  end
  private_class_method def self.compare_international_preference_for_mentor(mentor:, p1:, p2:)
    if !mentor.prefers_mentoring_international
      return 0
    end

    if p1.is_international && !p2.is_international
      return 1
    end

    if !p1.is_international && p2.is_international
      return -1
    end

    return 0

  end

  sig do
    params(
      target_rank: Integer,
      p1_rank: Integer,
      p2_rank: Integer
    ).returns(Integer)
  end
  private_class_method def self.compare_rank(target_rank:, p1_rank:, p2_rank:)
    p1_rank_difference = (p1_rank - target_rank).abs
    p2_rank_difference = (p2_rank - target_rank).abs
    
    # Reverse the comparison, since we prefer a lower rank difference (e.g. closer two ranks/seniorities).
    p2_rank_difference <=> p1_rank_difference
  end

  sig do
    params(
      mentee: Person,
      p1: Person,
      p2: Person
    ).returns(Integer)
  end
  private_class_method def self.compare_interests(mentee, p1, p2)
    mentee.interests.intersection(p1.interests.intersection).size <=> mentee.interests.intersection(p2.interests).size
  end

  sig do
    params(
      mentor: Person2025,
      p1: Person2025,
      p2: Person2025
    ).returns(Integer)
  end
  private_class_method def self.compare_mentee_seniority_allowlist(mentor:, p1:, p2:)
    allowlist = mentor.mentee_seniority_allowlist
    if allowlist.include?(p1.seniority) && !allowlist.include?(p2.seniority)
      return 1
    end

    if !allowlist.include?(p1.seniority) && allowlist.include?(p2.seniority)
      return -1
    end

    return 0
  end


  # Performs a comparison where
  #
  # Returns 1 if a == target and b != target
  # Returns -1 if a != target and b == target
  # Returns 0 otherwise
  sig do
    params(
      target: BasicObject,
      a: BasicObject,
      b: BasicObject
    ).returns(Integer)
  end
  private_class_method def self.compare_preferring_target(target:, a:, b:)
    if a == target && b != target
      return 1
    end

    if b == target && a != target
      return -1
    end

    0
  end
end