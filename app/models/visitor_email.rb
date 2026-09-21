# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_emails
# Database name: com_principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_digest            :string
#  discard_at              :datetime         default(Infinity), not null
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  purge_eligible_at                 :datetime         default(Infinity), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  public_id                 :string(21)       not null
#  visitor_email_status_id   :bigint           default(1), not null
#  visitor_id                :bigint           not null
#
# Indexes
#
#  index_visitor_emails_on_active_address_digest    (address_digest) UNIQUE WHERE ((address_digest IS NOT NULL) AND (visitor_email_status_id <> 4))
#  index_visitor_emails_on_discard_at             (discard_at)
#  index_visitor_emails_on_otp_last_sent_at         (otp_last_sent_at)
#  index_visitor_emails_on_public_id                (public_id) UNIQUE
#  index_visitor_emails_on_purge_eligible_at                (purge_eligible_at)
#  index_visitor_emails_on_visitor_email_status_id  (visitor_email_status_id)
#  index_visitor_emails_on_visitor_id               (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (visitor_email_status_id => visitor_email_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
class VisitorEmail < ComPrincipalRecord
  include PublicId
  include Retainable
  include Email
  include MfaStatusCredential
  include PromotionalEmailUnsubscribable

  self.filter_attributes += %w(address)

  MAX_EMAILS_PER_VISITOR = 4

  attribute :visitor_email_status_id, default: VisitorEmailStatus::UNVERIFIED

  belongs_to :visitor, inverse_of: :visitor_emails
  mfa_status_owner :visitor
  belongs_to :visitor_email_status, inverse_of: :visitor_emails

  validates :address, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :visitor_email_status_id, numericality: { only_integer: true }
  validates :address_digest,
            blind_index_uniqueness: {
              error_attribute: :address,
              status_column: :visitor_email_status_id,
              deleted_status_id: VisitorEmailStatus::DELETED,
            },
            allow_blank: true
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :visitor,
                 association: :visitor_emails,
                 foreign_key: :visitor_id,
                 limit: :MAX_EMAILS_PER_VISITOR,
                 record_name: "emails",
                 owner_name: "visitor"
  before_destroy :prevent_destroy_when_undeletable

  def to_param
    public_id
  end

  def generate_verification_token
    raw_token = SecureRandom.urlsafe_base64(32)
    self.verification_token_digest = Digest::SHA256.hexdigest(raw_token)
    save!
    raw_token
  end

  def verify_verification_token(raw_token)
    return false if raw_token.blank? || verification_token_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      verification_token_digest,
      Digest::SHA256.hexdigest(raw_token),
    )
  end

  def promotional_unsubscribe_scope
    :visitor
  end

  private

  def prevent_destroy_when_undeletable
    return unless undeletable?

    errors.add(:base, :undeletable, message: "cannot delete a protected email address")
    throw(:abort)
  end
end
