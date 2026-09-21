# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: domain_occurrences
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
#  index_domain_occurrences_on_body       (body) UNIQUE
#  index_domain_occurrences_on_public_id  (public_id) UNIQUE
#  index_domain_occurrences_on_purge_eligible_at  (purge_eligible_at)
#  index_domain_occurrences_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_domain_occurrences_on_status_id  (status_id => domain_occurrence_statuses.id)
#

class DomainOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: DomainOccurrenceStatus::NOTHING

  belongs_to :domain_occurrence_status, foreign_key: :status_id, inverse_of: :domain_occurrences
  has_many :area_domain_occurrences, dependent: :destroy, inverse_of: :domain_occurrence
  has_many :area_occurrences, through: :area_domain_occurrences
  has_many :domain_email_occurrences, dependent: :destroy, inverse_of: :domain_occurrence
  has_many :email_occurrences, through: :domain_email_occurrences
  has_many :domain_ip_occurrences, dependent: :destroy, inverse_of: :domain_occurrence
  has_many :ip_occurrences, through: :domain_ip_occurrences
  has_many :domain_staff_occurrences, class_name: "DomainOperatorOccurrence", dependent: :destroy,
                                      inverse_of: :domain_occurrence
  has_many :staff_occurrences, through: :domain_staff_occurrences
  has_many :domain_telephone_occurrences, dependent: :destroy, inverse_of: :domain_occurrence
  has_many :telephone_occurrences, through: :domain_telephone_occurrences
  has_many :domain_user_occurrences, class_name: "DomainClientOccurrence", dependent: :destroy,
                                     inverse_of: :domain_occurrence
  has_many :client_occurrences, through: :domain_user_occurrences, source: :user_occurrence
  has_many :domain_zip_occurrences, dependent: :destroy, inverse_of: :domain_occurrence
  has_many :zip_occurrences, through: :domain_zip_occurrences

  validates :body, length: { maximum: 253 }
  validates :status_id, numericality: { only_integer: true }
end
