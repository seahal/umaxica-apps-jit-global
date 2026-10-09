# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_telephones
# Database name: com_principal
#
#  id                          :bigint           not null, primary key
#  discard_at                :datetime         default(Infinity), not null
#  locked_at                   :datetime         default(-Infinity), not null
#  number                      :string           default(""), not null
#  number_digest               :string
#  otp_attempts_count          :integer          default(0), not null
#  otp_counter                 :text             default(""), not null
#  otp_expires_at              :datetime         default(-Infinity), not null
#  otp_private_key             :string           default(""), not null
#  purge_eligible_at                   :datetime         default(Infinity), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  public_id                   :string(21)       not null
#  visitor_id                  :bigint           not null
#  visitor_telephone_status_id :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_telephones_on_active_number_digest         (number_digest) UNIQUE WHERE ((number_digest IS NOT NULL) AND (visitor_telephone_status_id <> 4))
#  index_visitor_telephones_on_discard_at                 (discard_at)
#  index_visitor_telephones_on_public_id                    (public_id) UNIQUE
#  index_visitor_telephones_on_purge_eligible_at                    (purge_eligible_at)
#  index_visitor_telephones_on_visitor_id                   (visitor_id)
#  index_visitor_telephones_on_visitor_telephone_status_id  (visitor_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_id => visitors.id)
#  fk_rails_...  (visitor_telephone_status_id => visitor_telephone_statuses.id)
#
class VisitorTelephone < ComPrincipalRecord
  include Retainable
  include Telephone
  include TelephoneDeadIdentifierHistory

  include PublicId
  include TelephoneContactBinding

  IDENTIFIER_REALM = "com"
  encrypts :number, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)
  encrypts :otp_private_key, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  attribute :visitor_telephone_status_id, default: VisitorTelephoneStatus::UNVERIFIED

  belongs_to :visitor, inverse_of: :visitor_telephones
  belongs_to :visitor_telephone_status, inverse_of: :visitor_telephones

  validate :effective_binding_has_digest

  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :visitor_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, presence: true, if: :binding_effective?

  after_initialize :initialize_telephone_otp_state
  before_destroy :archive_dead_telephone_identifier, prepend: true

  scope :effective_binding, -> { where.not(binding_finalized_at: nil).where(binding_released_at: nil) }

  self.filter_attributes += %w(number sign_up_otp_context credential_registration_otp_context)

  public

  def to_param
    public_id
  end

  def contact_binding_digest
    number_digest
  end

  def finalize_sign_up_binding!(flow:, transaction:, session_nonce:)
    with_lock do
      unless flow.is_a?(VisitorSignUpFlow) && transaction.is_a?(VisitorTelephoneCeremonyTransaction) &&
          sign_up_parent_matches?(flow, session_nonce) && sign_up_consumed_ceremony_matches?(flow, transaction)
        raise ArgumentError, "COM Telephone signup authority is unavailable"
      end
      unless accessible?(self.class.database_now) && !binding_released?
        raise ArgumentError, "COM Telephone signup candidate is unavailable"
      end
      return self if binding_effective? && visitor_telephone_status_id == VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP

      unless !binding_finalized_at && visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
        raise ArgumentError, "COM Telephone signup candidate is not pending"
      end

      self.confirm_policy = "1"
      self.confirm_using_mfa = "1"
      update!(
        visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
        binding_finalized_at: self.class.database_now,
      )
      self
    end
  end

  private

  def sign_up_parent_matches?(flow, session_nonce)
    session_nonce.is_a?(String) && session_nonce.valid_encoding? && session_nonce.encoding.ascii_compatible? &&
      session_nonce.present? && flow.nonce_matches?(session_nonce) && flow.sign_up_checkpoint_pending? &&
      flow.step == "checkpoint" && flow.expires_at > flow.class.database_now &&
      !flow.lapsed?(flow.class.database_now) &&
      flow.entry_method == "telephone" && flow.pending_contact_type == "telephone" &&
      flow.pending_contact_id == id && flow.principal_id == visitor_id && flow.requirement_cleared?(:otp)
  end

  def sign_up_consumed_ceremony_matches?(flow, transaction)
    expected_session = Digest::SHA256.hexdigest(JSON.generate(["telephone_sign_up", flow.public_id, flow.nonce_digest]))
    transaction.surface == "com" && transaction.operation == "sign_up" && transaction.purpose == "sign_up" &&
      transaction.actor_ref == visitor.public_id && transaction.session_ref == expected_session &&
      transaction.telephone_candidate_ref == public_id && transaction.normalized_number_digest == number_digest &&
      transaction.expires_at == flow.expires_at && transaction.status == "pending" && !transaction.consumed_at &&
      !transaction.otp_cancelled_at && transaction.otp_verifier.nil? &&
      transaction.otp_consumed_at.is_a?(Time) && transaction.otp_consumed_at <= transaction.class.database_now &&
      transaction.otp_expires_at.is_a?(Time) && transaction.otp_consumed_at < transaction.otp_expires_at &&
      transaction.otp_receipt_verifier.present? && transaction.otp_generation.present?
  end
end
