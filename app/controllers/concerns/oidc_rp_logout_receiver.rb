# typed: false
# frozen_string_literal: true

module OidcRpLogoutReceiver
  extend ActiveSupport::Concern

  private

  def handle_oidc_backchannel_logout
    result = OidcLogoutTokenCodec.decode(
      logout_token: params[:logout_token].to_s,
      client_id: oidc_rp_logout_client_id,
      resource_type: oidc_rp_logout_resource_type,
    )
    return render plain: "invalid_logout_token", status: :bad_request unless result.success?

    OidcRpSessionLogout.call(
      resource_type: oidc_rp_logout_resource_type,
      client_id: oidc_rp_logout_client_id,
      sid: result.payload["sid"],
      reason: "oidc_backchannel_logout",
    )
    head :ok
  end

  def oidc_rp_logout_resource_type
    case self.class.name
    when /::Org::/ then "operator"
    when /::Com::/ then "visitor"
    else "client"
    end
  end

  def oidc_rp_logout_client_id
    return oidc_client_id if respond_to?(:oidc_client_id, true)

    raise NotImplementedError, "#{self.class.name} must define oidc_client_id for backchannel logout"
  end
end
