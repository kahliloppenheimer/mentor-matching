from __future__ import annotations

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
