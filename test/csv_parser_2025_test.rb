# typed: false
require 'minitest/autorun'
require 'tempfile'
require './lib/csv_parser_2025'

class CsvParser2025Test < Minitest::Test
  def test_parse_accepts_lf_line_endings
    with_csv(
      "name,email,state,seniority,is a mentor?,is a mentee?,img?,prefer mentoring img?,who would you be interested in mentoring?,how many mentees would you be willing to mentor?\n" \
      "Alice,alice@example.com,ny,4,1,0,0,0,,1\n"
    ) do |path|
      people = CsvParser2025.parse(path)
      assert_equal(1, people.size)
      assert_equal('alice@example.com', people.first.email)
    end
  end

  private

  def with_csv(contents)
    file = Tempfile.new(['people_2025', '.csv'])
    file.write(contents)
    file.close
    yield file.path
  ensure
    file&.unlink
  end
end
