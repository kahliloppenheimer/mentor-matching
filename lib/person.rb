# typed: strict
require 'sorbet-runtime'

extend T::Sig

class Person < T::Struct
  const :id, String
  const :name, String
  const :city, String
  const :state, String
  const :region, String
  const :seniority, String
  const :rank, Integer

  const :is_mentee, T::Boolean
  const :is_mentor, T::Boolean
  const :mentee_seniority_allowlist, T::Array[String]
end