# typed: false
# frozen_string_literal: true

class ExternalAuthenticationSignupUseCase
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, birthdate:, ceremony_started_at:)
    unless principal.is_a?(ExternalAuthentication::VerifiedPrincipal)
      raise ArgumentError, "verified principal is required"
    end

    @principal = principal
    @credential_candidate = credential_candidate
    @birthdate = birthdate
    @ceremony_started_at = ceremony_started_at
  end

  def call
    decision = SocialAuthSignupFinalizer.call(
      principal: principal,
      credential_candidate: credential_candidate,
      birthdate: birthdate,
      ceremony_started_at: ceremony_started_at,
    )
    ExternalAuthentication::SignupResult.new(
      status: :created,
      user: decision.fetch(:user),
      identity: decision.fetch(:identity),
    )
  end

  private

  attr_reader :principal, :credential_candidate, :birthdate, :ceremony_started_at
end
