# typed: strict
require 'sorbet-runtime'
require 'csv'
require './person'

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
    T.must(rows[1..]).map { |row| parse_person(csv_schema, row) }
  end

  sig do
    params(csv_path: String).returns(T::Array[T::Array[String]])
  end
  private_class_method def self.parse_csv_into_arrays(csv_path)
    CSV.read(csv_path).map do |row|
      row.map do |value|
        new_value = value&.downcase&.strip
        if new_value.nil? || new_value.empty?
          raise "Found empty value while parsing CSV. row=#{row}"
        end
        new_value
      end
    end
  end

  sig {params(headers: T::Array[String]).returns(T::Hash[String, Integer])}
  private_class_method def self.parse_csv_schema(headers)
    schema = T.let({}, T::Hash[String, Integer])
    headers.each_with_index do |header, i|
      schema_val = case header
      when NameCol,
        CityCol,
        StateCol,
        RegionCol,
        SeniorityCol
        i
      else
        raise 'Found unexpected CSV header: #{header}'
      end

      schema[header] = i
    end
    schema
  end

  sig do
    params(schema: T::Hash[String, Integer], row: T::Array[String]).returns(Person)
  end
  private_class_method def self.parse_person(schema, row)
    Person.new(
      name: row.fetch(schema.fetch(NameCol)),
      city: row.fetch(schema.fetch(CityCol)),
      state: row.fetch(schema.fetch(StateCol)),
      region: row.fetch(schema.fetch(RegionCol)),
      seniority: row.fetch(schema.fetch(SeniorityCol)),
    )
  end
end