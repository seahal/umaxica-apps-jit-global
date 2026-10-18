# typed: false
# frozen_string_literal: true

class ExternalAuthenticationLinkUseCase
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, user:, ceremony_started_at:)
    unless principal.is_a?(ExternalAuthentication::VerifiedPrincipal)
      raise ArgumentError, "verified principal is required"
    end

    @principal = principal
    @credential_candidate = credential_candidate
    @user = user
    @ceremony_started_at = ceremony_started_at
  end

  def call
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.not_logged_in") unless user

    repository = ExternalAuthentication::IdentityRepositoryFactory.current.build(principal.provider)
    repository.ensure_active_status!
    decision =
      AppPrincipalRecord.transaction do
        SocialAuthLinkHandler.call(
          principal: principal,
          credential_candidate: credential_candidate,
          current_client: user,
          repository: repository,
          provider: principal.provider,
          uid: principal.subject,
          ceremony_started_at: ceremony_started_at,
        )
      end

    ExternalAuthentication::LinkResult.new(
      status: :linked, user: decision.fetch(:user),
      identity: decision.fetch(:identity),
    )
  end

  private

  attr_reader :principal, :credential_candidate, :user, :ceremony_started_at
end
