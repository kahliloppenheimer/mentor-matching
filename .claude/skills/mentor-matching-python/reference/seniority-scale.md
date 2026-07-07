# Canonical seniority scale

The Python matcher needs `seniority` as a plain integer (higher = more senior).
This scale is the one actually used for the prior matching cycle and is the right
starting point unless the current file's categories clearly require adjustment.

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
- Never assign rank `0`. The matcher treats a literal `"0"` allowlist specially as
  "no restriction".
- Build a per-run mapping from the actual raw values found in the file.
- For ambiguous multi-select or free-text values, ask the user instead of silently
  guessing.
- For mentee counts, pick the most defensible single integer and flag it if the raw
  value is messy.
