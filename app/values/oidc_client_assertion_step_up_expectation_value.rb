# frozen_string_literal: true

class OidcClientAssertionStepUpExpectationValue
  public

  attr_reader :grant, :subject

  def initialize(grant:, subject:)
    unless grant.is_a?(String) && grant.present? && subject.is_a?(String) && subject.present?
      raise ArgumentError, "step-up assertion expectation requires a grant and subject"
    end

    @grant = grant
    @subject = subject
    freeze
  end
end
