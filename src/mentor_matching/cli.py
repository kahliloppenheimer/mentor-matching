from __future__ import annotations

import math
import sys

from mentor_matching.csv_parser import CsvParser
from mentor_matching.matching import Matching
from mentor_matching.previous_matches import PreviousMatches


def main() -> None:
    csv_file_path = sys.argv[1] if len(sys.argv) > 1 else None
    previous_matches_csv_path = sys.argv[2] if len(sys.argv) > 2 else None

    if csv_file_path is None or csv_file_path == "":
        raise RuntimeError("Please pass in a CSV file path as input")

    people = CsvParser.parse(csv_file_path)
    previously_matched: set[str] = set()
    if previous_matches_csv_path:
        previously_matched = PreviousMatches.parse(previous_matches_csv_path)

    matched_mentors_to_mentees, statistics = Matching.match(people, previously_matched=previously_matched)

    for line in statistics.diagnostics:
        print(line)

    print()
    print()
    print("*************RESULTS*************")
    print()
    print(
        "Median mentee # possible mentors = "
        f"{_format_ruby_value(statistics.median_possible_mentors_for_mentee)}"
    )
    print(
        "Median mentee paired mentor rank (e.g. 4 means 4th best) = "
        f"{_format_ruby_value(statistics.median_matched_mentor_rank_for_mentee)}"
    )
    print()
    print(
        "Median mentor # possible mentees = "
        f"{_format_ruby_value(statistics.median_possible_mentees_for_mentor)}"
    )
    print(
        "Median mentor paired match rank (e.g. 4 means 4th best) = "
        f"{_format_ruby_value(statistics.median_matched_mentee_rank_for_mentor)}"
    )
    print()
    print(f"# Mentor / Mentee pairs in same state = {statistics.same_state_pair_count} / {statistics.total_pair_count}")
    print(f"Median seniority difference = {_format_ruby_value(statistics.median_seniority_difference)}")
    print()
    print(f"# mentors preferring IMG = {statistics.img_preferring_mentor_count}")
    print(f"# IMG mentees = {statistics.img_mentee_count}")
    print(f"# IMG mentees paired w/ mentors preferring IMG = {statistics.img_preference_pair_count}")
    print()
    print(f"# matched mentees: {len(statistics.matched_mentee_emails)}")
    print(f"# eligible mentees: {len(statistics.matched_mentee_emails) + len(statistics.unmatched_mentee_emails)}")
    print(f"% mentee match: {_format_ruby_value(statistics.mentee_match_percent)}%")
    print(f"Unmatched mentees ({len(statistics.unmatched_mentee_emails)}): {list(statistics.unmatched_mentee_emails)}")
    print()
    print(f"# matched mentors: {len(statistics.matched_mentor_emails)}")
    print(f"# eligible mentors: {len(statistics.matched_mentor_emails) + len(statistics.unmatched_mentor_emails)}")
    print(f"% mentor match: {_format_ruby_value(statistics.mentor_match_percent)}%")
    print(f"Unmatched mentors ({len(statistics.unmatched_mentor_emails)}): {list(statistics.unmatched_mentor_emails)}")
    print()
    print("Mentees -> Mentors:")
    print()
    print(Matching.format_results(matched_mentors_to_mentees))


def _format_ruby_value(value: float | None) -> str:
    if value is None:
        return ""
    if math.isnan(value):
        return "NaN"
    return str(value)
