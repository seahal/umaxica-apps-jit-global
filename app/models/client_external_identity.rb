# typed: false
# frozen_string_literal: true

class ClientExternalIdentity < AppPrincipalRecord
  PROVIDERS = %w(apple google).freeze
  STATES = %w(active consent_revoked account_deleted).freeze

  encrypts :subject, deterministic: true

  alias_attribute :uid, :subject
  alias_attribute :user_id, :client_id

  belongs_to :client, inverse_of: :client_external_identities
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client_external_identity

  validates :provider, inclusion: { in: PROVIDERS }
  validates :issuer, :subject, :audience, :verification_authority, presence: true
  validates :state, inclusion: { in: STATES }
  validates :verified_at, presence: true

  scope :effective_binding, -> { where(released_at: nil) }

  def self.with_subject_lock(provider:, issuer:, subject:)
    raise ArgumentError, "social subject lock requires a Source transaction" unless lease_connection.transaction_open?
    raise ArgumentError, "social subject lock requires a block" unless block_given?

    key = Digest::SHA256.digest([provider, issuer, subject].join("\0")).unpack1("q>")
    # Only the derived signed integer enters SQL; the adapter cannot decode the lock function's void result.
    lease_connection.execute("SELECT pg_advisory_xact_lock(#{key.to_i})")
    yield
  end

  public_class_method :with_subject_lock

  def self.released_since_ceremony?(provider:, issuer:, subject:, ceremony_started_at:)
    unless ceremony_started_at.is_a?(Time) || ceremony_started_at.is_a?(ActiveSupport::TimeWithZone)
      raise ArgumentError, "social ceremony start time is required"
    end
    raise ArgumentError, "social ceremony cannot start in the future" if ceremony_started_at > database_now
    raise ArgumentError, "social release check requires a Source transaction" unless lease_connection.transaction_open?

    return true if where(provider: provider, issuer: issuer, subject: subject)
      .exists?(released_at: ceremony_started_at..)

    digest = ClientSocialAuditOutbox.subject_digest_for(provider: provider, subject: subject)
    ClientSocialAuditOutbox.where(
      provider: provider, provider_subject_digest: digest, event_name: "unlinked",
    ).exists?(released_at: ceremony_started_at..)
  end

  public_class_method :released_since_ceremony?

  alias_method :user, :client
  alias_method :user=, :client=

  def active?
    state == "active" && released_at.blank?
  end

  public :active?

  def touch_authenticated!
    update!(last_authenticated_at: Time.current)
  end

  def release!(at: self.class.database_now)
    return self if released_at.present?

    update!(state: "consent_revoked", released_at: at)
  end
end
