# typed: strict
require 'sorbet-runtime'

extend T::Sig

class Person < T::Struct
  const :name, String
  const :city, String
  const :state, String
  const :region, String
  const :seniority, String
end