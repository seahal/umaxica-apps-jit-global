# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_occurrences
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
#  index_ip_occurrences_on_body             (body) UNIQUE
#  index_ip_occurrences_on_body_created_at  (body,created_at)
#  index_ip_occurrences_on_public_id        (public_id) UNIQUE
#  index_ip_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_ip_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_ip_occurrences_on_status_id  (status_id => ip_occurrence_statuses.id)
#

class IpOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: IpOccurrenceStatus::NOTHING

  belongs_to :ip_occurrence_status, foreign_key: :status_id, inverse_of: :ip_occurrences
  has_many :area_ip_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :area_occurrences, through: :area_ip_occurrences
  has_many :ip_visitor_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :visitor_occurrences, through: :ip_visitor_occurrences
  has_many :domain_ip_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :domain_occurrences, through: :domain_ip_occurrences
  has_many :email_ip_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :email_occurrences, through: :email_ip_occurrences
  has_many :ip_staff_occurrences, class_name: "IpOperatorOccurrence", dependent: :destroy, inverse_of: :ip_occurrence
  has_many :staff_occurrences, through: :ip_staff_occurrences
  has_many :ip_telephone_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :telephone_occurrences, through: :ip_telephone_occurrences
  has_many :ip_user_occurrences, class_name: "IpClientOccurrence", dependent: :destroy, inverse_of: :ip_occurrence
  has_many :client_occurrences, through: :ip_user_occurrences, source: :user_occurrence
  has_many :ip_zip_occurrences, dependent: :destroy, inverse_of: :ip_occurrence
  has_many :zip_occurrences, through: :ip_zip_occurrences

  validates :body, length: { maximum: 64 }
  validates :status_id, numericality: { only_integer: true }
end
