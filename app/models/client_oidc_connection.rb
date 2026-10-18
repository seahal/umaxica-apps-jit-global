# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_oidc_connections
# Database name: op_base_app
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  revoked_at   :datetime
#  scope        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :string(64)       not null
#  public_id    :string(21)       not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_client_oidc_connections_on_public_id              (public_id) UNIQUE
#  index_client_oidc_connections_on_user_id_and_client_id  (user_id,client_id) UNIQUE
#
class ClientOidcConnection < OpBaseAppRecord
  include OidcConnectionRecord

  belongs_to :user, class_name: "Client"
  has_many :user_tokens,
           class_name: "ClientToken",
           foreign_key: :oidc_connection_id,
           dependent: :nullify,
           inverse_of: :oidc_connection

  validates :client_id, uniqueness: { scope: :user_id }

  def self.actor_foreign_key = :user_id

  def actor = user

  def active_tokens
    user_tokens.session_inventory
  end
end
