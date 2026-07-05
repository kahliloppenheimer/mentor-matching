# Canonical seniority scale

`lib/csv_parser_2025.rb` needs `seniority` as a plain integer (higher = more senior).
This scale is the one actually used for the prior matching cycle (recovered from the
legend embedded in a past raw export) — start from it instead of inventing a new one,
and only deviate if the current raw file's categories don't fit.

| Rank | Category |
|------|----------|
| 1 | Medical student (MS1 or MS2) |
| 2 | Medical student (MS3 or MS4) |
| 3 | PGY1 |
| 4 | PGY2 |
| 5 | PGY3 |
| 6 | PGY4 |
| 7 | Fellow |
| 8 | Early Career Psychiatrist (ECP) |
| 9 | Psychiatrist (attending, 7+ years) |
| 10 | Nurse Practitioner |
| 11 | Nurse Practitioner Student |
| 12 | Physician Assistant |
| 13 | Physician Assistant Student |
| 14 | IMG student |
| 15 | IMG graduate |
| 16 | Social Worker |
| 17 | Psychologist / Therapist |
| 18 | Peer Specialist |
| 19 | Retired |

Notes:
- **Never assign rank 0.** `CsvParser2025` treats a mentee-seniority-allowlist of
  literally `"0"` as a sentinel meaning "no restriction — mentor anyone more junior,"
  not a real category. Keep the scale 1-indexed to avoid colliding with that.
- Raw exports rarely match these labels exactly. Build a per-run mapping from the
  *actual* distinct values found in the file to this scale, e.g.:
  - `"Medical student (MS3 or MS4)"` → 2
  - `"Early Career Psychiatrist"` → 8
  - `"Psychiatrist (with 7+ years of experience)"` → 9
- Real exports contain free-text and multi-select junk that won't map cleanly, e.g.:
  - Multiple selections in one cell (`"Fellow, Early Career Psychiatrist"`) — ask the
    user how to resolve (default recommendation: take the higher/more-senior rank,
    since that's the more conservative choice for a self-reported ambiguous answer).
  - Ambiguous free text (`"IMG, beyond MS4 but not yet PGY1"`, `"First year of
    internship in Ain Shams, Egypt equivalent of a sixth year medical student"`) —
    don't guess silently. Show these rows to the user and ask for a ruling.
  - Stray non-answers (`"."`, `"all that applies"`) in multi-select fields — treat as
    no selection, not a category.

The "how many mentees would you mentor" column uses a much smaller scale:
`0 = not a mentor`, otherwise the plain integer count. Default to `1` if blank/absent
for anyone who is a mentor. Watch for free text here too (`"Ideally 1 ... but I'd
mentor more if needed"`, `"5-6"`, `"1, 2"`) — pick the most defensible single integer
(first number of a range, first number if a list) and flag it to the user rather than
silently averaging or guessing.
