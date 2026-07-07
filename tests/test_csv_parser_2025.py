from __future__ import annotations

from pathlib import Path

import pytest

from mentor_matching.csv_parser_2025 import CsvParser2025


def test_parse_builds_people_and_normalizes_values(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                " Alice ,Alice@Example.com, NY ,5,1,0,0,1,1,2;3",
            ]
        ),
        encoding="utf-8",
    )

    people = CsvParser2025.parse(str(csv_path))

    assert len(people) == 1
    assert people[0].name == "alice"
    assert people[0].email == "alice@example.com"
    assert people[0].state == "ny"
    assert people[0].mentee_seniority_allowlist == (1,)
    assert people[0].max_num_mentees == 3


def test_parse_expands_zero_allowlist_to_all_more_junior_levels(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                "Alice,alice@example.com,ny,4,1,0,0,0,0,1",
            ]
        ),
        encoding="utf-8",
    )

    people = CsvParser2025.parse(str(csv_path))

    assert people[0].mentee_seniority_allowlist == (0, 1, 2, 3)


def test_parse_raises_on_duplicate_email(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                "Alice,alice@example.com,ny,4,1,0,0,0,,1",
                "Bob,alice@example.com,ny,3,0,1,0,0,,1",
            ]
        ),
        encoding="utf-8",
    )

    with pytest.raises(RuntimeError):
        CsvParser2025.parse(str(csv_path))


def test_parse_raises_on_missing_required_header(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text("name,email\nalice,alice@example.com\n", encoding="utf-8")

    with pytest.raises(RuntimeError):
        CsvParser2025.parse(str(csv_path))


def test_parse_skips_trailing_blank_row(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                "Alice,alice@example.com,ny,4,1,0,0,0,,1",
                ",,,,,,,,,",
            ]
        ),
        encoding="utf-8",
    )

    people = CsvParser2025.parse(str(csv_path))

    assert len(people) == 1


def test_parse_boolean_coerces_like_ruby_to_i(tmp_path: Path) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                "Alice,alice@example.com,ny,4,TRUE,abc,nope,nah,abc,2;xyz",
            ]
        ),
        encoding="utf-8",
    )

    people = CsvParser2025.parse(str(csv_path))

    assert people[0].is_mentor is False
    assert people[0].is_mentee is False
    assert people[0].is_international is False
    assert people[0].prefers_mentoring_international is False
    assert people[0].mentee_seniority_allowlist == (0, 1, 2, 3)
    assert people[0].max_num_mentees == 2
