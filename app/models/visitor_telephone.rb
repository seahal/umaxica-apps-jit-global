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
  include PublicId
  include ContactBinding

  self.filter_attributes += %w(number)

  # Matches MAX_TELEPHONES_PER_USER and MAX_TELEPHONES_PER_STAFF: contact-method
  # caps are four across every principal.
  MAX_TELEPHONES_PER_VISITOR = 4

  attribute :visitor_telephone_status_id, default: VisitorTelephoneStatus::UNVERIFIED

  belongs_to :visitor, inverse_of: :visitor_telephones
  belongs_to :visitor_telephone_status, inverse_of: :visitor_telephones

  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :visitor_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest, presence: true, if: :binding_effective?
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :visitor,
                 association: :visitor_telephones,
                 foreign_key: :visitor_id,
                 limit: :MAX_TELEPHONES_PER_VISITOR,
                 record_name: "telephones",
                 owner_name: "visitor"

  def to_param
    public_id
  end

  def contact_binding_digest
    number_digest
  end
end
