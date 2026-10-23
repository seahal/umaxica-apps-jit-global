# typed: false
# frozen_string_literal: true

class SocialAuthSignupFinalizer
  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, birthdate:, ceremony_started_at:)
    @principal = principal
    @credential_candidate = credential_candidate
    @birthdate = birthdate
    @ceremony_started_at = ceremony_started_at
  end

  def call
    validate_principal!

    AppPrincipalRecord.transaction do
      ClientExternalIdentity.with_subject_lock(
        provider: provider, issuer: principal.issuer, subject: uid,
      ) do
        if ClientExternalIdentity.released_since_ceremony?(
          provider: provider, issuer: principal.issuer, subject: uid,
          ceremony_started_at: ceremony_started_at,
        )
          raise SocialAuth::ProviderError.new("errors.social_auth.identity_conflict")
        end

        create_signup_identity!
      end
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
    Rails.logger.error(
      JitLogEvent.format(
        "social_auth.signup_finalizer.failed",
        error_class: e.class.name,
        record_class: e.respond_to?(:record) ? e.record&.class&.name : nil,
        record_errors: e.respond_to?(:record) ? e.record&.errors&.full_messages : nil,
      ),
    )
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  private

  attr_reader :principal, :credential_candidate, :birthdate, :ceremony_started_at

  def create_signup_identity!
    ensure_signup_reference_defaults!
    repository.ensure_active_status!
    existing_identity = repository.find_by_subject(uid, lock: true)
    raise SocialAuth::ProviderError.new("errors.social_auth.identity_conflict") if existing_identity&.user_id.present?

    user = build_user
    user.save!

    identity = existing_identity || repository.build_for_user(
      user: user, principal: principal, credential_candidate: credential_candidate,
    )
    identity.user = user
    identity.save!
    identity.touch_authenticated!
    ClientSocialAuditOutbox.record!(identity: identity, owner: user, event_name: "linked")

    { user: user, identity: identity }
  end

  def validate_principal!
    return if principal.is_a?(ExternalAuthentication::VerifiedPrincipal)

    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  def provider
    @provider ||= principal.provider
  end

  def uid
    @uid ||= principal.subject
  end

  def repository
    @repository ||= ExternalAuthentication::IdentityRepositoryFactory.current.build(provider)
  end

  def build_user
    Client.new(
      birthdate: birthdate,
      status_id: ClientStatus::VERIFIED_WITH_SIGN_UP,
      visibility_id: default_visibility_id,
      # adr/authentication-security-mode.md B1: APP sign-up starts in NORMAL.
      security_mode_id: ClientSecurityMode::NORMAL,
      mfa_status_id: default_mfa_status_id,
    )
  end

  def default_visibility_id
    ClientVisibility::STAFF
  end

  def default_mfa_status_id
    ClientMfaStatus::UNCONFIGURED
  end

  def ensure_signup_reference_defaults!
    [
      ClientStatus,
      ClientVisibility,
      ClientMfaStatus,
    ].each { |klass| klass.ensure_defaults! if klass.respond_to?(:ensure_defaults!) }
  end
end
