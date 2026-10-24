# typed: false
# frozen_string_literal: true

class SocialAuthSignupFinalizer
  def self.call(...)
    new(...).call
  end

  # adr/sign-up-finalization-in-auth.md F3: the pending Client created at the confirmation gets its
  # External Identity and its registered status in one principal transaction.
  def initialize(user:, principal:, credential_candidate:, ceremony_started_at:)
    @user = user
    @principal = principal
    @credential_candidate = credential_candidate
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

  attr_reader :user, :principal, :credential_candidate, :ceremony_started_at

  def create_signup_identity!
    repository.ensure_active_status!
    existing_identity = repository.find_by_subject(uid, lock: true)
    raise SocialAuth::ProviderError.new("errors.social_auth.identity_conflict") if existing_identity&.user_id.present?

    user.lock!
    raise ActiveRecord::RecordNotSaved, "pending client is unavailable" unless
      user.status_id == ClientStatus::UNVERIFIED_WITH_SIGN_UP

    identity = existing_identity || repository.build_for_user(
      user: user, principal: principal, credential_candidate: credential_candidate,
    )
    identity.user = user
    identity.save!
    identity.touch_authenticated!
    user.update!(status_id: ClientStatus::VERIFIED_WITH_SIGN_UP)
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
end
