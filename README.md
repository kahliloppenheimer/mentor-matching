# Mentor Matching

Matches mentors and mentees from a sign-up spreadsheet using a stable-matching
algorithm (the same kind used for medical residency matching), so pairings make
sense by seniority, location, and stated preferences.

## Option 1: Run with Claude Code (recommended)

No coding knowledge needed — Claude walks you through preparing your data and
catches mistakes along the way.

1. Install [Claude Code](https://claude.com/claude-code).
2. Open this project folder in a terminal and run `claude`.
3. Say something like: *"I have a spreadsheet of mentor/mentee sign-ups, help me
   match them."*
4. Have your sign-up CSV ready (if it's a Google Sheet or Excel file, export it as
   CSV first). Claude will ask for it, walk you through mapping your columns to
   what the program needs, and confirm anything unclear with you before running.
5. Optional: have last year's match results ready too, if you want to avoid
   repeating the same pairings.
6. Results are saved as a CSV and summarized for you in the chat.

## Option 2: Run from the command line

Use this if you're comfortable in a terminal and already have a CSV in the exact
format below.

### 1. Install
Requires [uv](https://docs.astral.sh/uv/).
```bash
uv sync --dev
```

### 2. Prepare your CSV
Your CSV needs exactly these columns (any order):

| Column | Value |
|---|---|
| `name` | Full name |
| `email` | Email address |
| `state` | State, or country if not in the US |
| `seniority` | Integer — higher means more senior |
| `is a mentor?` | `1` or `0` |
| `is a mentee?` | `1` or `0` |
| `img?` | `1` or `0` — international medical graduate |
| `prefer mentoring img?` | `1` or `0` — mentor prefers mentoring an IMG |
| `who would you be interested in mentoring?` | Comma-separated seniority integers (blank = anyone more junior) |
| `how many mentees would you be willing to mentor?` | Integer |

### 3. Run it
```bash
uv run mentor-matching path/to/signups.csv
```

Optional: add a second CSV of last year's matches to avoid repeating pairings. It
needs `mentor_email` and `mentee_email` columns (any other columns are ignored;
a pairing is excluded regardless of which person is mentor vs. mentee this year):
```bash
uv run mentor-matching path/to/signups.csv path/to/last_years_matches.csv
```

Results print to the terminal. Every run is automatically checked for validity —
look for `Stability check passed` near the end of the output. If you ever see
`STABILITY CHECK FAILED` instead, something is wrong with the program itself
(not your data) and it needs to be fixed before the results can be trusted.

## How it works, for the curious

Every applicant can be a mentor, a mentee, or both. The program ranks each
person's potential mentors/mentees by seniority closeness, location, and IMG
preference, then runs the Gale-Shapley algorithm to produce a *stable* set of
pairs: no two people who aren't matched to each other would both rather be
matched together than stick with their current assignment.

## For developers
```bash
uv run pytest    # tests
uv run mypy src tests   # type checking
```
