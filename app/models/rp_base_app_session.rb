# typed: false
# frozen_string_literal: true

class RpBaseAppSession < RpBaseAppRecord
  self.table_name = "rp_sessions"

  CELL = RpCellBinding.fetch("rp_base_app")
  REALM = CELL.realm
  CLIENT_ID = CELL.client_id

  include PublicId

  belongs_to :op_session_binding, class_name: "RpBaseAppOpSessionBinding", inverse_of: :sessions
  has_many :step_up_states,
           class_name: "RpStepUpState",
           foreign_key: :rp_session_id,
           inverse_of: :rp_session,
           dependent: :restrict_with_error
  has_one :actor_selection,
          class_name: "RpBaseAppSessionSelection",
          foreign_key: :rp_session_id,
          inverse_of: :rp_session,
          dependent: :destroy

  # The partial index counts every unrevoked row, including an expired one.
  validates :op_session_binding_id,
            uniqueness: { conditions: -> { where(revoked_at: nil) } },
            on: :create, if: -> { revoked_at.nil? }

  validates :absolute_expires_at, presence: true
  validates :installed_generation, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :identity_binding_must_be_resolved
  validates :current_access_jti_digest, length: { maximum: 64 }

  public

  def active?(now: Time.current)
    return false if revoked_at.present? || op_session_binding_id.blank? || absolute_expires_at.blank? ||
      absolute_expires_at <= now

    RpBaseAppRecord.connected_to(role: :writing) do
      RpBaseAppOpSessionBinding.exists?(id: op_session_binding_id, revoked_at: nil)
    end
  end

  def selected_actor_context?
    RpBaseAppRecord.connected_to(role: :writing) do
      RpBaseAppSessionSelection.exists?(rp_session_id: id)
    end
  end

  private

  def identity_binding_must_be_resolved
    return if op_session_binding&.identity_binding_id.present?

    errors.add(:op_session_binding, "must have a resolved identity binding")
  end
end
