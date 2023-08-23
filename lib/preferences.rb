# typed: strict
require 'sorbet-runtime'
require './lib/person'
require 'pry-byebug'

class Preferences

  extend T::Sig

  sig {params(people: T::Array[Person]).returns(T::Hash[String, T::Array[String]])}
  def self.compute_mentor_to_mentee_preferences(people)
    preferences = T.let({}, T::Hash[String, T::Array[String]])

    people.each do |mentor|

      if !mentor.is_mentor
        preferences[mentor.name] = []
        next
      end

      potential_mentees = people
        # Only keep people who want to be mentees.
        .select {|other_person| other_person.is_mentee}
        # Only keep mentees that match the mentor's seniority allowlist (if there is one).
        .select {|other_person| mentor.mentee_seniority_allowlist.empty? || mentor.mentee_seniority_allowlist.include?(other_person.seniority)}
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentor == other_person}
        # Only keep potential mentees who are more junior.
        .select {|other_person| other_person.rank - mentor.rank < 0}
        # Reject any mentees who are on the person_denylist.
        .reject {|other_person| mentor.person_denylist.include?(other_person.name)}
        # Reject any mentees on the region denylist
        .reject {|other_person| mentor.mentee_region_denylist.include?(other_person.region)}

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

      if !mentee.is_mentee
        preferences[mentee.name] = []
        next
      end
      
      potential_mentors = people
        # Only keep people who want to be mentors
        .select {|other_person| other_person.is_mentor}
        # Rule out yourself as a potential mentor.
        .reject {|other_person| mentee == other_person}
        # Only keep potential mentors who are more senior
        .select {|other_person| other_person.rank - mentee.rank > 0}
        # Reject any mentors who are on the person_denylist.
        .reject {|other_person| mentee.person_denylist.include?(other_person.name)}
        # Rule out mentors on the mentor_region_denylist
        .reject {|other_person| mentee.mentor_region_denylist.include?(other_person.region)}

      # Perform a cascading comparison where we sort based on adjacent seniority, city, state, then region
      # (in descending order of priority).
      preferred_mentors = potential_mentors.sort do |p1, p2|
        comparisons = [
          p1.mentee_seniority_allowlist.include?(mentee.seniority) ? 1 : 0,
          compare_rank(target_rank: mentee.rank, p1_rank: p1.rank, p2_rank: p2.rank),
          # compare_preferring_target(target: mentee.city, a: p1.city, b: p2.city),
          # compare_preferring_target(target: mentee.state, a: p1.state, b: p2.state),
          compare_preferring_target(target: mentee.region, a: p1.region, b: p2.region),
          compare_interests(mentee, p1, p2)
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