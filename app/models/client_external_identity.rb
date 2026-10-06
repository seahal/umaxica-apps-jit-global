# typed: false
# frozen_string_literal: true

class ClientExternalIdentity < AppPrincipalRecord
  PROVIDERS = %w(apple google).freeze
  STATES = %w(active consent_revoked account_deleted).freeze

  encrypts :subject, deterministic: true

  scope :effective_binding, -> { where(released_at: nil) }

  belongs_to :client, inverse_of: :client_external_identities
  has_many :client_apple_notification_events,
           dependent: :nullify,
           inverse_of: :client_external_identity

  validates :provider, inclusion: { in: PROVIDERS }
  validates :issuer, :subject, :audience, :verification_authority, presence: true
  validates :state, inclusion: { in: STATES }
  validates :verified_at, presence: true

  alias_attribute :uid, :subject
  alias_attribute :user_id, :client_id

  alias_method :user, :client
  alias_method :user=, :client=

  def active?
    state == "active" && released_at.blank?
  end

  def touch_authenticated!
    update!(last_authenticated_at: Time.current)
  end

  def release!(at: self.class.database_now)
    return self if released_at.present?

    update!(state: "consent_revoked", released_at: at)
  end
end
