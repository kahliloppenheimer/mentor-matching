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
      schema_val = case header
      when NameCol,
        CityCol,
        StateCol,
        RegionCol,
        SeniorityCol
        i
      end

      schema[header] = i
    end

    if !schema.keys.include?(NameCol) \
      || !schema.keys.include?(CityCol) \
      || !schema.keys.include?(StateCol) \
      || !schema.keys.include?(RegionCol) \
      || !schema.keys.include?(SeniorityCol)
      raise "Could not find all schema values! Only found: #{schema.keys}"
    end

    schema
  end

  sig do
    params(schema: T::Hash[String, Integer], row: T::Array[T.nilable(String)]).returns(Person)
  end
  private_class_method def self.parse_person(schema, row)
    begin 
      Person.new(
        id: T.let(SecureRandom.alphanumeric, String),
        name: T.must(row.fetch(schema.fetch(NameCol))),
        city: T.must(row.fetch(schema.fetch(CityCol))),
        state: T.must(row.fetch(schema.fetch(StateCol))),
        region: T.must(row.fetch(schema.fetch(RegionCol))),
        seniority: T.must(row.fetch(schema.fetch(SeniorityCol))),
      )
    rescue TypeError 
      raise "Found nil value when parsing row: #{row}"
    end
  end
end