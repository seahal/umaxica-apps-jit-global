# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_device_sessions
# Database name: app_ticket
#
#  id                         :bigint           not null, primary key
#  dbsc_bound_at              :datetime
#  dbsc_public_key_thumbprint :string
#  dbsc_session_id_digest     :string
#  dpop_jkt                   :string
#  last_network_hmac          :string
#  last_seen_at               :datetime
#  revoke_reason              :string
#  revoked_at                 :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  current_refresh_token_id   :bigint
#  public_id                  :string(21)       not null
#  refresh_token_family_id    :string
#  status_id                  :bigint           default(1), not null
#  user_id                    :bigint           not null
#
# Indexes
#
#  index_client_device_sessions_on_current_refresh_token_id  (current_refresh_token_id)
#  index_client_device_sessions_on_dbsc_session_id_digest    (dbsc_session_id_digest)
#  index_client_device_sessions_on_public_id                 (public_id) UNIQUE
#  index_client_device_sessions_on_refresh_token_family_id   (refresh_token_family_id)
#  index_client_device_sessions_on_revoked_at                (revoked_at)
#  index_client_device_sessions_on_user_id                   (user_id)
#
class ClientDeviceSession < AppTicketRecord
  include DeviceSessionable

  belongs_to :user, class_name: "Client", inverse_of: :client_device_sessions
  # Nullable in the schema and legitimately blank for fallback (non-DBSC)
  # sessions and before the first refresh rotation. Marking it required made
  # `revoke!` (an `update!`) fail validation on such sessions, so sign-out could
  # not revoke them -- the session stayed usable. Revocation must always succeed.
  belongs_to :current_refresh_token, class_name: "ClientToken", optional: true
  has_many :client_tokens, foreign_key: :device_session_id,
                           dependent: :restrict_with_exception,
                           inverse_of: :device_session
end
