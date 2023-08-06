# typed: strict
require 'sorbet-runtime'
require 'csv'

# Example matching class!
class Matching
  extend T::Sig

  sig {params(csv_path: String).void}
  def match(csv_path)
    rows = parse_csv(csv_path)
    puts(rows.to_s)
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
end

matching = Matching.new
matching.match('test.csv')
