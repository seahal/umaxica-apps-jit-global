# typed: false
# frozen_string_literal: true

class OidcRpSessionLogout < ApplicationService
  def initialize(resource_type:, client_id:, sid:, reason:)
    super()
    @resource_type = resource_type
    @client_id = client_id
    @sid = sid
    @reason = reason
  end

  def call
    return false unless classes
    return false if client_id.blank?
    return false unless OidcLogoutTokenCodec::SID_PATTERN.match?(sid.to_s)

    token = find_session
    return false unless token

    if token.is_a?(usage_class)
      result = RpSessionRevoker.call(scope: :rp_session, record: token, status: "success")
      return result.success?
    end

    # A legacy UUID sid can still identify the Base Browser Session rather than
    # an RP Session. Preserve that historical contract: only the child path is
    # handled by RpSessionRevoker, while the explicit parent identifier reaches
    # the existing parent logout primitive.
    AuthenticationLogoutCurrentSession.call(
      resource: token_resource(token),
      token: token,
      token_class: token.class,
      session_public_id: token.public_id,
      reason: reason,
    )
    true
  end

  private

  attr_reader :resource_type, :client_id, :sid, :reason

  def classes
    @classes ||=
      case resource_type.to_s
      when "operator", "staff"
        [OperatorRpSession, OperatorToken, OrgTicketRecord]
      when "visitor", "customer"
        [VisitorRpSession, VisitorToken, ComTicketRecord]
      when "client"
        [ClientRpSession, ClientToken, AppTicketRecord]
      end
  end

  def token_class
    classes&.fetch(1)
  end

  def usage_class
    classes&.fetch(0)
  end

  def connection_owner
    classes&.fetch(2)
  end

  def find_session
    connection_owner.connected_to(role: :writing) do
      token = usage_class.find_by(public_id: sid, oidc_client_id: client_id)
      return token if token

      if OidcLogoutTokenCodec::LEGACY_UUID_PATTERN.match?(sid)
        token = token_class.find_by(oidc_sid: sid, oidc_client_id: client_id)
        return token if token
      end

      token_class.find_by(public_id: sid, oidc_client_id: client_id)
    end
  end

  def token_resource(token)
    case token
    when OperatorToken then token.staff
    when VisitorToken then token.visitor
    else token.user
    end
  end
end
