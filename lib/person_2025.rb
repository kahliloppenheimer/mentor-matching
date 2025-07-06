# typed: strict
require 'sorbet-runtime'

class Person2025 < T::Struct

  extend T::Sig

  const :id, String
  const :name, String
  const :email, String
  const :state, String
  const :seniority, Integer

  const :is_mentee, T::Boolean
  const :is_mentor, T::Boolean
  const :is_international, T::Boolean
  const :prefers_mentoring_international, T::Boolean
  prop :mentee_seniority_allowlist, T::Array[Integer]
  const :max_num_mentees, Integer

  sig {override.returns(Integer)}
  def hash
    return id.hash
  end

  sig {params(other: Person2025).returns(T::Boolean)}
  def eql?(other)
    return hash == other.hash
  end

  sig {params(other: Person2025).returns(T::Boolean)}
  def ==(other)
    return eql?(other)
  end

  sig {override.returns(String)}
  def to_s
    "#{name} (#{id})"
  end

  sig {override.returns(String)}
  def inspect
    return to_s
  end
end