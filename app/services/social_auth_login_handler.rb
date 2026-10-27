# typed: false
# frozen_string_literal: true

# Handles social login and social sign-up from a verified provider identity.
class SocialAuthLoginHandler
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, repository:, provider:, uid:, sign_up_entry: false,
                 ceremony_started_at:)
    @principal = principal
    @credential_candidate = credential_candidate
    @repository = repository
    @provider = provider
    @uid = uid
    @sign_up_entry = sign_up_entry
    @ceremony_started_at = ceremony_started_at
  end

  # D-48 with D-72 (WU-08). L8 (an enforcement effect on the provider subject) is decided before any
  # identity lookup, for sign-in and sign-up alike.
  def call
    if enforced_subject?
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.unauthorized", check: "enforced_subject")
    end

    ClientExternalIdentity.with_subject_lock(
      provider: provider, issuer: principal.issuer, subject: uid,
    ) do
      # L5: released during this ceremony.
      if ClientExternalIdentity.released_since_ceremony?(
        provider: provider, issuer: principal.issuer, subject: uid,
        ceremony_started_at: ceremony_started_at,
      )
        raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
      end

      identity = repository.find_by_subject_for_link(uid, lock: true)
      identity ? login_existing_identity(identity) : pending_social_signup
    end
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

  attr_reader :principal, :credential_candidate, :repository, :provider, :uid, :sign_up_entry,
              :ceremony_started_at

  def login_existing_identity(identity)
    # L7: a revoked or deleted provider account stops both intents with the fixed message.
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.unauthorized", check: "identity_inactive") unless
      identity.state == "active"

    user = identity.association(:client).scope.take
    if user.blank?
      # L4
      Rails.logger.fatal(JitLogEvent.format("social_auth.identity_without_client", provider: provider))
      raise SocialAuth::IdentityInvariantError
    end
    # L6: linked to a registration that never finished.
    if user.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP
      raise SocialAuth::UnauthorizedError.new("errors.social_auth.pending_social_signup_invalid_state")
    end
    # L2: a registered subject cannot start a sign-up.
    raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict") if sign_up_entry

    # L3 (a linked Client that cannot sign in) is refused by the Sign In eligibility check itself.

    repository.refresh_credentials!(identity, principal: principal, credential_candidate: credential_candidate)
    build_result(user, identity, existing_account: true)
  end

  def enforced_subject?
    digest =
      case provider.to_s
      when "google" then EnforcementIdentifierDigest.for_google_subject(
        realm: "app", issuer: principal.issuer,
        subject: uid,
      )
      when "apple" then EnforcementIdentifierDigest.for_apple_subject(
        realm: "app", issuer: principal.issuer,
        subject: uid,
      )
      else raise ArgumentError, "unsupported social provider"
      end
    return false unless digest

    AppEnforcementIdentifierEffect.in_force
      .exists?(identifier_kind: digest[:identifier_kind], lookup_digest: digest[:lookup_digest])
  end

  def pending_social_signup
    raise SocialAuth::UnauthorizedError.new("errors.social_auth.invalid_intent") unless sign_up_entry

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
