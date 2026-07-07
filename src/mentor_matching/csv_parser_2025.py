from __future__ import annotations

import csv
import secrets
from pathlib import Path

from mentor_matching.models import Person2025


class CsvParser2025:
    NAME_COL = "name"
    EMAIL_COL = "email"
    STATE_COL = "state"
    SENIORITY_COL = "seniority"
    IS_MENTOR_COL = "is a mentor?"
    IS_MENTEE_COL = "is a mentee?"
    IS_INTERNATIONAL_COL = "img?"
    PREFERS_MENTORING_INTERNATIONAL_COL = "prefer mentoring img?"
    MENTEE_SENIORITY_ALLOWLIST_COL = "who would you be interested in mentoring?"
    MAX_NUM_MENTEES_COL = "how many mentees would you be willing to mentor?"

    ALL_COLS = (
        NAME_COL,
        EMAIL_COL,
        STATE_COL,
        SENIORITY_COL,
        IS_MENTOR_COL,
        IS_MENTEE_COL,
        IS_INTERNATIONAL_COL,
        PREFERS_MENTORING_INTERNATIONAL_COL,
        MENTEE_SENIORITY_ALLOWLIST_COL,
        MAX_NUM_MENTEES_COL,
    )

    @classmethod
    def parse(cls, csv_path: str) -> list[Person2025]:
        rows = cls._parse_csv_into_arrays(csv_path)
        if not rows:
            raise RuntimeError("CSV is empty.")

        schema = cls._parse_csv_schema(rows[0])
        people = [
            cls._parse_person(schema=schema, row=row)
            for row in rows[1:]
            if cls._row_has_content(row)
        ]

        people_with_multiple_names = sorted(
            name for name, group in cls._group_by_name(people).items() if len(group) > 1
        )
        if people_with_multiple_names:
            raise RuntimeError(f"Found people with multiple entries:\n{people_with_multiple_names}")

        people_with_multiple_emails = sorted(
            email for email, group in cls._group_by_email(people).items() if len(group) > 1
        )
        if people_with_multiple_emails:
            raise RuntimeError(f"Found people with multiple entries:\n{people_with_multiple_emails}")

        corrected_people = [cls._correct_mentee_seniority_allowlist(person) for person in people]
        invalid_people = [
            person
            for person in corrected_people
            if any(preferred_seniority >= person.seniority for preferred_seniority in person.mentee_seniority_allowlist)
        ]
        if invalid_people:
            raise RuntimeError(
                "Found people with incorrect mentee preferences:\n"
                f"{[person.email for person in invalid_people]}"
            )

        return corrected_people

    @classmethod
    def _correct_mentee_seniority_allowlist(cls, person: Person2025) -> Person2025:
        filtered_allowlist = tuple(
            seniority for seniority in person.mentee_seniority_allowlist if seniority < person.seniority
        )
        return Person2025(
            id=person.id,
            name=person.name,
            email=person.email,
            state=person.state,
            seniority=person.seniority,
            is_mentee=person.is_mentee,
            is_mentor=person.is_mentor,
            is_international=person.is_international,
            prefers_mentoring_international=person.prefers_mentoring_international,
            mentee_seniority_allowlist=filtered_allowlist,
            max_num_mentees=person.max_num_mentees,
        )

    @classmethod
    def _parse_csv_into_arrays(cls, csv_path: str) -> list[list[str | None]]:
        with Path(csv_path).open(newline="", encoding="utf-8") as handle:
            return [
                [value.lower().strip() if value is not None else None for value in row]
                for row in csv.reader(handle)
            ]

    @classmethod
    def _parse_csv_schema(cls, headers: list[str | None]) -> dict[str, int]:
        schema: dict[str, int] = {}
        for index, header in enumerate(headers):
            if header is not None and header in cls.ALL_COLS:
                schema[header] = index

        for column in cls.ALL_COLS:
            if column not in schema:
                raise RuntimeError(f"Could not find column: `{column}` in CSV. Only found headers: {headers}")

        return schema

    @classmethod
    def _parse_boolean_col(cls, value: str) -> bool:
        num = cls._ruby_to_int(value)
        if num == 0:
            return False
        if num == 1:
            return True
        raise RuntimeError(f"Invalid boolean value found: {value}")

    @classmethod
    def _parse_person(cls, schema: dict[str, int], row: list[str | None]) -> Person2025:
        seniority_value = row[schema[cls.SENIORITY_COL]]
        if seniority_value is None:
            raise RuntimeError(f"Row is missing seniority:\n{row}")
        seniority = cls._ruby_to_int(seniority_value)

        mentee_seniority_allowlist = tuple(
            cls._ruby_to_int(item.strip())
            for item in (row[schema[cls.MENTEE_SENIORITY_ALLOWLIST_COL]] or "").split(",")
            if item.strip()
        )
        if mentee_seniority_allowlist == (0,):
            mentee_seniority_allowlist = tuple(range(seniority))

        max_num_mentees_value = row[schema[cls.MAX_NUM_MENTEES_COL]]
        if max_num_mentees_value is None:
            raise RuntimeError(f"Row is missing max_num_mentees:\n{row}")
        max_num_mentees = max(cls._ruby_to_int(value) for value in max_num_mentees_value.split(";"))

        return Person2025(
            id=secrets.token_hex(8),
            name=cls._required_value(row, schema[cls.NAME_COL]),
            email=cls._required_value(row, schema[cls.EMAIL_COL]),
            state=cls._required_value(row, schema[cls.STATE_COL]),
            seniority=seniority,
            is_mentee=cls._parse_boolean_col(cls._required_value(row, schema[cls.IS_MENTEE_COL])),
            is_mentor=cls._parse_boolean_col(cls._required_value(row, schema[cls.IS_MENTOR_COL])),
            is_international=cls._parse_boolean_col(cls._required_value(row, schema[cls.IS_INTERNATIONAL_COL])),
            prefers_mentoring_international=cls._parse_boolean_col(
                cls._required_value(row, schema[cls.PREFERS_MENTORING_INTERNATIONAL_COL])
            ),
            mentee_seniority_allowlist=mentee_seniority_allowlist,
            max_num_mentees=max_num_mentees,
        )

    @staticmethod
    def _required_value(row: list[str | None], index: int) -> str:
        value = row[index]
        if value is None or value == "":
            raise RuntimeError(f"Row is missing required value at index {index}:\n{row}")
        return value

    @staticmethod
    def _row_has_content(row: list[str | None]) -> bool:
        return any(value not in (None, "") for value in row)

    @staticmethod
    def _ruby_to_int(value: str) -> int:
        stripped = value.lstrip()
        sign = 1
        if stripped.startswith("-"):
            sign = -1
            stripped = stripped[1:]
        elif stripped.startswith("+"):
            stripped = stripped[1:]

        digits: list[str] = []
        for char in stripped:
            if not char.isdigit():
                break
            digits.append(char)

        if not digits:
            return 0

        return sign * int("".join(digits))

    @staticmethod
    def _group_by_name(people: list[Person2025]) -> dict[str, list[Person2025]]:
        grouped: dict[str, list[Person2025]] = {}
        for person in people:
            grouped.setdefault(person.name, []).append(person)
        return grouped

    @staticmethod
    def _group_by_email(people: list[Person2025]) -> dict[str, list[Person2025]]:
        grouped: dict[str, list[Person2025]] = {}
        for person in people:
            grouped.setdefault(person.email, []).append(person)
        return grouped
