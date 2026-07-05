## Stable mentor matching

### High Level Description
This is a Ruby program that matches psychiatry mentors and mentees from a pool of interested applicants.

First, for each applicant, the program looks at their seniority (e.g. Psychiatrist, Fellow, Resident, Medical student, etc.) and the seniorities of everyone else to find eligible pairings. Mentors only mentor people with a lower seniority, and mentees are only matched with people with a higher seniority. The program also looks at the locations of each application (i.e. "New York" vs "Michigan") and their interests (e.g. are they interested in Child Psychiatry? Research?). With all of this information in hand, the program generates a sorted rank list of preferred mentors and mentees for each applicant.

With a ranked list of automatically computed mentor/mentee preferences for each applicant, the program runs the famous Gale Shapley algorithm for stable matching. This is the same noble-prize winning algorithm also used by the notorious residency match process.

A quick note, the algorithm has been tweaked a tiny bit to work for mentor matching specifically. Mentor matching is a bit interesting and different from resident matching. In mentor matching, there is just one pool of applications, and each person can be both a mentor and a mentee. In residency matching there are two pools (residents and programs) and each program can house multiple residents. The fundamental premise of the algorithm remains the same, but some of the technical implementation varies to accommmodate this.

The final output of the program is a configuration of stable matches that satisfy the following guarantee: no unmatched mentor and mentee exist for whom they both would prefer each other to their current matching. Again, "prefer each other" is determined by the preferences the program computes based on seniority (preferring people close in seniority), location (preferring people close together), and interests (preferring people with similar interests).

### Overview
This is a Ruby program to perform Stable Mentor Matching! This is a fun variant of the famous stable marriage problem with the following tweaks:

- Anyone can be _both_ or _one of_ a mentor and mentee
- The pool for everyone to match with is...everyone (e.g. not two separate groups)
- A person's preferences for their mentor is _different_ than their preferences for their mentee

The program uses a variant of the famous Gale Shepley algorithm. It is tweaked to allow for:

- Assymetric preferences (i.e. a mentor can have a mentee on their preference list who does not reciprocally have that mentor on their list)
- Contextual prefernces (i.e. a person's mentor preferences are different than their mentee preferences)

At a high level, the program does the following:

1. Parse the CSV data into a useful internal representation of `Person` objects.
2. For each `Person` who should be considered a mentor, order all potential mentees and store this list as their preferences.
  a. Eligible mentees are determined as anyone who has a lower seniority rank than the mentor
  b. Eligible mentors are anyone above the lowest seniority with a `yes` value for `Is a Mentor?`

### How to run

There are two ways to run this, depending on whether you're comfortable in a
terminal or want help preparing your data first.

#### Option 1: Run as a script
Use this if you already have a CSV matching the exact columns below.
```
bundle
bundle exec ruby lib/application.rb ~/path_to_csv.csv [~/path_to_previous_matches.csv]
```

##### Expected CSV columns
```
name, email, state, seniority, is a mentor?, is a mentee?, img?, prefer mentoring img?, who would you be interested in mentoring?, how many mentees would you be willing to mentor?
```
- `seniority`: integer, higher = more senior
- `is a mentor?` / `is a mentee?` / `img?` / `prefer mentoring img?`: `0` or `1`
- `who would you be interested in mentoring?`: comma-separated seniority integers
  (blank = anyone more junior)
- `how many mentees would you be willing to mentor?`: integer (or semicolon-separated
  list; the max is used)

##### Optional: avoid repeating last year's pairings
Pass a second CSV of previous matches to prevent the same mentor/mentee pairing from
repeating. It needs `mentor_email` and `mentee_email` columns (any other columns are
ignored); a pairing is excluded regardless of which person is mentor vs. mentee this
year.

#### Option 2: Run as a Claude Code skill
Use this if you have a raw spreadsheet export (Google Forms/Sheets, Excel) that
doesn't already match the columns above — no coding knowledge required.

1. Install [Claude Code](https://claude.com/claude-code) and open this repo's folder
   with it (`claude` in a terminal, from this directory).
2. Tell it what you want, e.g. "I have a spreadsheet of mentor/mentee sign-ups, help
   me match them." It'll ask for your CSV, walk you through mapping and cleaning up
   your columns, confirm anything ambiguous with you, then run the match.
3. Results are saved under `tmp/` and summarized back to you in the chat.

See `.claude/skills/mentor-matching/SKILL.md` for exactly what it does.
