# typed: false
require 'minitest/autorun'
require 'set'
require './lib/person_2025'
require './lib/preferences'
require './lib/previous_matches'

class PreferencesTest < Minitest::Test
  def build_person(id:, name:, email:, seniority:, is_mentor:, is_mentee:)
    Person2025.new(
      id: id,
      name: name,
      email: email,
      state: 'NY',
      seniority: seniority,
      is_mentee: is_mentee,
      is_mentor: is_mentor,
      is_international: false,
      prefers_mentoring_international: false,
      mentee_seniority_allowlist: [],
      max_num_mentees: 1
    )
  end

  def setup
    @mentee = build_person(id: '1', name: 'mentee', email: 'mentee@example.com', seniority: 1, is_mentor: false, is_mentee: true)
    @mentor_a = build_person(id: '2', name: 'mentor a', email: 'mentor-a@example.com', seniority: 5, is_mentor: true, is_mentee: false)
    @mentor_b = build_person(id: '3', name: 'mentor b', email: 'mentor-b@example.com', seniority: 5, is_mentor: true, is_mentee: false)
  end

  def test_mentee_preferences_include_all_eligible_mentors_by_default
    preferences = Preferences.compute_mentee_to_mentor_preferences(mentees: [@mentee], mentors: [@mentor_a, @mentor_b])
    assert_equal([@mentor_a, @mentor_b].sort_by(&:email), preferences.fetch(@mentee).sort_by(&:email))
  end

  def test_mentee_preferences_exclude_a_previously_matched_mentor
    previously_matched = Set.new([PreviousMatches.pair_key(@mentor_a.email, @mentee.email)])
    preferences = Preferences.compute_mentee_to_mentor_preferences(
      mentees: [@mentee], mentors: [@mentor_a, @mentor_b], previously_matched: previously_matched
    )
    assert_equal([@mentor_b], preferences.fetch(@mentee))
  end

  def test_mentor_preferences_exclude_a_previously_matched_mentee
    other_mentee = build_person(id: '4', name: 'other mentee', email: 'other-mentee@example.com', seniority: 1, is_mentor: false, is_mentee: true)
    previously_matched = Set.new([PreviousMatches.pair_key(@mentor_a.email, @mentee.email)])
    preferences = Preferences.compute_mentor_to_mentee_preferences(
      mentees: [@mentee, other_mentee], mentors: [@mentor_a], previously_matched: previously_matched
    )
    assert_equal([other_mentee], preferences.fetch(@mentor_a))
  end
end
