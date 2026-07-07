from __future__ import annotations

import sys

from mentor_matching.csv_parser_2025 import CsvParser2025
from mentor_matching.matching import Matching
from mentor_matching.previous_matches import PreviousMatches


def main() -> None:
    csv_file_path = sys.argv[1] if len(sys.argv) > 1 else None
    previous_matches_csv_path = sys.argv[2] if len(sys.argv) > 2 else None

    if csv_file_path is None or csv_file_path == "":
        raise RuntimeError("Please pass in a CSV file path as input")

    people = CsvParser2025.parse(csv_file_path)
    previously_matched = set()
    if previous_matches_csv_path:
        previously_matched = PreviousMatches.parse(previous_matches_csv_path)

    matched_mentors_to_mentees, statistics = Matching.match(people, previously_matched=previously_matched)

    print("*************RESULTS*************")
    print()
    print(f"Median mentee # possible mentors = {statistics.median_possible_mentors_for_mentee}")
    print(f"Median mentee paired mentor rank (e.g. 4 means 4th best) = {statistics.median_matched_mentor_rank_for_mentee}")
    print()
    print(f"Median mentor # possible mentees = {statistics.median_possible_mentees_for_mentor}")
    print(f"Median mentor paired match rank (e.g. 4 means 4th best) = {statistics.median_matched_mentee_rank_for_mentor}")
    print()
    print(f"# Mentor / Mentee pairs in same state = {statistics.same_state_pair_count} / {statistics.total_pair_count}")
    print(f"Median seniority difference = {statistics.median_seniority_difference}")
    print()
    print(f"# mentors preferring IMG = {statistics.img_preferring_mentor_count}")
    print(f"# IMG mentees = {statistics.img_mentee_count}")
    print(f"# IMG mentees paired w/ mentors preferring IMG = {statistics.img_preference_pair_count}")
    print()
    print(f"# matched mentees: {len(statistics.matched_mentee_emails)}")
    print(f"# eligible mentees: {len(statistics.matched_mentee_emails) + len(statistics.unmatched_mentee_emails)}")
    print(f"% mentee match: {statistics.mentee_match_percent}%")
    print(f"Unmatched mentees ({len(statistics.unmatched_mentee_emails)}): {list(statistics.unmatched_mentee_emails)}")
    print()
    print(f"# matched mentors: {len(statistics.matched_mentor_emails)}")
    print(f"# eligible mentors: {len(statistics.matched_mentor_emails) + len(statistics.unmatched_mentor_emails)}")
    print(f"% mentor match: {statistics.mentor_match_percent}%")
    print(f"Unmatched mentors ({len(statistics.unmatched_mentor_emails)}): {list(statistics.unmatched_mentor_emails)}")
    print()
    print("Mentees -> Mentors:")
    print()
    print(Matching.format_results(matched_mentors_to_mentees))
