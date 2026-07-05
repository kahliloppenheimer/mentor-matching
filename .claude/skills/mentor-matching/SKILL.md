---
name: mentor-matching
description: Turns a raw mentor/mentee sign-up spreadsheet export (Google Forms, Google Sheets, Excel-as-CSV) into the format the mentor matching program needs, then runs the match. Use when the user has a CSV/spreadsheet of mentor-mentee sign-ups and wants to run matching, find mentor/mentee pairs, or mentions "match mentors and mentees" — especially when they don't already have a CSV in the program's exact column format.
---

# Mentor matching skill

You're helping someone with no Ruby/coding background turn their raw sign-up
spreadsheet into stable mentor/mentee matches. They will *not* know column names or
formats the underlying program expects — that's your job to figure out and confirm
with them in plain language.

The program itself (`lib/application.rb` → `CsvParser2025` → `Matching`) is unchanged
and strict: it only accepts a CSV with these exact columns (see
`lib/csv_parser_2025.rb:12-35`):

```
name, email, state, seniority, is a mentor?, is a mentee?, img?,
prefer mentoring img?, who would you be interested in mentoring?,
how many mentees would you be willing to mentor?
```

Your job is to get from "whatever spreadsheet they hand you" to that exact shape,
with their sign-off at each judgment call, then run the program. They can also
optionally hand you last year's match results to avoid repeating the same pairings
(`lib/application.rb` takes it as an optional second argument, parsed by
`lib/previous_matches.rb`).

## Steps

### 1. Get the raw file
Ask for the path to a CSV export of their sign-up spreadsheet. If they only have a
Google Sheet or Excel file, tell them how to export it: File → Download/Export → CSV.

### 2. Read it defensively
Real exports from this survey are messy: stray BOM/encoding quirks, embedded
newlines inside quoted header cells, trailing whitespace on names/emails, and
occasional malformed quoting. **Ruby's `CSV.read` has choked on real exports from
this form even with `liberal_parsing: true`.** Use Python's `csv` module (with
`encoding='utf-8-sig'`) to read the raw file — it has handled every real export seen
so far. Don't spend time debugging Ruby's CSV parser on the raw input; save Ruby for
writing the final clean output and running the program.

Print the header row and 2-3 sample rows for yourself to reason about (don't dump
the whole file into the conversation).

### 3. Propose a column mapping
Map the raw headers to the 10 required fields. Most are obvious from the header text
(e.g. "Email address" → `email`). Two are commonly *missing entirely* from raw
exports:
- `prefer mentoring img?` (whether a mentor prefers mentoring international grads) —
  if there's no such question in the raw file, default everyone to `0` (no
  preference) and say so explicitly; don't invent an answer.
- `state` — raw exports often only have a free-text "City" field like
  `"Valhalla, NY, USA"`, `"Milwaukee, wi"`, `"Karachi, Pakistan"`, or just a bare
  state/country name. Extract a clean state value per row yourself (you're good at
  this); for non-US locations just use the country or region as given. Flag any row
  you can't confidently place.

Show the user your proposed mapping (raw column → required field, plus any
defaults/assumptions) as plain text and get a quick confirmation or correction
before proceeding. Don't use multiple-choice UI for this — there are more raw
columns than a 4-option picker can hold; a short written summary is faster for them
to skim and correct.

### 4. Normalize seniority and mentee counts
Read `reference/seniority-scale.md` now. It has the canonical rank scale (recovered
from a past cycle's real data) plus known pitfalls: multi-select cells, free-text
non-answers, and why rank `0` is reserved and must never be assigned.

Build the raw-value → rank mapping from the *actual* distinct values in this file
(not a canned list) using that scale as the starting point. Print the proposed
mapping and let the user confirm/adjust. Separately list out any row whose raw value
didn't map cleanly (multi-select, free text, typos) and ask the user how to resolve
each one — don't guess silently on data that determines who mentors whom.

Do the same treatment for "how many mentees would you mentor" (default `1` for
mentors if blank, `0` if not a mentor) and for "who would you be interested in
mentoring" (reuse the same rank mapping — it's the same set of raw category labels
elsewhere in the form's multi-select; leave blank if the person isn't a mentor or
didn't answer, which the program already treats as "anyone more junior").

### 5. Normalize booleans
`is a mentor?`, `is a mentee?`, `img?`, `prefer mentoring img?` must be written as
literal `0` or `1`. Typical raw values are `Yes`/`No`/`Not applicable` — map
`Yes` → `1`, everything else → `0`. Confirm this reading with the user if the raw
values look unusual.

### 6. Write the normalized CSV
Once the mapping is confirmed, write the output with these exact lowercase headers
(order doesn't matter, `CsvParser2025` looks up by name):

```
name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?
```

Write it to `tmp/<timestamp>_normalized.csv` in the repo root (create `tmp/` if
needed — it's gitignored). Use Ruby's `CSV` library to generate it with
`row_sep: "\r\n"` — `CsvParser2025` reads with that exact row separator
(`lib/csv_parser_2025.rb:84`) and will error on plain `\n`. Quote any field that
might contain a comma (e.g. the mentee-seniority-allowlist column).

Show the user a short summary before running: counts of mentors/mentees, and any
rows you skipped or flagged.

### 7. Optional: don't repeat last year's pairings
Ask if they have last year's match results and want to avoid repeat pairings. If
so, get that file too — it's usually messier than you'd expect: real exports seen
so far have **no real header row** (just a junk title line like `Mentees,,Mentors,`)
and are purely positional (mentee name, mentee email, mentor name, mentor email).
Read a few rows defensively (same caution as step 2 — prefer Python's `csv` module),
confirm which columns are which with the user if it's not obvious from content
(e.g. which columns look like emails), then write
`tmp/<timestamp>_previous_matches.csv` with exactly these headers (any other
columns, e.g. names, are ignored by the program):

```
mentor_email,mentee_email
```

Plain `CSV` defaults are fine here (no `\r\n` requirement, unlike step 6 — that's
specific to `CsvParser2025`). A pairing is excluded regardless of which person is
mentor vs. mentee this year — if two people were matched last year in either
direction, they won't be re-paired.

### 8. Validate both CSVs before running anything
Don't hand the normalized file(s) straight to the full match — validate first by
actually parsing them with the program's own classes, so column/format problems
surface immediately instead of showing up as a confusing crash mid-run or (worse)
silently wrong results:

```
bundle exec ruby -r./lib/csv_parser_2025 -e 'CsvParser2025.parse(ARGV[0])' tmp/<timestamp>_normalized.csv
bundle exec ruby -r./lib/previous_matches -e 'PreviousMatches.parse(ARGV[0])' tmp/<timestamp>_previous_matches.csv
```

Both classes raise a clear, specific error message on bad input (missing required
column, duplicate name/email, missing seniority, invalid boolean value, etc. — see
`lib/csv_parser_2025.rb` and `lib/previous_matches.rb`). When one raises:
- If the fix is unambiguous (a typo'd header, a stray blank row, wrong row
  separator) — fix the normalized CSV yourself and re-validate. Don't ask the user
  to do something you can just do.
- If the fix is ambiguous (e.g. "found people with multiple entries" — a real
  duplicate sign-up where you can't tell which entry is authoritative) — stop, quote
  the exact error and the specific row(s), and ask the user how to resolve it.

Only move on to step 9 once both validations pass cleanly.

### 9. Run the match
```
bundle exec ruby lib/application.rb tmp/<timestamp>_normalized.csv tmp/<timestamp>_previous_matches.csv
```
(Note: `bundle exec lib/application.rb`, without `ruby`, fails with "not
executable" — the file has no shebang/exec bit. The second argument is optional —
omit it if there's no previous-matches file.)

Save the full output to `tmp/<timestamp>_results.txt` and summarize the key stats
(match %, median ranks, unmatched counts) back to the user in plain language.

For every unmatched mentee or mentor named in the output, give a one-line reason,
not just the name. The output already distinguishes two cases:
- Listed in "Filtering out N mentees/mentors with no preferences" — they had zero
  eligible counterparts (e.g. a mentee already at/near the top of the seniority
  scale with nobody strictly more senior in the mentor pool). Say so explicitly.
- Listed only in the final "Unmatched mentees/mentors" count but not filtered
  earlier — they had eligible preferences but lost out during the stable-matching
  process (their preferred matches were claimed by higher-priority competitors).

### 10. Produce a CSV of the results
Don't hand back the raw `Mentees -> Mentors:` text block from step 7 as the
deliverable — some emails contain stray `;` characters (people pasting two emails
into one field), which breaks naive splitting on that log format. Instead, derive
the pairs programmatically and write a real CSV, e.g. a small script that requires
`csv_parser_2025`, `matching`, and `preferences`, recomputes
`mentees_to_preferences`/`mentors_to_preferences` the same way `Matching.match`
does, calls `Matching.send(:gale_shapley, ...)`, and writes
`mentee_name,mentee_email,mentor_name,mentor_email` rows with Ruby's `CSV` library
(handles quoting/escaping automatically). Save it as `tmp/<timestamp>_matches.csv`
and tell the user where to find it.
