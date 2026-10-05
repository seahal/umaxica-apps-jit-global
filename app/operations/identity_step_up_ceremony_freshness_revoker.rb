# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyFreshnessRevoker
  def self.call!(token)
    new(token).call!
  end

  def initialize(token)
    @token = token
  end

  def call!
    unless token.is_a?(ClientToken) || token.is_a?(VisitorToken) || token.is_a?(OperatorToken)
      raise ArgumentError, "unsupported step-up token"
    end

    token.revoke_step_up_authority!
  end

  private

  attr_reader :token
end
