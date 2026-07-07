from __future__ import annotations

from pathlib import Path

import pytest

from mentor_matching.cli import main


def test_cli_prints_match_results(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    csv_path = tmp_path / "people.csv"
    csv_path.write_text(
        "\n".join(
            [
                "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?",
                "Mentor,mentor@example.com,ny,5,1,0,0,0,,1",
                "Mentee,mentee@example.com,ny,1,0,1,0,0,,1",
            ]
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr("sys.argv", ["mentor-matching", str(csv_path)])

    main()

    output = capsys.readouterr().out
    assert "*************RESULTS*************" in output
    assert "Num mentees: 1" in output
    assert "mentee;mentee@example.com;mentor;mentor@example.com" in output
