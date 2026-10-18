# frozen_string_literal: true

class ClientSocialAuditOutbox < AppZenithRecord
  attr_readonly :event_uuid, :operation_ref, :owner_ref, :identity_ref, :provider,
                :provider_subject_digest, :event_name, :occurred_at, :released_at

  validates :event_uuid, :operation_ref, :owner_ref, :identity_ref, :occurred_at,
            :provider_subject_digest, presence: true
  validates :provider, inclusion: { in: ClientExternalIdentity::PROVIDERS }
  validates :event_name, inclusion: { in: %w(linked unlinked) }

  def self.subject_digest_for(provider:, subject:)
    key = Rails.application.secret_key_base.presence ||
      raise(KeyError, "Missing key: Rails.application.secret_key_base")
    OpenSSL::HMAC.hexdigest("SHA256", key, "client-social-audit:#{provider}:#{subject}")
  end

  public_class_method :subject_digest_for

  def self.record!(identity:, owner:, event_name:)
    unless lease_connection.transaction_open?
      raise ArgumentError, "Social audit requires the Source Zenith transaction"
    end
    unless identity.is_a?(ClientExternalIdentity) && owner.is_a?(Client) &&
        identity.persisted? && identity.client_id == owner.id
      raise ArgumentError, "Social audit identity and owner must match"
    end
    unless (event_name == "linked" && identity.active?) ||
        (event_name == "unlinked" && identity.released_at.present?)
      raise ArgumentError, "Social audit event must match the committed binding state"
    end

    occurred_at = database_now
    create!(
      event_uuid: SecureRandom.uuid, operation_ref: identity.id.to_s,
      owner_ref: owner.public_id, identity_ref: identity.id.to_s,
      provider: identity.provider,
      provider_subject_digest: subject_digest_for(provider: identity.provider, subject: identity.subject),
      event_name: event_name, occurred_at: occurred_at,
      released_at: (occurred_at if event_name == "unlinked"),
    )
  end

  public_class_method :record!
end
