# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: jwt_occurrences
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
#  index_jwt_occurrences_on_body                 (body) UNIQUE
#  index_jwt_occurrences_on_body_and_created_at  (body,created_at)
#  index_jwt_occurrences_on_public_id            (public_id) UNIQUE
#  index_jwt_occurrences_on_purge_eligible_at            (purge_eligible_at)
#  index_jwt_occurrences_on_status_id            (status_id)
#
# Foreign Keys
#
#  fk_jwt_occurrences_on_status_id  (status_id => jwt_occurrence_statuses.id)
#
class JwtOccurrence < OccurrenceRecord
  include Retainable
  include PublicId
  include Occurrence

  attribute :status_id, default: JwtOccurrenceStatus::NOTHING

  belongs_to :jwt_occurrence_status, foreign_key: :status_id, inverse_of: :jwt_occurrences
  has_many :jwt_anomaly_events, dependent: :restrict_with_error, inverse_of: :jwt_occurrence

  validates :body, length: { maximum: 255 }
  validates :status_id, numericality: { only_integer: true }
end
