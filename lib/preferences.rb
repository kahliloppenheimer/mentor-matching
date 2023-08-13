# typed: strict
require 'sorbet-runtime'
require './lib/person'

class Preferences

  extend T::Sig

  sig {params(people: T::Array[Person]).returns(T::Hash[String, T::Array[String]])}
  def self.compute_mentor_to_mentee_preferences(people)
    preferences = T.let({}, T::Hash[String, T::Array[String]])
    people.each do |mentor|
      potential_mentees = people
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentor == other_person}
        # Only keep potential mentees who are more junior.
        .select {|other_person| other_person.rank - mentor.rank < 0}

      # Perform a cascading comparison where we sort based on adjacent seniority, city, state, then region
      # (in descending order of priority).
      preferred_mentees = potential_mentees.sort do |p1, p2|
        comparisons = [
          compare_rank(target_rank: mentor.rank, p1_rank: p1.rank, p2_rank: p2.rank),
          compare_preferring_target(target: mentor.city, a: p1.city, b: p2.city),
          compare_preferring_target(target: mentor.state, a: p1.state, b: p2.state),
          compare_preferring_target(target: mentor.region, a: p1.region, b: p2.region)
        ]

        final_comparison = sort_by_comparison_list(comparisons)

        # We want to sort in descending order (aka most preferred mentor first).
        -1 * final_comparison
      end

      preferences[mentor.name] = preferred_mentees.map(&:name)
    end

    preferences
  end

  sig {params(people: T::Array[Person]).returns(T::Hash[String, T::Array[String]])}
  def self.compute_mentee_to_mentor_preferences(people)
    preferences = T.let({}, T::Hash[String, T::Array[String]])
    people.each do |mentee|
      potential_mentors = people
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentee == other_person}
        # Only keep potential mentors who are more senior
        .select {|other_person| other_person.rank - mentee.rank > 0}

      # Perform a cascading comparison where we sort based on adjacent seniority, city, state, then region
      # (in descending order of priority).
      preferred_mentors = potential_mentors.sort do |p1, p2|
        comparisons = [
          compare_rank(target_rank: mentee.rank, p1_rank: p1.rank, p2_rank: p2.rank),
          compare_preferring_target(target: mentee.city, a: p1.city, b: p2.city),
          compare_preferring_target(target: mentee.state, a: p1.state, b: p2.state),
          compare_preferring_target(target: mentee.region, a: p1.region, b: p2.region)
        ]

        final_comparison = sort_by_comparison_list(comparisons)

        # We want to sort in descending order (aka most preferred mentor first).
        -1 * final_comparison
      end

      preferences[mentee.name] = preferred_mentors.map(&:name)
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