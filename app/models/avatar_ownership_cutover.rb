# typed: false
# frozen_string_literal: true

# Singleton marker for the verified Avatar ownership writer cutover.
class AvatarOwnershipCutover < AvatarRecord
  CUTOVER_ID = 1

  self.primary_key = :id

  validates :id, inclusion: { in: [CUTOVER_ID] }
  validates :cutover_at, presence: true

  before_update :reject_mutation
  before_destroy :reject_mutation

  class << self
    public

    def established?
      exists?(id: CUTOVER_ID)
    end

    def current
      find_by(id: CUTOVER_ID)
    end
  end

  public

  def readonly?
    persisted? || super
  end

  private

  def reject_mutation
    raise ActiveRecord::ReadOnlyRecord, "Avatar ownership cutover marker is immutable"
  end
end
