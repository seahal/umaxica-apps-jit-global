# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_tokens
# Database name: org_ticket
#
#  id                                 :bigint           not null, primary key
#  dbsc_challenge                     :text
#  dbsc_challenge_issued_at           :datetime
#  dbsc_public_key                    :jsonb
#  discarded_at                       :datetime         default(Infinity), not null
#  dpop_jkt                           :string
#  last_step_up_aal                   :string
#  last_step_up_at                    :datetime
#  last_step_up_audience              :string
#  last_step_up_method                :string
#  last_step_up_purpose               :string
#  last_step_up_scope                 :string
#  last_used_at                       :datetime
#  oidc_jti                           :uuid
#  oidc_scope                         :string
#  oidc_sid                           :uuid
#  purged_at                          :datetime         default(Infinity), not null
#  refresh_token_digest               :binary
#  refresh_token_generation           :integer          default(0), not null
#  rotated_at                         :datetime
#  selected_at                        :datetime
#  created_at                         :datetime         not null
#  authentication_event_at            :datetime
#  updated_at                         :datetime         not null
#  dbsc_session_id                    :string
#  device_session_id                  :bigint
#  last_step_up_session_public_id     :string
#  oidc_client_id                     :string(64)
#  oidc_connection_id                 :bigint
#  public_id                          :string(21)       default(""), not null
#  refresh_token_family_id            :string
#  selected_account_public_id         :string
#  selected_collective_public_id      :string
#  selected_collective_unit_public_id :string
#  staff_id                           :bigint           not null
#  staff_token_binding_method_id      :bigint           default(0), not null
#  staff_token_dbsc_status_id         :bigint           default(0), not null
#  staff_token_kind_id                :bigint           default(1), not null
#  staff_token_status_id              :bigint           default(1), not null
#
# Indexes
#
#  index_operator_tokens_on_created_at                     (created_at)
#  index_operator_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_operator_tokens_on_device_session_id              (device_session_id)
#  index_operator_tokens_on_discarded_at                   (discarded_at)
#  index_operator_tokens_on_oidc_connection_id             (oidc_connection_id)
#  index_operator_tokens_on_oidc_jti                       (oidc_jti)
#  index_operator_tokens_on_oidc_sid                       (oidc_sid)
#  index_operator_tokens_on_public_id                      (public_id) UNIQUE
#  index_operator_tokens_on_purged_at                      (purged_at)
#  index_operator_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_operator_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_operator_tokens_on_rotated_at                     (rotated_at)
#  index_operator_tokens_on_selected_account_public_id     (selected_account_public_id)
#  index_operator_tokens_on_selected_collective_public_id  (selected_collective_public_id)
#  index_operator_tokens_on_staff_id_and_last_step_up_at   (staff_id,last_step_up_at)
#  index_operator_tokens_on_staff_id_and_oidc_client_id    (staff_id,oidc_client_id)
#  index_operator_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id)
#  index_operator_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id)
#  index_operator_tokens_on_staff_token_kind_id            (staff_token_kind_id)
#  index_operator_tokens_on_staff_token_status_id          (staff_token_status_id)
#
# Foreign Keys
#
#  fk_rails_...                                      (staff_token_kind_id => operator_token_kinds.id) ON DELETE => restrict
#  fk_rails_...                                      (staff_token_status_id => operator_token_statuses.id) ON DELETE => restrict
#  fk_staff_tokens_on_staff_token_binding_method_id  (staff_token_binding_method_id => operator_token_binding_methods.id)
#  fk_staff_tokens_on_staff_token_dbsc_status_id     (staff_token_dbsc_status_id => operator_token_dbsc_statuses.id)
#

# Refresh tokens are persisted as digests only.
# OIDC sid/jti are protocol identifiers; public_id remains the token row identifier.
class OperatorToken < OrgTicketRecord
  self.belongs_to_required_by_default = false

  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::Retainable
  include ::TokenStatusManagement
  include ::DbscBindable
  include ::SessionOidcConnection
  include ::SelectedActorContext

  DBSC_BINDING_METHOD_CLASS = OperatorTokenBindingMethod
  DBSC_STATUS_CLASS = OperatorTokenDbscStatus

  LOGIN_SESSION_TTL = SecurityTokenLifetimes::OPERATOR_REFRESH_TOKEN_TTL
  DELETION_GRACE_PERIOD = 1.day
  MAX_SESSIONS_PER_STAFF = 1
  MAX_TOTAL_SESSIONS_PER_STAFF = 2
  session_oidc_connection_config actor_name: :staff, connection_class: OperatorOidcConnection

  belongs_to :staff, class_name: "Operator"
  belongs_to :staff_token_status, class_name: "OperatorTokenStatus"
  belongs_to :staff_token_kind, class_name: "OperatorTokenKind"
  belongs_to :staff_token_binding_method, class_name: "OperatorTokenBindingMethod"
  belongs_to :staff_token_dbsc_status, class_name: "OperatorTokenDbscStatus"
  belongs_to :oidc_connection, class_name: "OperatorOidcConnection"
  belongs_to :device_session, class_name: "OperatorDeviceSession", inverse_of: :staff_tokens
  has_many :operator_rp_sessions, inverse_of: :operator_token, dependent: :delete_all
  has_many :staff_verifications, class_name: "OperatorVerification",
                                 foreign_key: :staff_token_id,
                                 dependent: :delete_all,
                                 inverse_of: :staff_token
  has_one :step_up_session,
          class_name: "OperatorStepUpSession",
          foreign_key: :staff_token_id,
          inverse_of: :staff_token,
          strict_loading: false,
          dependent: :destroy
  attribute :staff_token_status_id, default: OperatorTokenStatus::ACTIVE
  attribute :staff_token_kind_id, default: OperatorTokenKind::BROWSER_WEB
  attribute :staff_token_binding_method_id, default: OperatorTokenBindingMethod::NOTHING
  attribute :staff_token_dbsc_status_id, default: OperatorTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }

  validate :enforce_concurrent_session_limit, on: :create
  attr_accessor :skip_session_limit_check

  private

  # This is a model-level validation to provide a friendly error message to the user.
  # The primary enforcement of the session limit is done by a database trigger,
  # which is more reliable and avoids race conditions.
  #
  # Operators are allowed one fully active session plus one restricted session that can
  # only be used to manage sessions, so the total live row limit is two.
  def enforce_concurrent_session_limit
    return if skip_session_limit_check
    return unless staff_id

    operation = -> { self.class.not_revoked.where(staff_id: staff_id, rotated_at: nil).count }
    count = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return if count < MAX_TOTAL_SESSIONS_PER_STAFF

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per staff (#{MAX_TOTAL_SESSIONS_PER_STAFF})",
    )
  end
end
