from __future__ import annotations

from math import isnan

from mentor_matching.matching import Matching
from mentor_matching.previous_matches import PreviousMatches

from tests.helpers import build_person


def test_multiplicity_duplicates_multi_slot_mentor() -> None:
    mentor = build_person(
        id="mentor",
        name="mentor",
        email="mentor@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
        max_num_mentees=3,
    )

    mentors = Matching.multiplicity(mentor)

    assert [person.id for person in mentors] == ["mentor1", "mentor2", "mentor3"]
    assert {person.email for person in mentors} == {"mentor@example.com"}


def test_match_assigns_distinct_slots_for_multi_mentee_mentor() -> None:
    mentor = build_person(
        id="mentor",
        name="mentor",
        email="mentor@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
        max_num_mentees=2,
    )
    mentee_a = build_person(
        id="a",
        name="mentee a",
        email="a@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentee_b = build_person(
        id="b",
        name="mentee b",
        email="b@example.com",
        seniority=2,
        is_mentor=False,
        is_mentee=True,
    )

    matches, statistics = Matching.match([mentor, mentee_a, mentee_b])

    assert len(matches) == 2
    assert {matched.email for matched in matches.values()} == {"a@example.com", "b@example.com"}
    assert statistics.mentee_match_percent == 100.0
    assert statistics.mentor_match_percent == 100.0
    assert statistics.stability_violations == ()


def test_match_respects_previous_matches() -> None:
    mentor = build_person(
        id="mentor",
        name="mentor",
        email="mentor@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
        max_num_mentees=2,
    )
    mentee_a = build_person(
        id="a",
        name="mentee a",
        email="a@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentee_b = build_person(
        id="b",
        name="mentee b",
        email="b@example.com",
        seniority=2,
        is_mentor=False,
        is_mentee=True,
    )
    previously_matched = {PreviousMatches.pair_key(mentor.email, mentee_a.email)}

    matches, statistics = Matching.match([mentor, mentee_a, mentee_b], previously_matched=previously_matched)

    assert {matched.email for matched in matches.values()} == {"b@example.com"}
    assert statistics.unmatched_mentee_emails == ("a@example.com",)


def test_format_results_outputs_sorted_export_rows() -> None:
    mentor_a = build_person(
        id="mentor_a",
        name="mentor a",
        email="mentor-a@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    mentor_b = build_person(
        id="mentor_b",
        name="mentor b",
        email="mentor-b@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    mentee_a = build_person(
        id="a",
        name="mentee a",
        email="a@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentee_b = build_person(
        id="b",
        name="mentee b",
        email="b@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )

    output = Matching.format_results({mentor_b: mentee_b, mentor_a: mentee_a})

    assert output.splitlines() == [
        "mentee a;a@example.com;mentor a;mentor-a@example.com",
        "mentee b;b@example.com;mentor b;mentor-b@example.com",
    ]


def test_match_handles_zero_matches_and_preserves_diagnostics() -> None:
    mentor = build_person(
        id="mentor",
        name="mentor",
        email="mentor@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    mentee = build_person(
        id="mentee",
        name="mentee",
        email="mentee@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    previously_matched = {PreviousMatches.pair_key(mentor.email, mentee.email)}

    matches, statistics = Matching.match([mentor, mentee], previously_matched=previously_matched)

    assert matches == {}
    assert statistics.median_matched_mentor_rank_for_mentee is None
    assert statistics.median_matched_mentee_rank_for_mentor is None
    assert statistics.median_seniority_difference is None
    assert statistics.mentee_match_percent == 0.0
    assert statistics.mentor_match_percent == 0.0
    assert "Excluding 1 previously-matched pair(s) from consideration" in statistics.diagnostics
    assert "Filtering out 1 mentees with no preferences:\n[mentee (mentee@example.com)]" in statistics.diagnostics


def test_match_handles_no_eligible_people_without_crashing() -> None:
    matches, statistics = Matching.match([])

    assert matches == {}
    assert isnan(statistics.mentee_match_percent)
    assert isnan(statistics.mentor_match_percent)


def test_find_blocking_pairs_detects_an_unstable_match() -> None:
    mentor_a = build_person(
        id="ma", name="mentor a", email="ma@example.com", seniority=5, is_mentor=True, is_mentee=False
    )
    mentor_b = build_person(
        id="mb", name="mentor b", email="mb@example.com", seniority=5, is_mentor=True, is_mentee=False
    )
    mentee_a = build_person(
        id="ea", name="mentee a", email="ea@example.com", seniority=1, is_mentor=False, is_mentee=True
    )
    mentee_b = build_person(
        id="eb", name="mentee b", email="eb@example.com", seniority=1, is_mentor=False, is_mentee=True
    )

    # Both mentees rank mentor_a first, and both mentors rank mentee_a first.
    mentees_to_preferences = {
        mentee_a: [mentor_a, mentor_b],
        mentee_b: [mentor_a, mentor_b],
    }
    mentors_to_preferences = {
        mentor_a: [mentee_a, mentee_b],
        mentor_b: [mentee_a, mentee_b],
    }

    # Deliberately the wrong pairing: mentor_a and mentee_a would both rather have
    # each other than their assigned partner, so this is a blocking pair.
    unstable_matches = {mentor_a: mentee_b, mentor_b: mentee_a}

    violations = Matching._find_blocking_pairs(
        matched_mentors_to_mentees=unstable_matches,
        mentees_to_preferences=mentees_to_preferences,
        mentors_to_preferences=mentors_to_preferences,
    )

    assert len(violations) > 0


def test_find_blocking_pairs_passes_a_stable_match() -> None:
    mentor_a = build_person(
        id="ma", name="mentor a", email="ma@example.com", seniority=5, is_mentor=True, is_mentee=False
    )
    mentor_b = build_person(
        id="mb", name="mentor b", email="mb@example.com", seniority=5, is_mentor=True, is_mentee=False
    )
    mentee_a = build_person(
        id="ea", name="mentee a", email="ea@example.com", seniority=1, is_mentor=False, is_mentee=True
    )
    mentee_b = build_person(
        id="eb", name="mentee b", email="eb@example.com", seniority=1, is_mentor=False, is_mentee=True
    )

    mentees_to_preferences = {
        mentee_a: [mentor_a, mentor_b],
        mentee_b: [mentor_a, mentor_b],
    }
    mentors_to_preferences = {
        mentor_a: [mentee_a, mentee_b],
        mentor_b: [mentee_a, mentee_b],
    }

    stable_matches = {mentor_a: mentee_a, mentor_b: mentee_b}

    violations = Matching._find_blocking_pairs(
        matched_mentors_to_mentees=stable_matches,
        mentees_to_preferences=mentees_to_preferences,
        mentors_to_preferences=mentors_to_preferences,
    )

    assert violations == ()
