from __future__ import annotations

from mentor_matching.preferences import Preferences
from mentor_matching.previous_matches import PreviousMatches

from tests.helpers import build_person


def test_mentee_preferences_include_all_eligible_mentors_by_default() -> None:
    mentee = build_person(
        id="1",
        name="mentee",
        email="mentee@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentor_a = build_person(
        id="2",
        name="mentor a",
        email="mentor-a@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    mentor_b = build_person(
        id="3",
        name="mentor b",
        email="mentor-b@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )

    preferences = Preferences.compute_mentee_to_mentor_preferences(mentees=[mentee], mentors=[mentor_a, mentor_b])

    assert sorted(preferences[mentee], key=lambda person: person.email) == sorted(
        [mentor_a, mentor_b], key=lambda person: person.email
    )


def test_mentee_preferences_exclude_a_previously_matched_mentor() -> None:
    mentee = build_person(
        id="1",
        name="mentee",
        email="mentee@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentor_a = build_person(
        id="2",
        name="mentor a",
        email="mentor-a@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    mentor_b = build_person(
        id="3",
        name="mentor b",
        email="mentor-b@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    previously_matched = {PreviousMatches.pair_key(mentor_a.email, mentee.email)}

    preferences = Preferences.compute_mentee_to_mentor_preferences(
        mentees=[mentee],
        mentors=[mentor_a, mentor_b],
        previously_matched=previously_matched,
    )

    assert preferences[mentee] == [mentor_b]


def test_mentor_preferences_exclude_a_previously_matched_mentee() -> None:
    mentee = build_person(
        id="1",
        name="mentee",
        email="mentee@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    other_mentee = build_person(
        id="4",
        name="other mentee",
        email="other-mentee@example.com",
        seniority=1,
        is_mentor=False,
        is_mentee=True,
    )
    mentor = build_person(
        id="2",
        name="mentor a",
        email="mentor-a@example.com",
        seniority=5,
        is_mentor=True,
        is_mentee=False,
    )
    previously_matched = {PreviousMatches.pair_key(mentor.email, mentee.email)}

    preferences = Preferences.compute_mentor_to_mentee_preferences(
        mentees=[mentee, other_mentee],
        mentors=[mentor],
        previously_matched=previously_matched,
    )

    assert preferences[mentor] == [other_mentee]


def test_mentor_preferences_prioritize_international_and_allowlist_then_state_then_rank() -> None:
    mentor = build_person(
        id="m1",
        name="mentor",
        email="mentor@example.com",
        seniority=6,
        is_mentor=True,
        is_mentee=False,
        state="ny",
        prefers_mentoring_international=True,
        mentee_seniority_allowlist=(2,),
    )
    mentee_a = build_person(
        id="a",
        name="mentee a",
        email="a@example.com",
        seniority=2,
        is_mentor=False,
        is_mentee=True,
        state="ca",
        is_international=True,
    )
    mentee_b = build_person(
        id="b",
        name="mentee b",
        email="b@example.com",
        seniority=3,
        is_mentor=False,
        is_mentee=True,
        state="ny",
        is_international=False,
    )

    preferences = Preferences.compute_mentor_to_mentee_preferences(mentees=[mentee_a, mentee_b], mentors=[mentor])

    assert preferences[mentor] == [mentee_a, mentee_b]


def test_mentee_preferences_prioritize_img_then_state_then_rank() -> None:
    mentee = build_person(
        id="mentee",
        name="mentee",
        email="mentee@example.com",
        seniority=2,
        is_mentor=False,
        is_mentee=True,
        state="ny",
        is_international=True,
    )
    mentor_a = build_person(
        id="a",
        name="mentor a",
        email="a@example.com",
        seniority=4,
        is_mentor=True,
        is_mentee=False,
        state="ca",
        prefers_mentoring_international=True,
    )
    mentor_b = build_person(
        id="b",
        name="mentor b",
        email="b@example.com",
        seniority=3,
        is_mentor=True,
        is_mentee=False,
        state="ny",
        prefers_mentoring_international=False,
    )

    preferences = Preferences.compute_mentee_to_mentor_preferences(mentees=[mentee], mentors=[mentor_a, mentor_b])

    assert preferences[mentee] == [mentor_a, mentor_b]
