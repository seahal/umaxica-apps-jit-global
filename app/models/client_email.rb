# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_emails
# Database name: app_principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_digest            :string
#  discard_at              :datetime         default(Infinity), not null
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  promotional               :boolean          default(TRUE), not null
#  purge_eligible_at                 :datetime         default(Infinity), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  public_id                 :string(21)       not null
#  user_email_status_id      :bigint           default(1), not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_client_emails_on_active_address_digest  (address_digest) UNIQUE WHERE ((address_digest IS NOT NULL) AND (user_email_status_id <> 4))
#  index_client_emails_on_discard_at           (discard_at)
#  index_client_emails_on_otp_last_sent_at       (otp_last_sent_at)
#  index_client_emails_on_public_id              (public_id) UNIQUE
#  index_client_emails_on_purge_eligible_at              (purge_eligible_at)
#  index_client_emails_on_user_email_status_id   (user_email_status_id)
#  index_client_emails_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_email_status_id => client_email_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#

class ClientEmail < AppPrincipalRecord
  include PublicId
  include Retainable
  include Email
  include EmailDeadIdentifierHistory

  include MfaStatusCredential
  include PromotionalEmailUnsubscribable
  include EmailContactBinding

  IDENTIFIER_REALM = "app"

  EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS = [
    ClientEmailStatus::VERIFIED,
    ClientEmailStatus::VERIFIED_WITH_SIGN_UP,
  ].freeze

  encrypts :address, downcase: true,
                     key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  attribute :user_email_status_id, default: ClientEmailStatus::UNVERIFIED
  belongs_to :user_email_status, class_name: "ClientEmailStatus",
                                 inverse_of: :client_emails
  belongs_to :user, class_name: "Client", inverse_of: :client_emails

  validate :effective_binding_has_digest
  validates :address, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :user_email_status_id, numericality: { only_integer: true }
  validates :address_digest, presence: true, if: :binding_effective?

  after_initialize :initialize_email_otp_state

  before_destroy :archive_dead_email_identifier, prepend: true
  before_destroy :prevent_destroy_when_undeletable

  after_initialize do
    self.address ||= ""
  end

  scope :effective_binding, -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) }

  self.filter_attributes += %w(address)
  mfa_status_owner :user

  public

  def to_param
    public_id
  end

  # Generates a new verification token and saves its digest
  # Returns the raw token
  def generate_verification_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.verification_token_digest = Digest::SHA256.hexdigest(raw_token)
    save!
    raw_token
  end

  def verify_verification_token(raw_token)
    return false if raw_token.blank? || verification_token_digest.blank?

    # Secure comparison of digests
    ActiveSupport::SecurityUtils.secure_compare(
      verification_token_digest,
      Digest::SHA256.hexdigest(raw_token),
    )
  end

  def subscription_preferences_locked?
    EDITABLE_SUBSCRIPTION_PREFERENCE_STATUS_IDS.exclude?(user_email_status_id)
  end

  def promotional_unsubscribe_scope
    :client
  end

  def contact_binding_digest
    address_digest
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end
end
