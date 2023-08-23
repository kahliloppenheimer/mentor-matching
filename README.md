## Stable mentor matching

### High Level Description
This is a Ruby program that matches psychiatry mentors and mentees from a pool of interested applicants.

First, for each applicant, the program looks at their seniority (e.g. Psychiatrist, Fellow, Resident, Medical student, etc.) to determine who might make a good mentor or mentee. It also looks at the locations of each application (i.e. what geographic region they are located in) and their interests (e.g. are they interested in Child Psychiatry? Research?). With all of this information in hand, the program generates a list of preferred mentors and mentees for each applicant.

With a ranked list of automatically computed mentor/mentee preferences for each applicant, the program runs the famous Gale Shapley algorithm for stable matching--this is the noble-prize winning algorithm also used by the residency match process. The algorithm has been tweaked to work with our use case. Mentor matching is a bit interesting and different from, say, resident matching. One person is both a mentor and mentee. And their potential mentors/mentees are all chosen from one big pool. In resident matching, residents and residency programs are two separate pools, and they everyone has just one role.

The program then outputs a configuration of stable matches that satisfy the following guarantee: no mentor is matched with a mentee for whom they both would prefer each other to their current matching. Again, "prefer each other" is determined by the automated preferences the program generates based on seniority (preferring people close in seniority), location (preferring people close together), and interests (preferring people with similar interests).

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
```
bundle
ruby exec application ~/path_to_csv.csv
```

### Expected CSV columns
```
Name, City, State, Region, Seniority, Child Psych Interest, Research Interest, Leadership Interest, Academic Med Interest, Forensics Addiction, DEI, Women's mental health, Is a mentee?, Is a mentor?, Only Mentors, Person Denylist, Mentor Region Denylist, Mentee Region Denylist
```