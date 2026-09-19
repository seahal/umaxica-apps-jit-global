# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_tokens
# Database name: com_ticket
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
#  visitor_id                         :bigint           not null
#  visitor_token_binding_method_id    :bigint           default(0), not null
#  visitor_token_dbsc_status_id       :bigint           default(0), not null
#  visitor_token_kind_id              :bigint           default(1), not null
#  visitor_token_status_id            :bigint           default(1), not null
#
# Indexes
#
#  index_visitor_tokens_on_created_at                       (created_at)
#  index_visitor_tokens_on_dbsc_session_id                  (dbsc_session_id) UNIQUE
#  index_visitor_tokens_on_device_session_id                (device_session_id)
#  index_visitor_tokens_on_discarded_at                     (discarded_at)
#  index_visitor_tokens_on_oidc_connection_id               (oidc_connection_id)
#  index_visitor_tokens_on_oidc_jti                         (oidc_jti)
#  index_visitor_tokens_on_oidc_sid                         (oidc_sid)
#  index_visitor_tokens_on_public_id                        (public_id) UNIQUE
#  index_visitor_tokens_on_purged_at                        (purged_at)
#  index_visitor_tokens_on_refresh_token_digest             (refresh_token_digest) UNIQUE
#  index_visitor_tokens_on_refresh_token_family_id          (refresh_token_family_id)
#  index_visitor_tokens_on_rotated_at                       (rotated_at)
#  index_visitor_tokens_on_selected_account_public_id       (selected_account_public_id)
#  index_visitor_tokens_on_selected_collective_public_id    (selected_collective_public_id)
#  index_visitor_tokens_on_visitor_id_and_last_step_up_at   (visitor_id,last_step_up_at)
#  index_visitor_tokens_on_visitor_id_and_oidc_client_id    (visitor_id,oidc_client_id)
#  index_visitor_tokens_on_visitor_token_binding_method_id  (visitor_token_binding_method_id)
#  index_visitor_tokens_on_visitor_token_dbsc_status_id     (visitor_token_dbsc_status_id)
#  index_visitor_tokens_on_visitor_token_kind_id            (visitor_token_kind_id)
#  index_visitor_tokens_on_visitor_token_status_id          (visitor_token_status_id)
#
# Foreign Keys
#
#  fk_customer_tokens_on_customer_token_binding_method_id  (visitor_token_binding_method_id => visitor_token_binding_methods.id)
#  fk_customer_tokens_on_customer_token_dbsc_status_id     (visitor_token_dbsc_status_id => visitor_token_dbsc_statuses.id)
#  fk_customer_tokens_on_customer_token_kind_id            (visitor_token_kind_id => visitor_token_kinds.id)
#  fk_customer_tokens_on_customer_token_status_id          (visitor_token_status_id => visitor_token_statuses.id)
#
class VisitorToken < ComTicketRecord
  self.belongs_to_required_by_default = false

  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::Retainable
  include ::TokenStatusManagement
  include ::DbscBindable
  include ::SessionOidcConnection
  include ::SelectedActorContext

  DBSC_BINDING_METHOD_CLASS = VisitorTokenBindingMethod
  DBSC_STATUS_CLASS = VisitorTokenDbscStatus

  LOGIN_SESSION_TTL = SecurityTokenLifetimes::VISITOR_REFRESH_TOKEN_TTL
  DELETION_GRACE_PERIOD = 1.day
  MAX_SESSIONS_PER_VISITOR = 1
  MAX_TOTAL_SESSIONS_PER_VISITOR = 2
  session_oidc_connection_config actor_name: :visitor, connection_class: VisitorOidcConnection

  belongs_to :visitor, inverse_of: :visitor_tokens
  has_many :visitor_verifications, dependent: :delete_all, inverse_of: :visitor_token
  belongs_to :visitor_token_status
  belongs_to :visitor_token_kind
  belongs_to :visitor_token_binding_method
  belongs_to :visitor_token_dbsc_status
  belongs_to :oidc_connection, class_name: "VisitorOidcConnection"
  belongs_to :device_session, class_name: "VisitorDeviceSession", inverse_of: :visitor_tokens
  has_many :visitor_rp_sessions, inverse_of: :visitor_token, dependent: :delete_all
  has_one :step_up_session,
          class_name: "VisitorStepUpSession",
          inverse_of: :visitor_token,
          strict_loading: false,
          dependent: :destroy

  attribute :visitor_token_status_id, default: VisitorTokenStatus::ACTIVE
  attribute :visitor_token_kind_id, default: VisitorTokenKind::BROWSER_WEB
  attribute :visitor_token_binding_method_id, default: VisitorTokenBindingMethod::NOTHING
  attribute :visitor_token_dbsc_status_id, default: VisitorTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }

  validate :enforce_concurrent_session_limit, on: :create
  attr_accessor :skip_session_limit_check

  private

  def enforce_concurrent_session_limit
    return if skip_session_limit_check
    return unless visitor_id

    operation = -> { self.class.not_revoked.where(visitor_id: visitor_id, rotated_at: nil).count }
    count = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
    return if count < MAX_TOTAL_SESSIONS_PER_VISITOR

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per visitor (#{MAX_TOTAL_SESSIONS_PER_VISITOR})",
    )
  end
end
