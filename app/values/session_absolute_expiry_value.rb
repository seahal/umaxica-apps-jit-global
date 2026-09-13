# typed: false
# frozen_string_literal: true

class SessionAbsoluteExpiryValue
  def self.cap(proposed_expiry:, absolute_expiry:)
    return proposed_expiry if unbounded?(absolute_expiry)
    return absolute_expiry if proposed_expiry.nil?

    [proposed_expiry, absolute_expiry].min
  end
  public_class_method :cap

  def self.unbounded?(expiry)
    expiry.nil? || (expiry.respond_to?(:infinite?) && expiry.infinite?)
  end

  private_class_method :unbounded?
end
