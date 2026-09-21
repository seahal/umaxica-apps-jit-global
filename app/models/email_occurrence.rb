# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_occurrences
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
#  index_email_occurrences_on_body             (body) UNIQUE
#  index_email_occurrences_on_body_created_at  (body,created_at)
#  index_email_occurrences_on_public_id        (public_id) UNIQUE
#  index_email_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_email_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_email_occurrences_on_status_id  (status_id => email_occurrence_statuses.id)
#

class EmailOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: EmailOccurrenceStatus::NOTHING

  belongs_to :email_occurrence_status, foreign_key: :status_id, inverse_of: :email_occurrences
  has_many :area_email_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :area_occurrences, through: :area_email_occurrences
  has_many :domain_email_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :domain_occurrences, through: :domain_email_occurrences
  has_many :email_visitor_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :visitor_occurrences, through: :email_visitor_occurrences
  has_many :email_ip_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :ip_occurrences, through: :email_ip_occurrences
  has_many :email_staff_occurrences, class_name: "EmailOperatorOccurrence", dependent: :destroy,
                                     inverse_of: :email_occurrence
  has_many :staff_occurrences, through: :email_staff_occurrences
  has_many :email_telephone_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :telephone_occurrences, through: :email_telephone_occurrences
  has_many :email_user_occurrences, class_name: "EmailClientOccurrence", dependent: :destroy,
                                    inverse_of: :email_occurrence
  has_many :client_occurrences, through: :email_user_occurrences, source: :user_occurrence
  has_many :email_zip_occurrences, dependent: :destroy, inverse_of: :email_occurrence
  has_many :zip_occurrences, through: :email_zip_occurrences

  validates :body, length: { maximum: 255 }
  validates :status_id, numericality: { only_integer: true }
end
