from __future__ import annotations

from functools import cmp_to_key

from mentor_matching.models import Person
from mentor_matching.previous_matches import PreviousMatches


class Preferences:
    @classmethod
    def compute_mentor_to_mentee_preferences(
        cls,
        mentees: list[Person],
        mentors: list[Person],
        previously_matched: set[str] | None = None,
    ) -> dict[Person, list[Person]]:
        excluded_pairs = previously_matched or set()
        preferences: dict[Person, list[Person]] = {}

        if not all(person.is_mentee for person in mentees):
            raise RuntimeError("Found non mentees!")
        if not all(person.is_mentor for person in mentors):
            raise RuntimeError("Found non mentors!")

        for mentor in mentors:
            potential_mentees = [
                other_person
                for other_person in mentees
                if other_person.is_mentee
                and mentor != other_person
                and other_person.seniority < mentor.seniority
                and PreviousMatches.pair_key(mentor.email, other_person.email) not in excluded_pairs
            ]
            def mentor_comparator(p1: Person, p2: Person) -> int:
                return cls._mentor_preference_comparator(mentor=mentor, p1=p1, p2=p2)

            preferred_mentees = sorted(
                potential_mentees,
                key=cmp_to_key(mentor_comparator),
            )
            preferences[mentor] = preferred_mentees

        return preferences

    @classmethod
    def compute_mentee_to_mentor_preferences(
        cls,
        mentees: list[Person],
        mentors: list[Person],
        previously_matched: set[str] | None = None,
    ) -> dict[Person, list[Person]]:
        excluded_pairs = previously_matched or set()
        preferences: dict[Person, list[Person]] = {}

        if not all(person.is_mentee for person in mentees):
            raise RuntimeError("Found non mentees!")
        if not all(person.is_mentor for person in mentors):
            raise RuntimeError("Found non mentors!")

        for mentee in mentees:
            potential_mentors = [
                other_person
                for other_person in mentors
                if mentee != other_person
                and other_person.seniority > mentee.seniority
                and PreviousMatches.pair_key(other_person.email, mentee.email) not in excluded_pairs
            ]
            def mentee_comparator(p1: Person, p2: Person) -> int:
                return cls._mentee_preference_comparator(mentee=mentee, p1=p1, p2=p2)

            preferred_mentors = sorted(
                potential_mentors,
                key=cmp_to_key(mentee_comparator),
            )
            preferences[mentee] = preferred_mentors

        return preferences

    @classmethod
    def _mentor_preference_comparator(cls, mentor: Person, p1: Person, p2: Person) -> int:
        comparisons = (
            cls._compare_international_preference_for_mentor(mentor=mentor, p1=p1, p2=p2),
            cls._compare_mentee_seniority_allowlist(mentor=mentor, p1=p1, p2=p2),
            cls._compare_preferring_target(target=mentor.state, a=p1.state, b=p2.state),
            cls._compare_rank(target_rank=mentor.seniority, p1_rank=p1.seniority, p2_rank=p2.seniority),
        )
        return -1 * cls._sort_by_comparison_list(comparisons)

    @classmethod
    def _mentee_preference_comparator(cls, mentee: Person, p1: Person, p2: Person) -> int:
        comparisons = (
            cls._compare_international_preference_for_mentee(mentee=mentee, p1=p1, p2=p2),
            cls._compare_preferring_target(target=mentee.state, a=p1.state, b=p2.state),
            cls._compare_rank(target_rank=mentee.seniority, p1_rank=p1.seniority, p2_rank=p2.seniority),
        )
        return -1 * cls._sort_by_comparison_list(comparisons)

    @staticmethod
    def _sort_by_comparison_list(comparisons: tuple[int, ...]) -> int:
        for comparison in comparisons:
            if comparison != 0:
                return comparison
        return 0

    @staticmethod
    def _compare_international_preference_for_mentee(mentee: Person, p1: Person, p2: Person) -> int:
        if not mentee.is_international:
            return 0
        if p1.prefers_mentoring_international and not p2.prefers_mentoring_international:
            return 1
        if not p1.prefers_mentoring_international and p2.prefers_mentoring_international:
            return -1
        return 0

    @staticmethod
    def _compare_international_preference_for_mentor(mentor: Person, p1: Person, p2: Person) -> int:
        if not mentor.prefers_mentoring_international:
            return 0
        if p1.is_international and not p2.is_international:
            return 1
        if not p1.is_international and p2.is_international:
            return -1
        return 0

    @staticmethod
    def _compare_rank(target_rank: int, p1_rank: int, p2_rank: int) -> int:
        p1_rank_difference = abs(p1_rank - target_rank)
        p2_rank_difference = abs(p2_rank - target_rank)
        if p2_rank_difference < p1_rank_difference:
            return -1
        if p2_rank_difference > p1_rank_difference:
            return 1
        return 0

    @staticmethod
    def _compare_mentee_seniority_allowlist(mentor: Person, p1: Person, p2: Person) -> int:
        allowlist = mentor.mentee_seniority_allowlist
        if p1.seniority in allowlist and p2.seniority not in allowlist:
            return 1
        if p1.seniority not in allowlist and p2.seniority in allowlist:
            return -1
        return 0

    @staticmethod
    def _compare_preferring_target(target: object, a: object, b: object) -> int:
        if a == target and b != target:
            return 1
        if a != target and b == target:
            return -1
        return 0
