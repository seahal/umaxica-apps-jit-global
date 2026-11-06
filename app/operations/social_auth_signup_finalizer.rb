# typed: false
# frozen_string_literal: true

class SocialAuthSignupFinalizer
  def self.call(...)
    new(...).call
  end

  # adr/sign-up-finalization-in-auth.md F3: the pending Client created at the confirmation gets its
  # External Identity and its registered status in one principal transaction.
  def initialize(user:, principal:, credential_candidate:, ceremony_started_at:, flow:)
    @user = user
    @principal = principal
    @credential_candidate = credential_candidate
    @ceremony_started_at = ceremony_started_at
    @flow = flow
  end

  def call
    validate_principal!

    AppSignUpRegistrationCommitter.call!(flow: @flow, client: user, method: provider) do
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
    { user: user, identity: repository.find_for_user(user) }
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
    verify_flow_evidence!
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

  def verify_flow_evidence!
    evidence = @flow.completed_requirements.fetch("social_signup")
    digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, [provider, uid].join(":"))
    unless @flow.social_provider == provider && @flow.pending_contact_type == "social_identity" &&
        evidence.fetch("provider") == provider && evidence.fetch("uid_digest") == digest &&
        ceremony_started_at == @flow.issued_at
      raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
    end
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
