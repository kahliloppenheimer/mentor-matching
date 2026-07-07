from __future__ import annotations

from dataclasses import dataclass, replace
from math import nan


@dataclass(frozen=True, eq=False)
class Person2025:
    id: str
    name: str
    email: str
    state: str
    seniority: int
    is_mentee: bool
    is_mentor: bool
    is_international: bool
    prefers_mentoring_international: bool
    mentee_seniority_allowlist: tuple[int, ...]
    max_num_mentees: int

    def with_id(self, new_id: str) -> Person2025:
        return replace(self, id=new_id)

    def __hash__(self) -> int:
        return hash(self.id)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Person2025) and self.id == other.id

    def __str__(self) -> str:
        return f"{self.name} ({self.email})"

    def __repr__(self) -> str:
        return str(self)


@dataclass(frozen=True)
class MatchStatistics:
    diagnostics: tuple[str, ...]
    matched_mentee_emails: tuple[str, ...]
    matched_mentor_emails: tuple[str, ...]
    unmatched_mentee_emails: tuple[str, ...]
    unmatched_mentor_emails: tuple[str, ...]
    mentee_match_percent: float
    mentor_match_percent: float
    median_possible_mentors_for_mentee: float | None
    median_possible_mentees_for_mentor: float | None
    median_matched_mentor_rank_for_mentee: float | None
    median_matched_mentee_rank_for_mentor: float | None
    same_state_pair_count: int
    total_pair_count: int
    median_seniority_difference: float | None
    img_preferring_mentor_count: int
    img_mentee_count: int
    img_preference_pair_count: int


NAN = nan
