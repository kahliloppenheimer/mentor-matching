---
name: mentor-matching
description: Turns a raw mentor/mentee sign-up spreadsheet export (Google Forms, Google Sheets, Excel-as-CSV) into the format the mentor matching program needs, then runs the match. Use when the user has a CSV/spreadsheet of mentor-mentee sign-ups and wants to run matching, find mentor/mentee pairs, or mentions "match mentors and mentees" — especially when they don't already have a CSV in the program's exact column format.
---

# Mentor matching skill

You're helping someone with no coding background turn a raw sign-up spreadsheet
into stable mentor/mentee matches.

The program is strict: it only accepts a CSV with these exact columns:

```
name, email, state, seniority, is a mentor?, is a mentee?, img?,
prefer mentoring img?, who would you be interested in mentoring?,
how many mentees would you be willing to mentor?
```

Your job is to get from a raw spreadsheet export to that exact shape, confirm any
ambiguous mapping with the user, then run the matcher. They can also optionally
hand you last year's match results to avoid repeat pairings.

## Steps

### 1. Get the raw file
Ask for the path to a CSV export of their sign-up spreadsheet. If they only have a
Google Sheet or Excel file, tell them to export CSV first.

### 2. Read it defensively
Use Python's `csv` module with `encoding='utf-8-sig'` to inspect the raw file.
Print the header row and 2-3 sample rows for yourself. Don't dump the full file
into the conversation.

### 3. Propose a column mapping
Map the raw headers to the 10 required fields.

Two fields are often missing in raw exports:
- `prefer mentoring img?`: if absent, default to `0` and say so explicitly.
- `state`: if the raw data only has city/free text, derive a clean state or country
  value per row yourself. Flag rows you can't place confidently.

Show the mapping and any defaults/assumptions to the user in plain text and get
confirmation before proceeding.

### 4. Normalize seniority and mentee counts
Read `reference/seniority-scale.md` now.

Build the raw-value -> rank mapping from the actual distinct values in the file
using that scale as the starting point. Show the mapping to the user and ask about
any ambiguous values or multi-select/free-text rows.

Do the same for:
- "how many mentees would you mentor"
- "who would you be interested in mentoring?"

Reuse the same seniority mapping for the mentoring-allowlist field.

### 5. Normalize booleans
Write `is a mentor?`, `is a mentee?`, `img?`, and `prefer mentoring img?` as
literal `0` or `1`.

Typical mapping:
- `Yes` -> `1`
- everything else -> `0`

If the raw values look unusual, confirm with the user instead of guessing.

### 6. Write the normalized CSV
Write the output with these exact lowercase headers:

```
name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?
```

Write it to `tmp/<timestamp>_normalized.csv` in the repo root. `tmp/` should be
created if missing.

Before running, summarize:
- mentor count
- mentee count
- any skipped rows
- any rows that needed judgment calls

### 7. Optional previous matches
Ask if they have last year's results and want to avoid repeated pairings.

If yes, build `tmp/<timestamp>_previous_matches.csv` with exactly:

```
mentor_email,mentee_email
```

Read the raw previous-match export defensively with Python `csv`. If it has junk
header/title rows or positional columns, infer carefully and confirm with the user
if the mapping is not obvious.

### 8. Validate before running
Validate the normalized file(s) with the program's own parser classes:

```bash
uv run python -c 'from mentor_matching.csv_parser import CsvParser; import sys; CsvParser.parse(sys.argv[1])' tmp/<timestamp>_normalized.csv
uv run python -c 'from mentor_matching.previous_matches import PreviousMatches; import sys; PreviousMatches.parse(sys.argv[1])' tmp/<timestamp>_previous_matches.csv
```

If a fix is mechanical, fix it yourself and re-run validation. If the fix is
ambiguous, stop and ask the user.

### 9. Run the match
```bash
uv run mentor-matching tmp/<timestamp>_normalized.csv tmp/<timestamp>_previous_matches.csv
```

The second argument is optional. Save the full output to
`tmp/<timestamp>_results.txt`.

Every match is always stability-checked automatically — `Matching.match` runs
`Matching._find_blocking_pairs` (the Gale-Shapley invariant: no unmatched
mentor/mentee pair should exist who'd both prefer each other over their current
match) and the CLI exits with a non-zero status and prints
`STABILITY CHECK FAILED` if it finds any. You don't need to invoke anything extra
for this to run, and you can't accidentally skip it.

If you ever see `STABILITY CHECK FAILED`, that means the matching algorithm
itself produced an invalid result. Don't report it to the user as if it were a
normal data issue and move on — treat it as a real bug in `matching.py`/
`preferences.py`. Stop and investigate/report it clearly.

Summarize for the user:
- match %
- median ranks
- unmatched counts (with a one-line reason for each unmatched person — see the
  "Filtering out N mentees/mentors with no preferences" vs. plain "Unmatched"
  distinction in the output)
- the stability check result (always mention it explicitly, even when it passes)

### 10. Produce a CSV of the results
Don't scrape the plain-text log by splitting on delimiters. Recompute the match
programmatically and write a real CSV with Python using the same parser and matching
modules, and the same `previously_matched` set if used.

Write:

```
mentee_name,mentee_email,mentee_state,mentee_seniority,mentor_name,mentor_email,mentor_state,mentor_seniority
```

Save it as `tmp/<timestamp>_matches.csv` and tell the user where it is.
