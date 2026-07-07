from __future__ import annotations

import csv


class PreviousMatches:
    MENTOR_EMAIL_COL = "mentor_email"
    MENTEE_EMAIL_COL = "mentee_email"

    @classmethod
    def pair_key(cls, mentor_email: str, mentee_email: str) -> str:
        return "|".join(sorted((mentor_email.lower().strip(), mentee_email.lower().strip())))

    @classmethod
    def parse(cls, csv_path: str) -> set[str]:
        with open(csv_path, newline="", encoding="utf-8") as handle:
            rows = list(csv.reader(handle))

        if not rows:
            raise RuntimeError("Previous matches CSV is empty.")

        headers = [header.lower().strip() if header is not None else None for header in rows[0]]
        schema: dict[str, int] = {}
        for column in (cls.MENTOR_EMAIL_COL, cls.MENTEE_EMAIL_COL):
            try:
                schema[column] = headers.index(column)
            except ValueError as exc:
                raise RuntimeError(
                    "Previous matches CSV is missing a "
                    f"`{column}` column. Expected headers: "
                    f"{cls.MENTOR_EMAIL_COL}, {cls.MENTEE_EMAIL_COL}."
                ) from exc

        pair_keys: set[str] = set()
        for row in rows[1:]:
            if not any(value is not None and value != "" for value in row):
                continue
            mentor_email = row[schema[cls.MENTOR_EMAIL_COL]]
            mentee_email = row[schema[cls.MENTEE_EMAIL_COL]]
            pair_keys.add(cls.pair_key(mentor_email, mentee_email))

        return pair_keys
