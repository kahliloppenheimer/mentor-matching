from __future__ import annotations

from pathlib import Path

import pytest

from mentor_matching.previous_matches import PreviousMatches


def test_pair_key_is_order_independent() -> None:
    assert PreviousMatches.pair_key("a@example.com", "b@example.com") == PreviousMatches.pair_key(
        "b@example.com", "a@example.com"
    )


def test_pair_key_normalizes_case_and_whitespace() -> None:
    assert PreviousMatches.pair_key("A@Example.com", "b@example.com") == PreviousMatches.pair_key(
        " a@example.com ", " B@Example.COM "
    )


def test_parse_builds_pair_keys_from_csv(tmp_path: Path) -> None:
    csv_path = tmp_path / "previous_matches.csv"
    csv_path.write_text("mentor_email,mentee_email\nmentor@example.com,mentee@example.com\n", encoding="utf-8")

    pairs = PreviousMatches.parse(str(csv_path))

    assert len(pairs) == 1
    assert PreviousMatches.pair_key("mentor@example.com", "mentee@example.com") in pairs


def test_parse_raises_on_missing_column(tmp_path: Path) -> None:
    csv_path = tmp_path / "previous_matches.csv"
    csv_path.write_text("mentor_email,other_col\nmentor@example.com,foo\n", encoding="utf-8")

    with pytest.raises(RuntimeError):
        PreviousMatches.parse(str(csv_path))
