# typed: strict
require 'sorbet-runtime'
require 'csv'

# Example matching class!
class Matching
  extend T::Sig

  NameCol = 'name'
  CityCol = 'city'
  StateCol = 'state'
  RegionCol = 'region'
  SeniorityCol = 'seniority'

  class Person < T::Struct
    const :name, String
    const :city, String
    const :state, String
    const :region, String
    const :seniority, String
  end

  sig {params(csv_path: String).void}
  def match(csv_path)
    rows = parse_csv(csv_path)
    headers = rows[0]
    csv_schema = parse_csv_schema(T.must(headers))
    people = T.must(rows[1..]).map { |row| parse_person(csv_schema, row) }

    puts("Headers:\n#{headers.to_s}")
    puts("\nPeople:\n#{people.map(&:serialize).join("\n")}")
  end

  sig do
    params(csv_path: String).returns(T::Array[T::Array[String]])
  end
  private def parse_csv(csv_path)
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
  private def parse_csv_schema(headers)
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
  private def parse_person(schema, row)
    Person.new(
      name: row.fetch(schema.fetch(NameCol)),
      city: row.fetch(schema.fetch(CityCol)),
      state: row.fetch(schema.fetch(StateCol)),
      region: row.fetch(schema.fetch(RegionCol)),
      seniority: row.fetch(schema.fetch(SeniorityCol)),
    )
  end
end

matching = Matching.new
matching.match('test-inputs.csv')
