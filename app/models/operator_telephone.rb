# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephones
# Database name: org_principal
#
#  id                                 :bigint           not null, primary key
#  locked_at                          :datetime
#  number                             :string           not null
#  number_digest                      :string
#  otp_attempts_count                 :integer          default(0), not null
#  otp_counter                        :text             not null
#  otp_expires_at                     :datetime
#  otp_private_key                    :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  staff_id                           :bigint           not null
#  staff_identity_telephone_status_id :bigint           default(6), not null
#
# Indexes
#
#  idx_on_staff_identity_telephone_status_id_6c01767c57  (staff_identity_telephone_status_id)
#  index_operator_telephones_on_number_digest            (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_operator_telephones_on_staff_id                 (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_telephone_status_id => operator_telephone_statuses.id)
#

class OperatorTelephone < OrgPrincipalRecord
  include Telephone
  include TelephoneDeadIdentifierHistory

  IDENTIFIER_REALM = "org"

  MAX_TELEPHONES_PER_STAFF = 4

  encrypts :number, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)
  encrypts :otp_private_key, key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  alias_attribute :staff_telephone_status_id, :staff_identity_telephone_status_id
  attribute :staff_identity_telephone_status_id, default: OperatorTelephoneStatus::UNVERIFIED

  belongs_to :staff_telephone_status, class_name: "OperatorTelephoneStatus",
                                      foreign_key: :staff_identity_telephone_status_id,
                                      inverse_of: :staff_telephones
  belongs_to :staff, class_name: "Operator"

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :staff_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, blind_index_uniqueness: { error_attribute: :number }, allow_blank: true

  after_initialize :initialize_telephone_otp_state

  before_destroy :archive_dead_telephone_identifier, prepend: true

  self.filter_attributes += %w(number)

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_telephones,
                 foreign_key: :staff_id,
                 limit: :MAX_TELEPHONES_PER_STAFF,
                 record_name: "telephones",
                 owner_name: "staff"

  after_initialize do
    self.number ||= ""
  end

  # Note: :number encryption is handled by Telephone concern

  public

  def finalize_telephone_registration!(transaction:, code:, session_ref:)
    with_lock do
      unless transaction.is_a?(OperatorTelephoneCeremonyTransaction) &&
          transaction.surface == "org" && transaction.normalized_number_digest == number_digest &&
          transaction.telephone_registration_otp_evidence?(
            code: code, actor_ref: staff.public_id, session_ref: session_ref, candidate_ref: id.to_s,
          )
        raise ArgumentError, "ORG Telephone registration evidence is unavailable"
      end
      return self if staff_telephone_status_id == OperatorTelephoneStatus::VERIFIED

      unless staff_telephone_status_id == OperatorTelephoneStatus::UNVERIFIED
        raise ArgumentError, "ORG Telephone registration candidate is not pending"
      end

      update!(staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED)
      self
    end
  end

  private
end
