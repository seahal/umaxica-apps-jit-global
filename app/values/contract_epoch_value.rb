# typed: false
# frozen_string_literal: true

# The release/profile epoch is a signed protocol fact. It is distinct from an actor's
# authentication epoch, which records an identity stop and recovery boundary.
class ContractEpochValue
  MINIMUM = 1

  class Invalid < ArgumentError; end

  class << self
    public

    def coerce(value)
      integer = value.is_a?(Integer) ? value : Integer(value, 10)
      raise Invalid, "contract epoch must be positive" if integer < MINIMUM

      integer
    rescue TypeError, ArgumentError
      raise Invalid, "contract epoch must be a positive integer"
    end

    def valid?(value)
      coerce(value)
      true
    rescue Invalid
      false
    end
  end
end
