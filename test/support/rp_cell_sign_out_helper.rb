# frozen_string_literal: true

require_relative "rp_cell_session_helper"

# Seeds the local RP authentication contract and keeps Visa's RFC 7009 call inside the test process.
module RpCellSignOutHelper
  def authenticate_rp_cell_for_sign_out!(client_id:, actor:, root_token:)
    @rp_cell_client = OidcClientRegistry.find!(client_id)
    @rp_cell_resource_type = OidcIssuer.resource_type_for_client(@rp_cell_client)
    @rp_cell_token_response, @rp_cell_payload, @rp_cell_session = sign_in_rp_cell(
      client_id, actor:, root_token:,
    )
    grant_class = (@rp_cell_resource_type == "operator") ? OpOrgGrant : OpAppGrant
    @rp_cell_op_grant = grant_class.find_by!(
      public_id: @rp_cell_payload.fetch("sid"), oidc_client_id: client_id,
    )
    @rp_cell_root_token = root_token
  end

  def post_rp_cell_sign_out(path, params: {}, headers: {})
    @rp_cell_revocation_calls = []
    local_session = @rp_cell_session
    result = Object.new
    result.define_singleton_method(:success?) { false }
    result.define_singleton_method(:outcome) { :network_unavailable }

    OidcOpRevocationClient.stub(
      :revoke,
      ->(**arguments) {
        @rp_cell_revocation_calls << arguments.merge(local_session_revoked: local_session.reload.revoked_at.present?)
        result
      },
    ) do
      post(path, params:, headers:)
    end
  end

  def assert_rp_cell_sign_out_handoff!(client_id:, region:)
    client = OidcClientRegistry.find!(client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)
    redirect_uri =
      client.post_logout_redirect_uris.find do |candidate|
        Rack::Utils.parse_nested_query(URI.parse(candidate).query.to_s)["ri"] == region.to_s
      end

    assert_response :see_other
    assert_rp_cell_visa_logout_redirect!(
      client:, client_id:, redirect_uri:, location:, query:,
    )
    assert_rp_cell_local_logout_revocation!(client_id:, resource_type:)
    assert_predicate @rp_cell_session.reload.revoked_at, :present?
    assert_predicate @rp_cell_op_grant.reload, :active?
    assert_predicate @rp_cell_root_token.reload, :currently_usable?
  end

  private

  def assert_rp_cell_visa_logout_redirect!(client:, client_id:, redirect_uri:, location:, query:)
    assert_equal OidcIssuer.host_for_client(client), location.host
    assert_equal "/oidc/logout", location.path
    assert_equal client_id, query.fetch("client_id")
    assert_not query.key?("id_token_hint")
    assert_equal redirect_uri, query.fetch("post_logout_redirect_uri")
    assert_predicate query.fetch("state"), :present?
  end

  def assert_rp_cell_local_logout_revocation!(client_id:, resource_type:)
    assert_equal @rp_cell_token_response.fetch(:refresh_token), @rp_cell_revocation_calls.fetch(0).fetch(:token)
    assert_equal resource_type, @rp_cell_revocation_calls.fetch(0).fetch(:resource_type)
    assert_equal client_id, @rp_cell_revocation_calls.fetch(0).fetch(:client_id)
    assert @rp_cell_revocation_calls.fetch(0).fetch(:local_session_revoked)
  end
end
