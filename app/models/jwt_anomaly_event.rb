# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: jwt_anomaly_events
# Database name: occurrence
#
#  id                :bigint           not null, primary key
#  alg               :string           default(""), not null
#  code              :string           default(""), not null
#  error_class       :string           default(""), not null
#  error_message     :string           default(""), not null
#  issuer            :string           default(""), not null
#  jti               :string           default(""), not null
#  kid               :string           default(""), not null
#  metadata          :jsonb            not null
#  occurred_at       :datetime         not null
#  request_host      :string           default(""), not null
#  typ               :string           default(""), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  jwt_occurrence_id :bigint           not null
#
# Indexes
#
#  index_jwt_anomaly_events_on_code               (code)
#  index_jwt_anomaly_events_on_jwt_occurrence_id  (jwt_occurrence_id)
#  index_jwt_anomaly_events_on_occurred_at        (occurred_at)
#
# Foreign Keys
#
#  fk_jwt_anomaly_events_on_jwt_occurrence_id  (jwt_occurrence_id => jwt_occurrences.id)
#
class JwtAnomalyEvent < OccurrenceRecord
  belongs_to :jwt_occurrence, inverse_of: :jwt_anomaly_events

  validates :code, presence: true, length: { maximum: 255 }
  validates :request_host, length: { maximum: 255 }, allow_blank: true
  validates :kid, :alg, :typ, :issuer, :jti, :error_class, length: { maximum: 255 }, allow_blank: true
  validates :error_message, length: { maximum: 1000 }, allow_blank: true
  # Empty metadata is valid when a payload carries no allowlisted keys; only NULL is rejected.
  validates :metadata, exclusion: { in: [nil] }
  validates :occurred_at, presence: true
end
