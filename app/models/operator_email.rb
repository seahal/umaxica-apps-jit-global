# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_emails
# Database name: org_principal
#
#  id                             :bigint           not null, primary key
#  address                        :string           not null
#  address_digest                 :string
#  locked_at                      :datetime
#  notifiable                     :boolean          default(TRUE), not null
#  otp_attempts_count             :integer          default(0), not null
#  otp_last_sent_at               :datetime
#  promotional                    :boolean          default(TRUE), not null
#  subscribable                   :boolean          default(TRUE), not null
#  undeletable                    :boolean          default(FALSE), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       default(""), not null
#  staff_id                       :bigint           not null
#  staff_identity_email_status_id :bigint           default(6), not null
#
# Indexes
#
#  index_operator_emails_on_address_digest                  (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_operator_emails_on_public_id                       (public_id) UNIQUE
#  index_operator_emails_on_staff_id                        (staff_id)
#  index_operator_emails_on_staff_identity_email_status_id  (staff_identity_email_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_email_status_id => operator_email_statuses.id)
#

class OperatorEmail < OrgPrincipalRecord
  # P3d removes identifier-owned proof; ceremony transactions own verification material.
  self.ignored_columns += %w(otp_private_key otp_counter otp_expires_at)

  include PublicId
  include Email
  include EmailDeadIdentifierHistory

  include PromotionalEmailUnsubscribable

  IDENTIFIER_REALM = "org"

  MAX_EMAILS_PER_STAFF = 4

  encrypts :address, downcase: true,
                     key_provider: RealmIdentifierEncryptionKeyProvider.key_provider(realm: IDENTIFIER_REALM)

  alias_attribute :staff_email_status_id, :staff_identity_email_status_id
  attribute :staff_identity_email_status_id, default: OperatorEmailStatus::UNVERIFIED
  belongs_to :staff_email_status, class_name: "OperatorEmailStatus",
                                  foreign_key: :staff_identity_email_status_id,
                                  inverse_of: :staff_emails
  belongs_to :staff, class_name: "Operator"
  validates :address, presence: true, length: { maximum: 255 }
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :staff_identity_email_status_id, numericality: { only_integer: true }
  validates :address_digest, blind_index_uniqueness: { error_attribute: :address }, allow_blank: true

  after_initialize :initialize_email_otp_state

  before_destroy :archive_dead_email_identifier, prepend: true

  self.filter_attributes += %w(address)

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_emails,
                 foreign_key: :staff_id,
                 limit: :MAX_EMAILS_PER_STAFF,
                 record_name: "emails",
                 owner_name: "staff"
  before_destroy :prevent_destroy_when_undeletable
  before_validation do
    self.staff_id ||= 0
  end

  public

  after_initialize do
    self.address ||= ""
  end

  def finalize_email_registration!(transaction:, code:, session_ref:)
    with_lock do
      unless transaction.is_a?(OperatorEmailCeremonyTransaction) &&
          transaction.bootstrap_ceremony_transaction_ref.nil? &&
          transaction.normalized_email_digest == address_digest &&
          transaction.email_registration_otp_evidence?(
            code: code, actor_ref: staff.public_id, session_ref: session_ref, candidate_ref: public_id,
          )
        raise ArgumentError, "ORG Email registration evidence is unavailable"
      end
      return self if staff_email_status_id == OperatorEmailStatus::VERIFIED

      unless staff_email_status_id == OperatorEmailStatus::UNVERIFIED
        raise ArgumentError, "ORG Email registration candidate is not pending"
      end

      update!(staff_email_status_id: OperatorEmailStatus::VERIFIED)
      self
    end
  end

  def to_param
    public_id
  end

  def promotional_unsubscribe_scope
    :operator
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end
end
