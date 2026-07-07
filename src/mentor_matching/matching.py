from __future__ import annotations

from statistics import median

from mentor_matching.models import MatchStatistics, NAN, Person2025
from mentor_matching.preferences import Preferences


class Matching:
    @classmethod
    def multiplicity(cls, person: Person2025) -> list[Person2025]:
        if person.max_num_mentees <= 1:
            return [person]
        return [person.with_id(f"{person.id}{index}") for index in range(1, person.max_num_mentees + 1)]

    @classmethod
    def match(
        cls, people: list[Person2025], previously_matched: set[str] | None = None
    ) -> tuple[dict[Person2025, Person2025], MatchStatistics]:
        excluded_pairs = previously_matched or set()
        diagnostics: list[str] = []
        mentors = [mentor for person in people if person.is_mentor for mentor in cls.multiplicity(person)]
        mentees = [person for person in people if person.is_mentee]

        if excluded_pairs:
            diagnostics.append(
                f"Excluding {len(excluded_pairs)} previously-matched pair(s) from consideration"
            )

        mentees_to_preferences = Preferences.compute_mentee_to_mentor_preferences(
            mentees=mentees,
            mentors=mentors,
            previously_matched=excluded_pairs,
        )
        mentees_with_no_preferences = [
            mentee for mentee, preferences in mentees_to_preferences.items() if not preferences
        ]
        if mentees_with_no_preferences:
            diagnostics.append(
                "Filtering out "
                f"{len(mentees_with_no_preferences)} mentees with no preferences:\n"
                f"{mentees_with_no_preferences}"
            )
        mentees_to_preferences = {
            mentee: preferences for mentee, preferences in mentees_to_preferences.items() if preferences
        }
        diagnostics.append(f"Num mentees: {len({person.email for person in people if person.is_mentee})}")

        mentors_to_preferences = Preferences.compute_mentor_to_mentee_preferences(
            mentees=mentees,
            mentors=mentors,
            previously_matched=excluded_pairs,
        )
        mentors_with_no_preferences = [
            mentor for mentor, preferences in mentors_to_preferences.items() if not preferences
        ]
        if mentors_with_no_preferences:
            diagnostics.append(
                f"Filtering out {len(mentors_with_no_preferences)} mentors with no preferences:\n"
            )
        mentors_to_preferences = {
            mentor: preferences for mentor, preferences in mentors_to_preferences.items() if preferences
        }
        diagnostics.append(f"Num mentors: {len({person.email for person in people if person.is_mentor})}")
        diagnostics.append(
            "Num mentor slots (accounting for multiple mentees per mentor): "
            f"{len(mentors_to_preferences)}"
        )

        matched_mentors_to_mentees = cls._gale_shapley(
            proposers=mentees_to_preferences,
            acceptors=mentors_to_preferences,
        )

        return matched_mentors_to_mentees, cls._compute_match_statistics(
            matched_mentors_to_mentees=matched_mentors_to_mentees,
            mentees=mentees,
            mentors=mentors,
            mentees_to_preferences=mentees_to_preferences,
            mentors_to_preferences=mentors_to_preferences,
            diagnostics=diagnostics,
        )

    @classmethod
    def format_results(cls, matched_mentors_to_mentees: dict[Person2025, Person2025]) -> str:
        rows = sorted(
            f"{mentee.name};{mentee.email};{mentor.name};{mentor.email}"
            for mentor, mentee in matched_mentors_to_mentees.items()
        )
        return "\n".join(rows)

    @classmethod
    def _compute_match_statistics(
        cls,
        matched_mentors_to_mentees: dict[Person2025, Person2025],
        mentees: list[Person2025],
        mentors: list[Person2025],
        mentees_to_preferences: dict[Person2025, list[Person2025]],
        mentors_to_preferences: dict[Person2025, list[Person2025]],
        diagnostics: list[str],
    ) -> MatchStatistics:
        matched_mentee_emails = sorted({mentee.email for mentee in matched_mentors_to_mentees.values()})
        matched_mentor_emails = sorted({mentor.email for mentor in matched_mentors_to_mentees})
        unique_mentee_emails = sorted({mentee.email for mentee in mentees})
        unique_mentor_emails = sorted({mentor.email for mentor in mentors})

        mentees_to_mentors = {mentee: mentor for mentor, mentee in matched_mentors_to_mentees.items()}
        mentee_ranks = [
            mentees_to_preferences[mentee].index(mentor) + 1 for mentee, mentor in mentees_to_mentors.items()
        ]
        mentor_ranks = [
            mentors_to_preferences[mentor].index(mentee) + 1 for mentor, mentee in matched_mentors_to_mentees.items()
        ]

        unmatched_mentee_emails = sorted(
            mentee.email for mentee in mentees if mentee.email not in set(matched_mentee_emails)
        )
        unmatched_mentor_emails = sorted(
            {
                mentor.email
                for mentor in mentors
                if mentor.email not in set(matched_mentor_emails)
            }
        )

        same_state_pair_count = sum(
            1 for mentor, mentee in matched_mentors_to_mentees.items() if mentor.state == mentee.state
        )
        total_pair_count = len(matched_mentors_to_mentees)
        seniority_differences = [mentor.seniority - mentee.seniority for mentor, mentee in matched_mentors_to_mentees.items()]
        img_preferring_mentor_count = sum(1 for mentor in mentors if mentor.prefers_mentoring_international)
        img_mentee_count = sum(1 for mentee in mentees if mentee.is_international)
        img_preference_pair_count = sum(
            1
            for mentor, mentee in matched_mentors_to_mentees.items()
            if mentor.prefers_mentoring_international and mentee.is_international
        )

        return MatchStatistics(
            diagnostics=tuple(diagnostics),
            matched_mentee_emails=tuple(matched_mentee_emails),
            matched_mentor_emails=tuple(matched_mentor_emails),
            unmatched_mentee_emails=tuple(unmatched_mentee_emails),
            unmatched_mentor_emails=tuple(unmatched_mentor_emails),
            mentee_match_percent=cls._percent(len(matched_mentee_emails), len(unique_mentee_emails)),
            mentor_match_percent=cls._percent(len(matched_mentor_emails), len(unique_mentor_emails)),
            median_possible_mentors_for_mentee=cls._median_or_none(
                [len(value) for value in mentees_to_preferences.values()]
            ),
            median_possible_mentees_for_mentor=cls._median_or_none(
                [len(value) for value in mentors_to_preferences.values()]
            ),
            median_matched_mentor_rank_for_mentee=cls._median_or_none(mentee_ranks),
            median_matched_mentee_rank_for_mentor=cls._median_or_none(mentor_ranks),
            same_state_pair_count=same_state_pair_count,
            total_pair_count=total_pair_count,
            median_seniority_difference=cls._median_or_none(seniority_differences),
            img_preferring_mentor_count=img_preferring_mentor_count,
            img_mentee_count=img_mentee_count,
            img_preference_pair_count=img_preference_pair_count,
        )

    @classmethod
    def _gale_shapley(
        cls,
        proposers: dict[Person2025, list[Person2025]],
        acceptors: dict[Person2025, list[Person2025]],
    ) -> dict[Person2025, Person2025]:
        proposer_preferences = {proposer: list(preferences) for proposer, preferences in proposers.items()}
        acceptor_preferences = {acceptor: list(preferences) for acceptor, preferences in acceptors.items()}

        proposer_preferences = {
            proposer: [
                acceptor
                for acceptor in preferences
                if acceptor in acceptor_preferences and proposer in acceptor_preferences[acceptor]
            ]
            for proposer, preferences in proposer_preferences.items()
        }
        acceptor_preferences = {
            acceptor: [
                proposer
                for proposer in preferences
                if proposer in proposer_preferences and acceptor in proposer_preferences[proposer]
            ]
            for acceptor, preferences in acceptor_preferences.items()
        }

        matches: dict[Person2025, Person2025] = {}
        proposer = cls._pick_next_proposer(proposers=proposer_preferences, matches=matches)
        while proposer is not None:
            top_choice = cls._get_and_remove_top_choice(proposer=proposer, proposers=proposer_preferences)
            existing_match = matches.get(top_choice)
            if existing_match is None or cls._prefers(
                acceptor=top_choice,
                proposer1=proposer,
                proposer2=existing_match,
                acceptors=acceptor_preferences,
            ):
                matches[top_choice] = proposer
            proposer = cls._pick_next_proposer(proposers=proposer_preferences, matches=matches)

        return matches

    @staticmethod
    def _pick_next_proposer(
        proposers: dict[Person2025, list[Person2025]],
        matches: dict[Person2025, Person2025],
    ) -> Person2025 | None:
        matched_proposers = set(matches.values())
        for proposer, choices in proposers.items():
            if choices and proposer not in matched_proposers:
                return proposer
        return None

    @staticmethod
    def _get_and_remove_top_choice(
        proposer: Person2025,
        proposers: dict[Person2025, list[Person2025]],
    ) -> Person2025:
        choices = proposers[proposer]
        if not choices:
            raise RuntimeError(f"Proposer has no choices left: {proposer}")
        return choices.pop(0)

    @staticmethod
    def _prefers(
        acceptor: Person2025,
        proposer1: Person2025,
        proposer2: Person2025,
        acceptors: dict[Person2025, list[Person2025]],
    ) -> bool:
        preferences = acceptors[acceptor]
        proposer1_preference = preferences.index(proposer1) if proposer1 in preferences else -1
        proposer2_preference = preferences.index(proposer2) if proposer2 in preferences else -1
        return proposer1_preference < proposer2_preference

    @staticmethod
    def _median_or_none(values: list[int]) -> float | None:
        if not values:
            return None
        return float(median(values))

    @staticmethod
    def _percent(numerator: int, denominator: int) -> float:
        if denominator == 0:
            return NAN
        return 100.0 * numerator / denominator
