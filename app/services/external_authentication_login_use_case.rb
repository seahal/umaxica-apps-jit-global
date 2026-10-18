# typed: false
# frozen_string_literal: true

class ExternalAuthenticationLoginUseCase
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, sign_up_entry:, ceremony_started_at:)
    unless principal.is_a?(ExternalAuthentication::VerifiedPrincipal)
      raise ArgumentError, "verified principal is required"
    end

    @principal = principal
    @credential_candidate = credential_candidate
    @sign_up_entry = sign_up_entry == true
    @ceremony_started_at = ceremony_started_at
  end

  def call
    repository = ExternalAuthentication::IdentityRepositoryFactory.current.build(principal.provider)
    repository.ensure_active_status!

    decision =
      AppPrincipalRecord.transaction do
        SocialAuthLoginHandler.call(
          principal: principal,
          credential_candidate: credential_candidate,
          repository: repository,
          provider: principal.provider,
          uid: principal.subject,
          sign_up_entry: sign_up_entry,
          ceremony_started_at: ceremony_started_at,
        )
      end

    if decision[:pending_social_signup]
      ExternalAuthentication::LoginResult.new(
        status: :signup_required,
        user: nil,
        identity: nil,
        existing_account: false,
      )
    else
      ExternalAuthentication::LoginResult.new(
        status: :authenticated,
        user: decision.fetch(:user),
        identity: decision.fetch(:identity),
        existing_account: decision.fetch(:existing_account),
      )
    end
  end

  private

  attr_reader :principal, :credential_candidate, :sign_up_entry, :ceremony_started_at
end
