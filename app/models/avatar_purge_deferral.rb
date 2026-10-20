# typed: false
# frozen_string_literal: true

class AvatarPurgeDeferral < AvatarRecord
  belongs_to :avatar, inverse_of: :purge_deferrals

  validates :reason_code, presence: true
  validates :attempt_count, numericality: { only_integer: true, greater_than: 0 }
  validates :reason_code, length: { maximum: 100 }
  validates :first_observed_at, exclusion: { in: [nil] }

  public

  # Record one observable, idempotent deferral for the Avatar and reason.
  # A row lock serializes concurrent attempts after the unique lookup.
  def self.record!(avatar:, reason_code:, observed_at: Avatar.database_now)
    row =
      find_or_create_by!(avatar_id: avatar.id, reason_code: reason_code) do |candidate|
        candidate.attempt_count = 1
        candidate.first_observed_at = observed_at
        candidate.last_observed_at = observed_at
      end
    return row if row.previously_new_record?

    row.with_lock do
      row.update!(
        attempt_count: row.attempt_count + 1,
        last_observed_at: observed_at,
      )
    end
    row
  end

  public_class_method :record!
end
