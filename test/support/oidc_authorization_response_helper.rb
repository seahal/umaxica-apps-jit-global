# frozen_string_literal: true

# Reads the RP-bound authorization response out of a Jump redirect so tests can assert the
# protocol parameters the relying party receives on its redirect_uri.
module OidcAuthorizationResponseHelper
  def assert_oidc_error_redirect(error:, redirect_uri:, state: "state")
    assert_response :redirect

    target = URI.parse(jump_target_url(response.location))
    params = Rack::Utils.parse_query(target.query.to_s)

    assert_equal redirect_uri, "#{target.scheme}://#{target.host}#{target.path}"
    assert_equal error, params["error"]
    assert_equal state, params["state"]
    assert_predicate params["iss"], :present?
    assert_nil params["code"]
  end

  private

  def jump_target_url(location)
    uri = URI.parse(location.to_s)
    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload.fetch("url")
  end
end
