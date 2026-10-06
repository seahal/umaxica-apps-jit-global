# typed: false
# frozen_string_literal: true

# Handles account-linking for an authenticated client.
class SocialAuthLinkHandler
  Result = Data.define(:user, :identity, :jwt_payload, :step_up_authenticated, :existing_account)

  def self.call(...)
    new(...).call
  end

  def initialize(principal:, credential_candidate:, current_client:, repository:, provider:, uid:)
    @principal = principal
    @credential_candidate = credential_candidate
    @current_client = current_client
    @repository = repository
    @provider = provider
    @uid = uid
  end

  def call
    raise UnauthorizedError.new("errors.social_auth.not_logged_in") unless current_client

    Rails.logger.debug { "[SocialAuth] handle_link - current_client_present: #{current_client.present?}" }

    existing_for_user = identity_for_current_user
    return handle_existing_for_current_user(existing_for_user) if existing_for_user

    identity = repository.find_by_subject_for_link(uid, lock: true)
    Rails.logger.debug do
      "[SocialAuth] Identity with uid exists: #{identity.present?}, " \
        "belongs_to_current_user: #{identity&.user_id == current_client_id}"
    end

    identity ? handle_existing_uid_identity(identity) : link_new_identity
  rescue ActiveRecord::RecordNotUnique => e
    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.link_race_condition",
        user_id: current_client_id,
        provider: provider,
        uid: "[FILTERED]",
        error: e.message,
      ),
    )
    raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
  end

  private

  attr_reader :principal, :credential_candidate, :current_client, :repository, :provider, :uid

  def current_client_id
    current_client.id
  end

  def handle_existing_for_current_user(identity)
    unless same_social_identity?(identity)
      Rails.logger.debug do
        "[SocialAuth] Conflict - user already has #{provider} linked to a different uid"
      end
      raise SocialAuth::ConflictError.new("errors.social_auth.identity_conflict")
    end

    reactivate_current_identity(identity)
    build_result(identity)
  end

  def reactivate_current_identity(identity)
    was_active = identity.active?
    repository.refresh_credentials!(
      identity,
      principal: principal,
      credential_candidate: credential_candidate,
    )
    repository.activate!(identity)
    create_social_link_audit(identity) unless was_active
    Rails.logger.debug { "[SocialAuth] Reactivated existing identity" }
  end

  def handle_existing_uid_identity(identity)
    if identity.user_id != current_client_id
      Rails.logger.debug do
        "[SocialAuth] Conflict - identity belongs to another user: #{identity.user_id}"
      end
      raise SocialAuth::ConflictError.new(
        "errors.social_auth.linked_to_another_user",
        provider: SocialIdentifiable.normalize_provider(provider),
      )
    end

    Rails.logger.debug { "[SocialAuth] Identity already belongs to current user, updating" }
    was_active = identity.active?
    repository.refresh_credentials!(
      identity,
      principal: principal,
      credential_candidate: credential_candidate,
    )
    create_social_link_audit(identity) unless was_active
    build_result(identity)
  end

  def link_new_identity
    Rails.logger.debug { "[SocialAuth] Creating new identity for current user" }
    identity =
      without_prosopite_noise do
        build_identity_for_current_user.tap do |new_identity|
          new_identity.save!
          new_identity.touch_authenticated!
          create_social_link_audit(new_identity)
        end
      end

    Rails.logger.info(
      JitLogEvent.format(
        "social_auth.linked",
        user_id: current_client_id,
        provider: provider,
      ),
    )

    Rails.logger.debug { "[SocialAuth] Successfully linked new identity" }
    build_result(identity)
  end

  def without_prosopite_noise(&)
    return yield unless defined?(Prosopite)

    Prosopite.pause(&)
  end

  def identity_for_current_user
    repository.find_for_user_for_link(current_client)
  end

  def same_social_identity?(identity)
    identity.uid.to_s == uid.to_s &&
      SocialIdentifiable.normalize_provider(identity.provider) == SocialIdentifiable.normalize_provider(provider)
  end

  def build_identity_for_current_user
    repository.build_for_user(
      user: current_client,
      principal: principal,
      credential_candidate: credential_candidate,
    )
  end

  def create_social_link_audit(identity)
    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: ClientChronicleEvent::SOCIAL_LINKED)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end

    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: current_client_id,
      event_id: ClientChronicleEvent::SOCIAL_LINKED,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: current_client_id.to_s,
      subject_type: "Client",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: SocialIdentifiable.normalize_provider(provider),
        social_identity_type: identity.class.name,
      },
    )
  end

  def build_result(identity)
    {
      user: current_client,
      identity: identity,
      jwt_payload: { user_id: current_client_id },
      step_up_authenticated: false,
      existing_account: nil,
    }
  end
end
