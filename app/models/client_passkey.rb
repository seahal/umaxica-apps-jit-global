# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_passkeys
# Database name: app_zenith
#
#  id                       :bigint           not null, primary key
#  aaguid                   :uuid
#  authenticator_attachment :string
#  backup_eligible          :boolean
#  backup_state             :boolean
#  description              :string           default(""), not null
#  discard_at             :datetime         default(Infinity), not null
#  last_used_at             :datetime
#  metadata_source          :string
#  provider_name            :string
#  public_key               :text             not null
#  purge_eligible_at                :datetime         default(Infinity), not null
#  sign_count               :bigint           default(0), not null
#  transports               :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_id              :uuid             not null
#  public_id                :string(21)
#  status_id                :bigint           default(1), not null
#  user_id                  :bigint           not null
#  webauthn_id              :string           default(""), not null
#
# Indexes
#
#  index_client_passkeys_on_discard_at    (discard_at)
#  index_client_passkeys_on_public_id       (public_id) UNIQUE
#  index_client_passkeys_on_purge_eligible_at       (purge_eligible_at)
#  index_client_passkeys_on_status_id       (status_id)
#  index_client_passkeys_on_webauthn_id     (webauthn_id) UNIQUE
#  index_user_identity_passkeys_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => client_passkey_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

class ClientPasskey < AppPrincipalRecord
  include ::PublicId
  include Retainable
  include MfaStatusCredential

  MAX_PASSKEYS_PER_USER = 4
  attribute :status_id, default: ClientPasskeyStatus::ACTIVE

  belongs_to :user, class_name: "Client", inverse_of: :client_passkeys
  mfa_status_owner :user
  belongs_to :status, class_name: "ClientPasskeyStatus"

  scope :active, -> { where(status_id: ClientPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_slot_limit, on: :create
  before_validation :set_defaults, on: :create
  before_validation :ensure_status_defaults, on: :create
  around_create :create_with_slot_lock

  def to_param
    public_id
  end

  private

  # Terminal history remains available to bootstrap/recovery checks without occupying a registration slot.
  def validate_slot_limit
    return if user_id.nil? || [ClientPasskeyStatus::REVOKED, ClientPasskeyStatus::DELETED].include?(status_id)

    count =
      self.class.connection_class_for_self.connected_to(role: :writing) do
        self.class.where(user_id: user_id).where.not(status_id: [ClientPasskeyStatus::REVOKED, ClientPasskeyStatus::DELETED]).count
      end
    return if count < MAX_PASSKEYS_PER_USER

    errors.add(:base, :too_many, message: "exceeds maximum passkeys per user (#{MAX_PASSKEYS_PER_USER})")
  end

  # Validation alone cannot reserve capacity; every INSERT repeats the check under the owner lock.
  def create_with_slot_lock
    self.class.connection_class_for_self.connected_to(role: :writing) do
      user.with_lock do
        validate_slot_limit
        raise ActiveRecord::RecordInvalid, self if errors.any?

        yield
      end
    end
  end

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end

  def ensure_status_defaults
    ClientPasskeyStatus.ensure_defaults!
  end
end
