# typed: false
# frozen_string_literal: true

# The lifecycle vocabulary shared by the six concrete, surface-local lifecycle records.
class AuthorityResourceLifecycleStateValue
  ACTIVE = "active"
  INACTIVE = "inactive"
  DISCARDED = "discarded"
  DELETED = "deleted"
  RETAINED = "retained"
  VALUES = [ACTIVE, INACTIVE, DISCARDED, DELETED, RETAINED].freeze

  def self.normalize(value)
    normalized = value.to_s
    return normalized if VALUES.include?(normalized)

    raise ArgumentError, "unsupported authority resource lifecycle state: #{value.inspect}"
  end
  public_class_method :normalize
end
