from __future__ import annotations

from dataclasses import replace
from pathlib import Path

import pytest

from mentor_matching.cli import main
from mentor_matching.matching import Matching
from mentor_matching.models import MatchStatistics, Person

_PEOPLE_CSV_ROWS = [
    "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
    "Mentor,mentor@example.com,ny,5,1,0,0,0,,1",
    "Mentee,mentee@example.com,ny,1,0,1,0,0,,1",
]


def test_cli_prints_match_results(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text("\n".join(_PEOPLE_CSV_ROWS), encoding="utf-8")
    monkeypatch.setattr("sys.argv", ["mentor-matching", str(csv_path)])

    main()

    output = capsys.readouterr().out
    assert "*************RESULTS*************" in output
    assert "Num mentees: 1" in output
    assert "mentee;mentee@example.com;mentor;mentor@example.com" in output
    assert "Stability check passed: no blocking pairs found." in output


def test_cli_exits_nonzero_when_stability_check_fails(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text("\n".join(_PEOPLE_CSV_ROWS), encoding="utf-8")
    monkeypatch.setattr("sys.argv", ["mentor-matching", str(csv_path)])

    original_match = Matching.match

    def fake_match(
        people: list[Person], previously_matched: set[str] | None = None
    ) -> tuple[dict[Person, Person], MatchStatistics]:
        matches, statistics = original_match(people, previously_matched=previously_matched)
        return matches, replace(statistics, stability_violations=("fake blocking pair for test",))

    monkeypatch.setattr(Matching, "match", fake_match)

    with pytest.raises(SystemExit) as exc_info:
        main()

    assert exc_info.value.code == 1
    output = capsys.readouterr().out
    assert "STABILITY CHECK FAILED: found 1 blocking pair(s):" in output
    assert "fake blocking pair for test" in output
