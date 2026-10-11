# typed: false
# frozen_string_literal: true

class OidcConnectionRecorder < ApplicationService
  class StaleAuthorization < StandardError; end

  def initialize(resource:, client:, scope:, authorization_issued_at:, used_at: Time.current)
    super()
    @resource = resource
    @client = client
    @scope = scope
    @authorization_issued_at = authorization_issued_at
    @used_at = used_at
  end

  def call
    attributes = { actor_key => resource.id }
    attributes[:client_id] = client.client_id

    connection = connection_model.lock.find_or_initialize_by(attributes)
    reject_stale_authorization!(connection)

    connection.scope = normalized_scope
    connection.last_used_at = used_at
    connection.revoked_at = nil
    connection.save!
    connection
  end

  private

  attr_reader :resource, :client, :scope, :authorization_issued_at, :used_at

  def reject_stale_authorization!(connection)
    return if connection.revoked_at.blank?
    return if authorization_issued_at.present? && authorization_issued_at > connection.revoked_at

    raise StaleAuthorization, "authorization code predates OIDC connection revocation"
  end

  def connection_model
    case resource
    when Operator then OperatorOidcConnection
    when Visitor then VisitorOidcConnection
    else ClientOidcConnection
    end
  end

  def actor_key
    connection_model.actor_foreign_key
  end

  def normalized_scope
    scope.to_s.split.uniq.join(" ").presence
  end
end
