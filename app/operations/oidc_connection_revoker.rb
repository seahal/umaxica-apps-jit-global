# typed: false
# frozen_string_literal: true

class OidcConnectionRevoker < ApplicationService
  def initialize(connection:, revoked_at: Time.current)
    super()
    @connection = connection
    @revoked_at = revoked_at
  end

  def call
    connection.class.transaction do
      connection.update!(revoked_at: revoked_at)
      revoke_tokens!
    end

    connection
  end

  private

  attr_reader :connection, :revoked_at

  def revoke_tokens!
    token_scope.find_each do |token|
      AuthenticationLogoutCurrentSession.call(
        token: token,
        reason: "oidc_connection_revoked",
      )
    end
  end

  def token_scope
    connection.active_tokens.where(oidc_client_id: connection.client_id)
  end
end
