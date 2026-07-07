from __future__ import annotations

from mentor_matching.models import Person2025


def build_person(
    *,
    id: str,
    name: str,
    email: str,
    seniority: int,
    is_mentor: bool,
    is_mentee: bool,
    state: str = "ny",
    is_international: bool = False,
    prefers_mentoring_international: bool = False,
    mentee_seniority_allowlist: tuple[int, ...] = (),
    max_num_mentees: int = 1,
) -> Person2025:
    return Person2025(
        id=id,
        name=name,
        email=email,
        state=state,
        seniority=seniority,
        is_mentee=is_mentee,
        is_mentor=is_mentor,
        is_international=is_international,
        prefers_mentoring_international=prefers_mentoring_international,
        mentee_seniority_allowlist=mentee_seniority_allowlist,
        max_num_mentees=max_num_mentees,
    )
