# typed: strict
require 'sorbet-runtime'
require 'csv'
require 'securerandom'
require './lib/person_2025'

# CSV parser for a new schema of CSV data (2025).
class CsvParser2025

  extend T::Sig

  NameCol = 'name'
  EmailCol = 'email'
  StateCol = 'state'
  SeniorityCol = 'seniority'
  IsMentorCol = 'is a mentor?'
  IsMenteeCol = 'is a mentee?'
  IsInternationalCol = "img?"
  PrefersMentoringInternationalCol = "prefer mentoring img?"
  MenteeSeniorityAllowlistCol = 'who would you be interested in mentoring?'
  MaxNumMenteesCol = 'how many mentees would you be willing to mentor?'

  AllCols = T.let([
    NameCol,
    EmailCol,
    StateCol,
    SeniorityCol,
    IsMentorCol,
    IsMenteeCol,
    IsInternationalCol,
    PrefersMentoringInternationalCol,
    MenteeSeniorityAllowlistCol,
    MaxNumMenteesCol
  ],
  T::Array[String])

  sig do
    params(csv_path: String).returns(T::Array[Person2025])
  end
  def self.parse(csv_path)
    rows = parse_csv_into_arrays(csv_path)
    headers = rows[0]
    csv_schema = parse_csv_schema(T.must(headers))
    people = T.must(rows[1..])
      .reject { |row| row.all?(&:nil?) }
      .map { |row| parse_person(csv_schema, row) }
      .compact
    
    people_with_multiple_names = (people.group_by(&:name).select{|_, group| group.size > 1}.map {|name, _| name})
    if people_with_multiple_names.size > 0
      raise "Found people with multiple entries:\n#{people_with_multiple_names}"
    end

    people_with_multiple_emails = (people.group_by(&:email).select{|_, group| group.size > 1}.map {|email, _| email})
    if people_with_multiple_emails.size > 0
      raise "Found people with multiple entries:\n#{people_with_multiple_emails}"
    end

    people = people.map{|person| correct_mentee_seniority_allowlist(person)} 

    people_with_incorrect_mentee_preferences = people.select{|person| person.mentee_seniority_allowlist.any?{|preferred_seniority| preferred_seniority >= person.seniority}}
    if people_with_incorrect_mentee_preferences.size > 0
      raise "Found people with incorrect mentee preferences:\n#{people_with_incorrect_mentee_preferences.map(&:email)}"
    end

    return people
  end

  sig do
    params(person: Person2025).returns(Person2025)
  end
  private_class_method def self.correct_mentee_seniority_allowlist(person)
    allowlist = person.mentee_seniority_allowlist

    person.mentee_seniority_allowlist = allowlist.select{|seniority| seniority < person.seniority}

    return person
  end

  sig do
    params(csv_path: String).returns(T::Array[T::Array[T.nilable(String)]])
  end
  private_class_method def self.parse_csv_into_arrays(csv_path)
    CSV.read(csv_path, row_sep: "\r\n").map do |row|
      row.map do |value|
        value&.downcase&.strip
      end
    end
  end

  sig {params(headers: T::Array[T.nilable(String)]).returns(T::Hash[String, Integer])}
  private_class_method def self.parse_csv_schema(headers)
    schema = T.let({}, T::Hash[String, Integer])
    headers.each_with_index do |header, i|
      if header.nil?
        next
      end
      if AllCols.include?(header)
        schema[header] = i
      end
    end

    AllCols.each do |column|
      if !schema.keys.include?(column)
        raise "Could not find column: `#{column}` in CSV. Only found headers: #{headers}"
      end
    end

    schema
  end

  # Parses a boolean col in the CSV that is 0 (false) or 1 (true)
  sig {params(val: String).returns(T::Boolean)}
  private_class_method def self.parse_boolean_col(val)
    num = val.to_i
    case num
    when 0
      return false
    when 1
      return true
    else
      raise "Invalid boolean value found: #{val}"
    end
  end

  sig do
    params(schema: T::Hash[String, Integer], row: T::Array[T.nilable(String)]).returns(T.nilable(Person2025))
  end
  private_class_method def self.parse_person(schema, row)
    seniority = row[schema.fetch(SeniorityCol)]&.to_i

    skip_message = "Skipping #{row.fetch(schema.fetch(NameCol))} because of missing values."

    if seniority.nil?
      raise "Row is missing seniority:\n#{row}"
    end

    is_mentee = parse_boolean_col(T.must(row[schema.fetch(IsMenteeCol)]))
    is_mentor = parse_boolean_col(T.must(row[schema.fetch(IsMentorCol)]))
    is_international = parse_boolean_col(T.must(row[schema.fetch(IsInternationalCol)]))
    prefers_mentoring_international = parse_boolean_col(T.must(row[schema.fetch(PrefersMentoringInternationalCol)]))

    mentee_seniority_allowlist = (row[schema.fetch(MenteeSeniorityAllowlistCol)] || "").split(",").map(&:strip).map(&:to_i)

    if mentee_seniority_allowlist.size == 1 && mentee_seniority_allowlist[0] == 0
      mentee_seniority_allowlist = (0...seniority).to_a
    end
    
    max_num_mentees_str = T.must(row.fetch(schema.fetch(MaxNumMenteesCol)))
    max_num_mentees = T.must(max_num_mentees_str.split(';').map(&:to_i).max)

    return Person2025.new(
      id: T.let(SecureRandom.alphanumeric, String),
      name: T.must(row.fetch(schema.fetch(NameCol))).downcase,
      email: T.must(row.fetch(schema.fetch(EmailCol))).downcase,
      state: T.must(row.fetch(schema.fetch(StateCol))).downcase,
      seniority: seniority,
      is_mentee: is_mentee,
      is_mentor: is_mentor,
      is_international: is_international,
      prefers_mentoring_international: prefers_mentoring_international,
      mentee_seniority_allowlist: mentee_seniority_allowlist,
      max_num_mentees: max_num_mentees
    )
  end
end