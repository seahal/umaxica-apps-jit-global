# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_oidc_connections
# Database name: op_base_com
#
#  id           :bigint           not null, primary key
#  last_used_at :datetime
#  revoked_at   :datetime
#  scope        :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :string(64)       not null
#  public_id    :string(21)       not null
#  visitor_id   :bigint           not null
#
# Indexes
#
#  index_visitor_oidc_connections_on_public_id                 (public_id) UNIQUE
#  index_visitor_oidc_connections_on_visitor_id_and_client_id  (visitor_id,client_id) UNIQUE
#
class VisitorOidcConnection < OpBaseComRecord
  include OidcConnectionRecord

  belongs_to :visitor
  has_many :visitor_tokens,
           class_name: "VisitorToken",
           foreign_key: :oidc_connection_id,
           dependent: :nullify,
           inverse_of: :oidc_connection

  validates :client_id, uniqueness: { scope: :visitor_id }

  def self.actor_foreign_key = :visitor_id

  def actor = visitor

  def active_tokens
    visitor_tokens.session_inventory
  end
end
