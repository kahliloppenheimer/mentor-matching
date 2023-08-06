# typed: strict
require 'sorbet-runtime'

# Example matching class!
class Matching
  extend T::Sig

  sig do
    params(a: Integer, b: Integer).returns(Integer)
  end
  def self.plus(a, b)
    a + b
  end
end

puts(Matching.plus(1, 2))
