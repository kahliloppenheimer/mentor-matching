## Mentor matching!

Python script that takes in CSV with the following schema and matches mentors with mentees.

```
Name, City, State, Region, Seniority

Julia, NYC, NY, MA, Doctor
Robin, LA, CA, WC, Medical student
Hannah, NYC, NY, MA, Medical student
Kahlil, SF, CA, WC, Resident 
```

=>

```
Mentor, Mentee

Julia, Hannah
Kahlil, Robin
```

## Run the included example
ruby lib/application.rb data/test-inputs.csv
