# typed: false
# frozen_string_literal: true

# Handles social login and social sign-up from a verified provider identity.
class SocialAuthLoginHandler
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, repository:, provider:, uid:, sign_up_entry: false)
    @principal = principal
    @credential_candidate = credential_candidate
    @repository = repository
    @provider = provider
    @uid = uid
    @sign_up_entry = sign_up_entry
  end

  def call
    identity = repository.find_by_subject(uid, lock: true)
    Rails.logger.debug { "[SocialAuth] handle_login - identity found: #{identity.present?}" }

    identity ? login_existing_identity(identity) : pending_social_signup
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.race_condition",
        provider: provider,
        uid: "[FILTERED]",
        error: e.message,
      ),
    )
    raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
  end

  private

  attr_reader :principal, :credential_candidate, :repository, :provider, :uid, :sign_up_entry

  def login_existing_identity(identity)
    user = identity.user
    existing_account = user.present?
    Rails.logger.debug do
      "[SocialAuth] Existing identity - linked: #{user.present?}, orphaned: #{user.nil?}"
    end

    return pending_social_signup if user.blank?

    repository.refresh_credentials!(
      identity,
      principal: principal,
      credential_candidate: credential_candidate,
    )
    Rails.logger.debug { "[SocialAuth] Identity credentials updated" }
    build_result(user, identity, existing_account: existing_account)
  end

  def pending_social_signup
    Rails.logger.debug { "[SocialAuth] Unknown social identity requires signup confirmation" }
    {
      user: nil,
      identity: nil,
      jwt_payload: {},
      existing_account: false,
      pending_social_signup: true,
      provider: provider,
      uid: uid,
    }
  end

  def build_result(user, identity, existing_account:)
    {
      user: user,
      identity: identity,
      jwt_payload: { user_id: user.id },
      step_up_authenticated: false,
      existing_account: existing_account,
    }
  end
end
