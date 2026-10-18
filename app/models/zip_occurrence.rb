# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: zip_occurrences
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
#  index_zip_occurrences_on_body       (body) UNIQUE
#  index_zip_occurrences_on_public_id  (public_id) UNIQUE
#  index_zip_occurrences_on_purge_eligible_at  (purge_eligible_at)
#  index_zip_occurrences_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_zip_occurrences_on_status_id  (status_id => zip_occurrence_statuses.id)
#

class ZipOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: ZipOccurrenceStatus::NOTHING

  belongs_to :zip_occurrence_status, foreign_key: :status_id, inverse_of: :zip_occurrences
  has_many :area_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :area_occurrences, through: :area_zip_occurrences
  has_many :domain_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :domain_occurrences, through: :domain_zip_occurrences
  has_many :email_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :email_occurrences, through: :email_zip_occurrences
  has_many :ip_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :ip_occurrences, through: :ip_zip_occurrences
  has_many :staff_zip_occurrences, class_name: "OperatorZipOccurrence", dependent: :destroy, inverse_of: :zip_occurrence
  has_many :staff_occurrences, through: :staff_zip_occurrences
  has_many :telephone_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :telephone_occurrences, through: :telephone_zip_occurrences
  has_many :client_zip_occurrences, dependent: :destroy, inverse_of: :zip_occurrence
  has_many :client_occurrences, through: :client_zip_occurrences, source: :user_occurrence

  validates :body, length: { maximum: 16 }
  validates :status_id, numericality: { only_integer: true }
end
