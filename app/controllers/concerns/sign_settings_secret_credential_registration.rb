# typed: false
# frozen_string_literal: true

module SignSettingsSecretCredentialRegistration
  extend ActiveSupport::Concern

  private

  def start_secret_credential_ceremony!(_surface:, _actor:, _session_ref:, _operation: "enrollment")
    nil
  end

  def finish_secret_credential_ceremony!(surface:, actor:, session_ref:, record_class:, name:, enabled:, # rubocop:disable Lint/UnusedMethodArgument
                                         raw_secret_credential:, _operation: "enrollment")
    create_settings_secret_credential!(
      surface: surface,
      actor: actor,
      record_class: record_class,
      name: name,
      enabled: enabled,
      raw_secret_credential: raw_secret_credential,
    )
  end

  def create_settings_secret_credential!(surface:, actor:, record_class:, name:, enabled:, raw_secret_credential:) # rubocop:disable Lint/UnusedMethodArgument
    params = { name: name, enabled: enabled }
    case surface.to_s
    when "com"
      VisitorSecretCredentialsCreate.call(
        actor: actor,
        visitor: actor,
        params: params,
        raw_secret_credential: raw_secret_credential,
      )
    when "org"
      OperatorSecretCredentialsCreate.call(
        actor: actor,
        staff: actor,
        params: params,
        raw_secret_credential: raw_secret_credential,
      )
    else
      raise IdentitySecretCredentialCeremonyContract::Error, "surface is invalid"
    end
  end

  def reset_secret_credential_ceremony_session!
    session.delete(secret_credential_ceremony_session_key)
  end

  def secret_credential_ceremony_session_key
    :secret_credential_ceremony
  end
end
