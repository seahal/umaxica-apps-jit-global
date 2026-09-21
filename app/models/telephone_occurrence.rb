# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephone_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  discard_at :datetime         default(Infinity), not null
#  memo         :string           default(""), not null
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(0), not null
#
# Indexes
#
#  index_telephone_occurrences_on_body             (body) UNIQUE
#  index_telephone_occurrences_on_body_created_at  (body,created_at)
#  index_telephone_occurrences_on_public_id        (public_id) UNIQUE
#  index_telephone_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_telephone_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_telephone_occurrences_on_status_id  (status_id => telephone_occurrence_statuses.id)
#

class TelephoneOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence
  include TelephoneNormalization

  HMAC_BODY_FORMAT = /\A\h{64}\z/

  attribute :status_id, default: TelephoneOccurrenceStatus::NOTHING

  before_validation :normalize_body_unless_hmac

  validates :body, presence: true, length: { maximum: 255 }
  validate :validate_body_format_unless_hmac

  belongs_to :telephone_occurrence_status, foreign_key: :status_id, inverse_of: :telephone_occurrences
  has_many :area_telephone_occurrences, dependent: :destroy, inverse_of: :telephone_occurrence
  has_many :area_occurrences, through: :area_telephone_occurrences
  has_many :domain_telephone_occurrences, dependent: :destroy, inverse_of: :telephone_occurrence
  has_many :domain_occurrences, through: :domain_telephone_occurrences
  has_many :email_telephone_occurrences, dependent: :destroy, inverse_of: :telephone_occurrence
  has_many :email_occurrences, through: :email_telephone_occurrences
  has_many :ip_telephone_occurrences, dependent: :destroy, inverse_of: :telephone_occurrence
  has_many :ip_occurrences, through: :ip_telephone_occurrences
  has_many :staff_telephone_occurrences, class_name: "OperatorTelephoneOccurrence", dependent: :destroy,
                                         inverse_of: :telephone_occurrence
  has_many :staff_occurrences, through: :staff_telephone_occurrences
  has_many :telephone_user_occurrences, class_name: "TelephoneClientOccurrence", dependent: :destroy,
                                        inverse_of: :telephone_occurrence
  has_many :client_occurrences, through: :telephone_user_occurrences, source: :user_occurrence
  has_many :telephone_zip_occurrences, dependent: :destroy, inverse_of: :telephone_occurrence
  has_many :zip_occurrences, through: :telephone_zip_occurrences

  validates :status_id, numericality: { only_integer: true }

  private

  def hmac_body?
    body.to_s.match?(HMAC_BODY_FORMAT)
  end

  def normalize_body_unless_hmac
    return if hmac_body?

    self.body = TelephoneNormalization.normalize_to_e164(body)
  end

  def validate_body_format_unless_hmac
    return if hmac_body?

    return errors.add(:body, :invalid_e164_format) if body.blank?

    errors.add(:body, :invalid_e164_format) unless body.match?(TelephoneNormalization::E164_FORMAT)
    errors.add(:body, :country_code_cannot_start_with_zero) if body.start_with?("+0")
  end
end
