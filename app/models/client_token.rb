# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_tokens
# Database name: app_ticket
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
#  selected_avatar_public_id          :string
#  selected_collective_public_id      :string
#  selected_collective_unit_public_id :string
#  user_id                            :bigint           not null
#  user_token_binding_method_id       :bigint           default(0), not null
#  user_token_dbsc_status_id          :bigint           default(0), not null
#  user_token_kind_id                 :bigint           default(11), not null
#  user_token_status_id               :bigint           default(1), not null
#
# Indexes
#
#  index_client_tokens_on_created_at                     (created_at)
#  index_client_tokens_on_dbsc_session_id                (dbsc_session_id) UNIQUE
#  index_client_tokens_on_device_session_id              (device_session_id)
#  index_client_tokens_on_discarded_at                   (discarded_at)
#  index_client_tokens_on_oidc_connection_id             (oidc_connection_id)
#  index_client_tokens_on_oidc_jti                       (oidc_jti)
#  index_client_tokens_on_oidc_sid                       (oidc_sid)
#  index_client_tokens_on_public_id                      (public_id) UNIQUE
#  index_client_tokens_on_purged_at                      (purged_at)
#  index_client_tokens_on_refresh_token_digest           (refresh_token_digest) UNIQUE
#  index_client_tokens_on_refresh_token_family_id        (refresh_token_family_id)
#  index_client_tokens_on_rotated_at                     (rotated_at)
#  index_client_tokens_on_selected_account_public_id     (selected_account_public_id)
#  index_client_tokens_on_selected_avatar_public_id      (selected_avatar_public_id)
#  index_client_tokens_on_selected_collective_public_id  (selected_collective_public_id)
#  index_client_tokens_on_user_id_and_last_step_up_at    (user_id,last_step_up_at)
#  index_client_tokens_on_user_id_and_oidc_client_id     (user_id,oidc_client_id)
#  index_client_tokens_on_user_token_binding_method_id   (user_token_binding_method_id)
#  index_client_tokens_on_user_token_dbsc_status_id      (user_token_dbsc_status_id)
#  index_client_tokens_on_user_token_kind_id             (user_token_kind_id)
#  index_client_tokens_on_user_token_status_id           (user_token_status_id)
#
# Foreign Keys
#
#  fk_rails_...                                    (user_token_kind_id => client_token_kinds.id) ON DELETE => restrict
#  fk_rails_...                                    (user_token_status_id => client_token_statuses.id) ON DELETE => restrict
#  fk_user_tokens_on_user_token_binding_method_id  (user_token_binding_method_id => client_token_binding_methods.id)
#  fk_user_tokens_on_user_token_dbsc_status_id     (user_token_dbsc_status_id => client_token_dbsc_statuses.id)
#

# Refresh tokens are persisted as digests only.
# OIDC sid/jti are protocol identifiers; public_id remains the token row identifier.
class ClientToken < AppTicketRecord
  self.belongs_to_required_by_default = false

  include ::PublicId
  include ::RefreshTokenable
  include ::SignedSessionReference
  include ::Retainable
  include ::TokenStatusManagement
  include ::DbscBindable
  include ::SessionOidcConnection
  include ::SelectedActorContext

  DBSC_BINDING_METHOD_CLASS = ClientTokenBindingMethod
  DBSC_STATUS_CLASS = ClientTokenDbscStatus

  MAX_SESSIONS_PER_USER = 2
  MAX_TOTAL_SESSIONS_PER_USER = 3
  session_oidc_connection_config actor_name: :user, connection_class: ClientOidcConnection

  belongs_to :user, class_name: "Client", inverse_of: :client_tokens
  belongs_to :user_token_status, class_name: "ClientTokenStatus"
  belongs_to :user_token_kind, class_name: "ClientTokenKind"
  belongs_to :user_token_binding_method, class_name: "ClientTokenBindingMethod"
  belongs_to :user_token_dbsc_status, class_name: "ClientTokenDbscStatus"
  belongs_to :oidc_connection, class_name: "ClientOidcConnection"
  belongs_to :device_session, class_name: "ClientDeviceSession", inverse_of: :client_tokens
  has_many :client_rp_sessions, inverse_of: :client_token, dependent: :delete_all
  has_many :client_verifications, dependent: :delete_all, inverse_of: :user_token
  has_one :step_up_session,
          class_name: "ClientStepUpSession",
          inverse_of: :user_token,
          strict_loading: false,
          dependent: :destroy
  attribute :user_token_status_id, default: ClientTokenStatus::ACTIVE
  attribute :user_token_kind_id, default: ClientTokenKind::BROWSER_WEB
  attribute :user_token_binding_method_id, default: ClientTokenBindingMethod::NOTHING
  attribute :user_token_dbsc_status_id, default: ClientTokenDbscStatus::NOTHING

  validates :public_id, uniqueness: true, length: { maximum: 21 }

  validate :enforce_concurrent_session_limit, on: :create

  private

  attr_accessor :skip_session_limit_check

  # This model-level validation provides an early, user-facing error message before
  # the database trigger rejects excess concurrent sessions.
  # The primary enforcement of the session limit is done by a database trigger,
  # which is more reliable and avoids race conditions.
  #
  # Note: We now allow up to 3 total sessions (2 active + 1 restricted),
  # but the Auth concern handles restricting the 3rd session.
  def enforce_concurrent_session_limit
    return if skip_session_limit_check
    return unless user_id

    operation = -> { self.class.not_revoked.where(user_id: user_id, rotated_at: nil).count }
    count = defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call

    return if count < MAX_TOTAL_SESSIONS_PER_USER

    errors.add(
      :base, :too_many,
      message: "exceeds maximum concurrent sessions per user (#{MAX_TOTAL_SESSIONS_PER_USER})",
    )
  end
end
