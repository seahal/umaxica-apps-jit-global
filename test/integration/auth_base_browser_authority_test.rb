# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthBaseBrowserAuthorityTest < ActionDispatch::IntegrationTest
  test "anonymous Base protected access enters Auth only after the neutral sign and authorization POSTs" do
    previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))
    get(base_app_accounts_path(ri: "jp"))

    assert_response :redirect
    assert_equal "/sign", URI.parse(response.location).path
    before_roots = ClientToken.count
    before_ceremonies = ClientAuthCeremonySession.count
    base = self
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    base_headers = { "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin" }
    base.host!(base_host)
    base.https!
    base.get("/sign", params: { ri: "jp" })

    assert_equal 200, base.response.status
    entry_form = Nokogiri::HTML(base.response.body).at_css("form")
    entry_fields = entry_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(entry_form["action"], params: entry_fields, headers: base_headers)

    assert_equal 303, base.response.status
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    payload, = JWT.decode(
      rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    target = URI.parse(payload.fetch("url"))

    assert_equal base_host, target.host
    base.get(target.request_uri)
    authorization_form = Nokogiri::HTML(base.response.body).at_css("form#base-authorization-ceremony-start-form")
    authorization_fields = authorization_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    base.post(authorization_form["action"], params: authorization_fields, headers: base_headers)

    assert_equal 303, base.response.status
    handoff_rt = Rack::Utils.parse_query(URI.parse(base.response.location).query).fetch("rt")
    handoff_payload, = JWT.decode(
      handoff_rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
      algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    auth_target = URI.parse(handoff_payload.fetch("url"))

    assert_equal auth_host, auth_target.host
    query = Rack::Utils.parse_query(auth_target.query)

    assert_equal auth_app_sign_in_path, auth_target.path
    assert_predicate query["entry_ref"], :present?
    assert_nil query["client_id"]
    assert_equal before_roots, ClientToken.count
    assert_equal before_ceremonies, ClientAuthCeremonySession.count
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
  end
end
