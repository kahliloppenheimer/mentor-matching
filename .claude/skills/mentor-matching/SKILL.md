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
with their sign-off at each judgment call, then run the program.

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

### 7. Run the match
```
bundle exec ruby lib/application.rb tmp/<timestamp>_normalized.csv
```
(Note: `bundle exec lib/application.rb`, without `ruby`, fails with "not
executable" — the file has no shebang/exec bit.)

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

### 8. Produce a CSV of the results
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
