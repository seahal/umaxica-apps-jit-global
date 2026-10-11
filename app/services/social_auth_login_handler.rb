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

  def create_user_for_identity(identity)
    Rails.logger.debug { "[SocialAuth] Creating user for orphaned identity" }
    user = build_login_user
    persist_user!(user, context: "login_orphaned_identity")
    repository.assign_to_user(identity, user)
    identity.update!(user_id: user.id)
    user
  end

  def build_login_user
    user = Client.new
    ensure_user_status(user)
    ensure_user_visibility(user)
    ensure_user_mfa_level(user)
    ensure_user_mfa_status(user)
    user
  end

  def ensure_user_status(user)
    return if user.status_id.present? && user.status_id != ClientStatus::NOTHING

    status = ensure_user_status_record(ClientStatus::UNVERIFIED_WITH_SIGN_UP, "UNVERIFIED_WITH_SIGN_UP") ||
      ensure_user_status_record(ClientStatus::NOTHING, "NEYO") ||
      ClientStatus.first

    if status.present?
      user.status_id = status.id
    else
      Rails.logger.error(JitLogEvent.format("social_auth.default_reference.missing", reference: "user_status"))
    end
  end

  def ensure_user_status_record(id, code)
    ensure_reference_record!(ClientStatus, id, code)
  end

  def ensure_user_visibility(user)
    visibility = ensure_user_visibility_record(user.visibility_id, "STAFF") ||
      ensure_user_visibility_record(ClientVisibility::STAFF, "STAFF") ||
      ensure_user_visibility_record(ClientVisibility::USER, "USER") ||
      ClientVisibility.first

    if visibility.present?
      user.visibility_id = visibility.id
    else
      Rails.logger.error(JitLogEvent.format("social_auth.default_reference.missing", reference: "user_visibility"))
    end
  end

  def ensure_user_visibility_record(id, code)
    return nil if id.blank?

    ensure_reference_record!(ClientVisibility, id, code)
  end

  def ensure_user_mfa_level(user)
    mfa_level = ensure_user_mfa_level_record(user.mfa_level_id) ||
      ensure_user_mfa_level_record(ClientMfaLevel::NOTHING) ||
      ClientMfaLevel.first

    if mfa_level.present?
      user.mfa_level_id = mfa_level.id
    else
      Rails.logger.error(
        JitLogEvent.format(
          "social_auth.default_reference.missing",
          reference: "user_mfa_level",
        ),
      )
    end
  end

  def ensure_user_mfa_level_record(id)
    return nil if id.blank?

    ensure_reference_record!(ClientMfaLevel, id, nil)
  end

  def ensure_user_mfa_status(user)
    status = ensure_user_mfa_status_record(user.mfa_status_id) ||
      ensure_user_mfa_status_record(ClientMfaStatus::UNCONFIGURED) ||
      ClientMfaStatus.first

    if status.present?
      user.mfa_status_id = status.id
    else
      Rails.logger.error(
        JitLogEvent.format(
          "social_auth.default_reference.missing",
          reference: "user_mfa_status",
        ),
      )
    end
  end

  def ensure_user_mfa_status_record(id)
    return nil if id.blank?

    ensure_reference_record!(ClientMfaStatus, id, nil)
  end

  def ensure_reference_record!(model, id, code)
    AppZenithRecord.connected_to(role: :writing) do
      attributes = { id: id }
      attributes[:code] = code if model.column_names.include?("code")

      model.find_or_create_by!(id: id) do |record|
        attributes.each do |attribute, value|
          record.public_send("#{attribute}=", value)
        end
      end
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(
      "[SocialAuth] Failed to ensure reference record - model: #{model.name}, id: #{id.inspect}, " \
      "error: #{e.class.name}: #{e.message}",
    )
    nil
  end

  def persist_user!(user, context:)
    user.save!
  rescue ActiveRecord::RecordInvalid => e
    log_user_status_error(user, e, context: context)
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error")
  end

  def log_user_status_error(user, error, context:)
    details = user.errors.details.slice(:user_status, :status_id)
    Rails.logger.warn(
      "[SocialAuth] User creation failed (#{context}) - " \
      "status_id: #{user.status_id.inspect}, errors: #{details.inspect}, message: #{error.message}",
    )
  end

  def build_identity_for_user(user)
    repository.build_for_user(
      user: user,
      principal: principal,
      credential_candidate: credential_candidate,
    )
  end

  def create_social_signup_audit(user)
    event_id = social_signup_event_id
    return unless event_id

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicleEvent.find_or_create_by!(id: event_id)
      ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
    end

    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: user.id,
      event_id: event_id,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: user.id.to_s,
      subject_type: "Client",
      occurred_at: Time.current,
      context: {
        auth_method: "social",
        provider: SocialIdentifiable.normalize_provider(provider),
      },
    )
  end

  def social_signup_event_id
    case SocialIdentifiable.normalize_provider(provider)
    when "google"
      ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE
    when "apple"
      ClientChronicleEvent::SIGNED_UP_WITH_APPLE
    end
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
