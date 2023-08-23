# typed: strict
require 'sorbet-runtime'
require 'csv'
require 'securerandom'
require './lib/person'

class CsvParser

  extend T::Sig

  NameCol = 'name'
  CityCol = 'city'
  StateCol = 'state'
  RegionCol = 'region'
  SeniorityCol = 'seniority'
  IsMenteeCol = 'is a mentee?'
  IsMentorCol = 'is a mentor?'
  MentorSeniorityAllowlistCol = 'only mentors'
  MentorRegionDenylistCol = 'mentor region denylist'
  MenteeRegionDenylistCol = 'mentee region denylist'

  # Interests (should refactor to be more modular)
  ChildPsychInterestCol = 'child psych interest'
  ResearchInterestCol = 'research interest'
  LeadershipInterestCol = 'leadership interest'
  AcademicMedInterestCol = 'academic med interest'
  ForensicsInterestCol = 'forensics'
  AddictionInterestCol = 'addiction'
  DeiInterestCol = 'dei'
  WomensMentalHealthCol = "women's mental health"

  AllCols = T.let([
    NameCol,
    CityCol,
    StateCol,
    RegionCol,
    SeniorityCol,
    IsMentorCol,
    IsMenteeCol,
    MentorSeniorityAllowlistCol,
    MentorRegionDenylistCol,
    MenteeRegionDenylistCol,
    ChildPsychInterestCol,
    ResearchInterestCol,
    LeadershipInterestCol,
    AcademicMedInterestCol,
    ForensicsInterestCol,
    AddictionInterestCol,
    DeiInterestCol,
    WomensMentalHealthCol
  ],
  T::Array[String])

  sig do
    params(csv_path: String).returns(T::Array[Person])
  end
  def self.parse(csv_path)
    rows = parse_csv_into_arrays(csv_path)
    headers = rows[0]
    csv_schema = parse_csv_schema(T.must(headers))
    T.must(rows[1..])
      .reject { |row| row.all?(&:nil?) }
      .map { |row| parse_person(csv_schema, row) }
      .compact
  end

  sig do
    params(csv_path: String).returns(T::Array[T::Array[T.nilable(String)]])
  end
  private_class_method def self.parse_csv_into_arrays(csv_path)
    CSV.read(csv_path).map do |row|
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
        raise "Could not find column: `#{column}` in CSV."
      end
    end

    schema
  end

  sig do
    params(schema: T::Hash[String, Integer], row: T::Array[T.nilable(String)]).returns(T.nilable(Person))
  end
  private_class_method def self.parse_person(schema, row)
    seniority = row[schema.fetch(SeniorityCol)]

    skip_message = "Skipping #{row.fetch(schema.fetch(NameCol))} because of missing values."

    if seniority.nil?
      puts(skip_message)
      return nil
    end

    rank = rank(seniority)
    if rank.nil?
      puts(skip_message)
      return nil
    end

    is_mentee = (row[schema.fetch(IsMenteeCol)] || "yes") == "yes"
    is_mentor = (row[schema.fetch(IsMentorCol)] || "yes") == "yes"
    mentee_seniority_allowlist = (row[schema.fetch(MentorSeniorityAllowlistCol)] || "").split(",").map(&:strip)
    mentor_region_denylist = (row[schema.fetch(MentorRegionDenylistCol)] || "").split(",").map(&:strip)
    mentee_region_denylist = (row[schema.fetch(MenteeRegionDenylistCol)] || "").split(",").map(&:strip)

    interests = [
      row[schema.fetch(ChildPsychInterestCol)],
      row[schema.fetch(ResearchInterestCol)],
      row[schema.fetch(LeadershipInterestCol)],
      row[schema.fetch(AcademicMedInterestCol)],
      row[schema.fetch(ForensicsInterestCol)],
      row[schema.fetch(AddictionInterestCol)],
      row[schema.fetch(DeiInterestCol)],
      row[schema.fetch(WomensMentalHealthCol)],
    ].compact

    begin 
      Person.new(
        id: T.let(SecureRandom.alphanumeric, String),
        name: T.must(row.fetch(schema.fetch(NameCol))),
        city: T.must(row.fetch(schema.fetch(CityCol))),
        state: T.must(row.fetch(schema.fetch(StateCol))),
        region: T.must(row.fetch(schema.fetch(RegionCol))),
        seniority: seniority,
        rank: rank,
        is_mentee: is_mentee,
        is_mentor: is_mentor,
        mentee_seniority_allowlist: mentee_seniority_allowlist,
        mentor_region_denylist: mentor_region_denylist,
        mentee_region_denylist: mentee_region_denylist,
        interests: interests
      )
    end
  end

  sig {params(seniority: String).returns(T.nilable(Integer))}
  private_class_method def self.rank(seniority)
    case seniority
    when 'psychiatrist'
      5
    when 'ecp'
      4
    when 'fellow'
      3
    when 'resident'
      2
    when 'ms34'
      1
    when 'ms12'
      0
    else
      puts "Found unknown seniority value: #{seniority}"
      return nil
    end
  end
end