# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: area_occurrences
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
#  index_area_occurrences_on_body       (body) UNIQUE
#  index_area_occurrences_on_public_id  (public_id) UNIQUE
#  index_area_occurrences_on_purge_eligible_at  (purge_eligible_at)
#  index_area_occurrences_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_area_occurrences_on_status_id  (status_id => area_occurrence_statuses.id)
#

class AreaOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: AreaOccurrenceStatus::NOTHING

  belongs_to :area_occurrence_status, foreign_key: :status_id, inverse_of: :area_occurrences
  has_many :area_domain_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :domain_occurrences, through: :area_domain_occurrences
  has_many :area_email_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :email_occurrences, through: :area_email_occurrences
  has_many :area_visitor_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :visitor_occurrences, through: :area_visitor_occurrences
  has_many :area_ip_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :ip_occurrences, through: :area_ip_occurrences
  has_many :area_staff_occurrences, class_name: "AreaOperatorOccurrence", dependent: :destroy,
                                    inverse_of: :area_occurrence
  has_many :staff_occurrences, through: :area_staff_occurrences
  has_many :area_telephone_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :telephone_occurrences, through: :area_telephone_occurrences
  has_many :area_user_occurrences, class_name: "AreaClientOccurrence", dependent: :destroy, inverse_of: :area_occurrence
  has_many :client_occurrences, through: :area_user_occurrences, source: :user_occurrence
  has_many :area_zip_occurrences, dependent: :destroy, inverse_of: :area_occurrence
  has_many :zip_occurrences, through: :area_zip_occurrences

  validates :body, length: { maximum: 255 }
  validates :status_id, numericality: { only_integer: true }
end
