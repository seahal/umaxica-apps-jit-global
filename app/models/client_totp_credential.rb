# typed: false
# frozen_string_literal: true

# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credentials
# Database name: app_principal
#
#  id                                      :bigint           not null, primary key
#  last_otp_at                             :datetime         default(-Infinity), not null
#  otp_attempts_count                      :integer          default(0), not null
#  private_key                             :string(1024)     default(""), not null
#  title                                   :string(32)
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  public_id                               :string(21)       not null
#  user_id                                 :bigint           not null
#  user_identity_totp_credential_status_id :bigint           default(5), not null
#
# Indexes
#
#  idx_on_user_identity_totp_credential_status_id_47a8d28ad3  (user_identity_totp_credential_status_id)
#  index_client_totp_credentials_on_public_id                 (public_id) UNIQUE
#  index_client_totp_credentials_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_totp_credential_status_id => client_totp_credential_statuses.id)
#

class ClientTotpCredential < AppPrincipalRecord
  include ::PublicId
  include MfaStatusCredential

  encrypts :private_key

  alias_attribute :user_totp_credential_status_id, :user_identity_totp_credential_status_id
  MAX_TOTP_SLOTS = 2
  MAX_CONSECUTIVE_FAILURES = 100
  SLOT_CONSUMING_STATUS_IDS = [
    ClientTotpCredentialStatus::ACTIVE,
    ClientTotpCredentialStatus::INACTIVE,
  ].freeze

  class SlotLimitExceeded < StandardError; end

  attr_accessor :first_token

  belongs_to :user, class_name: "Client", inverse_of: :client_totp_credentials
  mfa_status_owner :user
  belongs_to :user_totp_credential_status,
             class_name: "ClientTotpCredentialStatus",
             inverse_of: :client_totp_credentials,
             foreign_key: :user_identity_totp_credential_status_id
  attribute :user_identity_totp_credential_status_id, default: ClientTotpCredentialStatus::NOTHING

  validates :private_key, presence: true, length: { maximum: 1024 }
  validates :last_otp_at, presence: true
  validates :otp_attempts_count, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: MAX_CONSECUTIVE_FAILURES,
  }
  validates :title, length: { maximum: 32 }, allow_blank: true
  validate :revoked_status_is_terminal, on: :update

  after_initialize :generate_private_key_if_blank
  after_initialize :generate_public_id_if_blank

  public

  class << self
    public

    def slot_consuming_status_ids
      SLOT_CONSUMING_STATUS_IDS
    end

    def slot_consuming
      where(user_identity_totp_credential_status_id: SLOT_CONSUMING_STATUS_IDS)
    end

    # The client row is the cross-database coordination lock. Every production enrollment
    # path must use this method so the slot check and INSERT cannot race one another.
    def create_for_user!(user:, **attributes)
      user.class.transaction do
        user.lock!

        transaction do
          if slot_consuming.where(user_id: user.id).count >= MAX_TOTP_SLOTS
            raise SlotLimitExceeded, "TOTP credential slot limit is reached"
          end

          user.client_totp_credentials.create!(**attributes)
        end
      end
    end
  end

  def active?
    user_identity_totp_credential_status_id == ClientTotpCredentialStatus::ACTIVE
  end

  def inactive?
    user_identity_totp_credential_status_id == ClientTotpCredentialStatus::INACTIVE
  end

  def revoked?
    user_identity_totp_credential_status_id == ClientTotpCredentialStatus::REVOKED
  end

  def deleted?
    user_identity_totp_credential_status_id == ClientTotpCredentialStatus::DELETED
  end

  def usable?
    active?
  end

  def slot_consuming?
    SLOT_CONSUMING_STATUS_IDS.include?(user_identity_totp_credential_status_id)
  end

  # The caller must hold this row's PostgreSQL lock. A failed verification is permanently
  # associated with this authenticator; it never resets by elapsed time or by re-registration.
  def record_totp_failure!
    return :ignored unless active?

    self.otp_attempts_count = [otp_attempts_count.to_i + 1, MAX_CONSECUTIVE_FAILURES].min
    if otp_attempts_count >= MAX_CONSECUTIVE_FAILURES
      self.user_identity_totp_credential_status_id = ClientTotpCredentialStatus::REVOKED
    end
    save!(validate: false)
    revoked? ? :revoked : :failed
  end

  # Records a successful verification and clears only this authenticator's consecutive failures.
  # The caller holds the row lock and must have checked the ACTIVE state in that same transaction.
  def record_totp_success!(otp_at:)
    return false unless active?

    self.last_otp_at = Time.zone.at(otp_at)
    self.otp_attempts_count = 0
    save!(validate: false)
    true
  end

  private

  def generate_public_id_if_blank
    return unless has_attribute?(:public_id)

    self.public_id = Nanoid.generate(size: 21) if self[:public_id].blank?
  end

  def generate_private_key_if_blank
    self.private_key = ROTP::Base32.random_base32 if read_attribute_before_type_cast("private_key").blank?
  end

  def revoked_status_is_terminal
    return unless user_identity_totp_credential_status_id_in_database == ClientTotpCredentialStatus::REVOKED
    return unless will_save_change_to_user_identity_totp_credential_status_id?
    return if user_identity_totp_credential_status_id == ClientTotpCredentialStatus::REVOKED

    errors.add(:user_identity_totp_credential_status_id, "cannot leave REVOKED")
  end
end
