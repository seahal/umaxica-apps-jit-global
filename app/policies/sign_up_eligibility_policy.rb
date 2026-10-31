# typed: false
# frozen_string_literal: true

# ADR `sign-up-one-day-minimum-age-and-feature-level-age-restrictions` (R-AU-50): sign-up on
# `.app` and `.org` establishes identity and does not gate on age. A birthdate is eligible only
# when it is at least one calendar day before the service date of the check: yesterday is the
# closest eligible date, today is refused on purpose (an unattended submission produces it), and
# tomorrow or later was already invalid and now meets the same boundary. Feature-level age rules
# (for example an adult-content gate) are each feature's own concern and must not reuse this.
class SignUpEligibilityPolicy
  SURFACES = %i(app org).freeze
  private_constant :SURFACES

  def self.eligible?(birthdate, surface:, today: Time.zone.today)
    validate_surface!(surface)

    birthdate = AgeEligibility.birthdate_for_age(birthdate)
    birthdate.present? && birthdate < today
  end

  def self.supported_surface?(surface)
    return false unless surface.is_a?(String) || surface.is_a?(Symbol)

    SURFACES.include?(surface.to_sym)
  end

  class << self
    private

    def validate_surface!(surface)
      return if supported_surface?(surface)

      raise ArgumentError, "unsupported sign-up eligibility surface: #{surface.inspect}"
    end
  end
end
