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
  self.filter_attributes += %w(number)

  MAX_TELEPHONES_PER_USER = 4
  alias_attribute :user_telephone_status_id, :user_identity_telephone_status_id
  include Retainable
  include Telephone
  include PublicId

  def to_param
    public_id
  end

  attribute :user_identity_telephone_status_id, default: ClientTelephoneStatus::UNVERIFIED

  belongs_to :user_telephone_status,
             class_name: "ClientTelephoneStatus",
             inverse_of: :client_telephones,
             foreign_key: :user_identity_telephone_status_id
  belongs_to :user, class_name: "Client", inverse_of: :client_telephones

  # Note: :number validation is now handled by Telephone concern (E.164 normalization)
  validates :number, presence: true
  validates :otp_attempts_count, presence: true, numericality: { only_integer: true }
  validates :otp_counter, presence: true
  validates :otp_private_key, presence: true, length: { maximum: 255 }
  validates :user_identity_telephone_status_id, numericality: { only_integer: true }
  validates :number_digest,
            blind_index_uniqueness: {
              error_attribute: :number,
              status_column: :user_identity_telephone_status_id,
              deleted_status_id: ClientTelephoneStatus::DELETED,
            },
            allow_blank: true
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :user,
                 association: :client_telephones,
                 foreign_key: :user_id,
                 limit: :MAX_TELEPHONES_PER_USER,
                 record_name: "telephones",
                 owner_name: "user"

  after_initialize do
    self.number ||= ""
  end

  # Note: :number encryption is handled by Telephone concern

  private
end
