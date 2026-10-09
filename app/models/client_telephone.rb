# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_telephones
# Database name: app_principal
#
#  id                                :bigint           not null, primary key
#  discard_at                      :datetime         default(Infinity), not null
#  locked_at                         :datetime         default(-Infinity), not null
#  number                            :string           default(""), not null
#  number_digest                     :string
#  otp_attempts_count                :integer          default(0), not null
#  otp_counter                       :text             default(""), not null
#  otp_expires_at                    :datetime         default(-Infinity), not null
#  otp_private_key                   :string           default(""), not null
#  purge_eligible_at                         :datetime         default(Infinity), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  public_id                         :string(21)       not null
#  user_id                           :bigint           not null
#  user_identity_telephone_status_id :bigint           default(2), not null
#
# Indexes
#
#  index_client_telephones_on_active_number_digest               (number_digest) UNIQUE WHERE ((number_digest IS NOT NULL) AND (user_identity_telephone_status_id <> 4))
#  index_client_telephones_on_discard_at                       (discard_at)
#  index_client_telephones_on_public_id                          (public_id) UNIQUE
#  index_client_telephones_on_purge_eligible_at                          (purge_eligible_at)
#  index_client_telephones_on_user_id                            (user_id)
#  index_client_telephones_on_user_identity_telephone_status_id  (user_identity_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_telephone_status_id => client_telephone_statuses.id)
#

class ClientTelephone < AppPrincipalRecord
  include Retainable
  include Telephone
  include TelephoneDeadIdentifierHistory

  include PublicId
  include TelephoneContactBinding

  IDENTIFIER_REALM = "app"
  encrypts :number, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)
  encrypts :otp_private_key, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  self.filter_attributes += %w(number sign_up_otp_context credential_registration_otp_context)

  alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id

  attribute :user_identity_telephone_status_id, default: ClientTelephoneStatus::UNVERIFIED

  belongs_to :user_telephone_status,
             class_name: "ClientTelephoneStatus",
             inverse_of: :client_telephones,
             foreign_key: :user_identity_telephone_status_id
  belongs_to :user, class_name: "Client", inverse_of: :client_telephones

  validate :effective_binding_has_digest

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :user_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, presence: true, if: :binding_effective?

  after_initialize :initialize_telephone_otp_state
  before_destroy :archive_dead_telephone_identifier, prepend: true

  after_initialize do
    self.number ||= ""
  end

  scope :effective_binding, -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) }

  public

  def to_param
    public_id
  end

  def finalize_sign_up_binding!(flow:, transaction:, session_nonce:)
    with_lock do
      unless flow.is_a?(ClientSignUpFlow) && transaction.is_a?(ClientTelephoneCeremonyTransaction) &&
          sign_up_parent_matches?(flow, session_nonce) && sign_up_consumed_ceremony_matches?(flow, transaction)
        raise ArgumentError, "APP Telephone signup authority is unavailable"
      end
      unless accessible?(self.class.database_now) && !binding_released?
        raise ArgumentError, "APP Telephone signup candidate is unavailable"
      end
      return self if binding_effective? && user_telephone_status_id == ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP

      unless !binding_finalized_at && user_telephone_status_id == ClientTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
        raise ArgumentError, "APP Telephone signup candidate is not pending"
      end

      self.confirm_policy = "1"
      self.confirm_using_mfa = "1"
      update!(
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED_WITH_SIGN_UP,
        binding_finalized_at: self.class.database_now,
      )
      self
    end
  end

  def contact_binding_digest
    number_digest
  end

  # Note: :number encryption is handled by Telephone concern

  private

  def sign_up_parent_matches?(flow, session_nonce)
    session_nonce.is_a?(String) && session_nonce.valid_encoding? && session_nonce.encoding.ascii_compatible? &&
      session_nonce.present? && flow.nonce_matches?(session_nonce) && flow.sign_up_checkpoint_pending? &&
      flow.step == "checkpoint" && flow.expires_at > flow.class.database_now &&
      !flow.lapsed?(flow.class.database_now) &&
      flow.entry_method == "telephone" && flow.pending_contact_type == "telephone" &&
      flow.pending_contact_id == id && flow.principal_id == user_id && flow.requirement_cleared?(:otp)
  end

  def sign_up_consumed_ceremony_matches?(flow, transaction)
    expected_session = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
    transaction.surface == "app" && transaction.operation == "sign_up" && transaction.purpose == "sign_up" &&
      transaction.actor_ref == user.public_id && transaction.session_ref == expected_session &&
      transaction.telephone_candidate_ref == public_id && transaction.normalized_number_digest == number_digest &&
      transaction.expires_at == flow.expires_at && transaction.status == "pending" && !transaction.consumed_at &&
      !transaction.otp_cancelled_at && transaction.otp_verifier.nil? &&
      transaction.otp_consumed_at.is_a?(Time) && transaction.otp_consumed_at <= transaction.class.database_now &&
      transaction.otp_expires_at.is_a?(Time) && transaction.otp_consumed_at < transaction.otp_expires_at &&
      transaction.otp_receipt_verifier.present? && transaction.otp_generation.present?
  end
end
