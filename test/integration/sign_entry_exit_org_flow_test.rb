# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on Org through the real Base RP start, Visa OP admission, Auth exit endpoint, Base RP
# continuation and Base RP commit. Org has no public Sign Up, so it offers Cancel but never Switch.
# The corporate surface owns no credential ceremony (two.md WU-3), so it has no entry or exit flow.
class SignEntryExitOrgFlowTest < ActionDispatch::IntegrationTest
  CONFIG = {
    base_host: "PUBLIC_BASE_STAFF_URL",
    visa_surface: :org,
    auth_host: "PUBLIC_AUTH_STAFF_URL",
    client_id: "core-org-jp",
    realm: "operator",
    sign_in_component: "auth/org/sign/ins/show",
    transaction_class: OperatorOidcAuthorizationTransaction,
  }.freeze

  test "org pending authorization continuation returns a generic refusal without issuing a code" do
    transaction = start_at_auth_sign_in!
    before = transaction.reload.attributes
    host! visa_host_for_test_surface(CONFIG.fetch(:visa_surface))
    OidcAuthorizationCodeIssuer.stub(:call, ->(**) { flunk("pending transaction must not issue a code") }) do
      get "/oidc/result", params: { transaction_ref: transaction.transaction_id, result_ref: SecureRandom.uuid },
                          headers: browser_navigation_headers
    end

    assert_response :bad_request
    assert_equal(
      { "error" => "invalid_request", "error_description" => "invalid continuation request" },
      response.parsed_body,
    )
    assert_nil response.location
    assert_equal before, transaction.reload.attributes
  end

  test "Org Cancel returns access_denied, and Org offers no Switch" do
    transaction = start_at_auth_sign_in!

    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")

    post "https://#{auth_host}/sign/cancellation?ri=jp"
    query = rp_query(commit_visa_continuation!)

    assert_equal %w(error iss state), query.keys.sort
    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_predicate transaction.reload, :canceled?
  end

  test "Org refuses a Switch request even for its neutral parent" do
    transaction = start_at_auth_sign_in!

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_switch_request!(transaction:, target: "sign_up")
    end
  end

  private

  def auth_host = ENV.fetch(CONFIG.fetch(:auth_host))

  def start_at_auth_sign_in!
    client = OidcClientRegistry.find!(CONFIG.fetch(:client_id))
    host!(visa_host_for_test_surface(CONFIG.fetch(:visa_surface)))
    https!
    get(
      "/oauth/authorize",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(CONFIG.fetch(:realm)).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: "state",
        nonce: "nonce",
        scope: "openid profile",
      },
      headers: browser_navigation_headers,
    )

    sign_in =
      if response.redirect?
        URI.parse(jump_rt_url_from_location_for_test(response.location))
      else

        assert_response :success
        form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
        post(form["action"], params: form.css("input").to_h { |input| [input["name"], input["value"]] })

        assert_response :see_other
        URI.parse(jump_rt_url_from_location_for_test(response.location))
      end
    entry_ref = Rack::Utils.parse_nested_query(sign_in.query).fetch("entry_ref")
    drive_to_auth_page!(sign_in.to_s)

    assert_equal CONFIG.fetch(:sign_in_component), inertia_component

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: :org)
    CONFIG.fetch(:transaction_class).find(binding.authorization_transaction_id)
  end

  # Follows redirects (unwrapping Jump) and same-origin continuation forms until a page settles.
  def drive_to_auth_page!(url)
    target = URI.parse(url)
    host!(target.host)
    get(target.request_uri, headers: browser_navigation_headers)
    12.times do
      selector = "form[id$='continuation-form'], form[id$='confirmation-form']"
      form = response.redirect? ? nil : response.parsed_body.at_css(selector)
      if response.redirect?
        target = URI.parse(jump_rt_url_from_location_for_test(response.location))
        host!(target.host)
        get(target.request_uri, headers: browser_navigation_headers)
      elsif form
        action = URI.join("https://#{host}", form["action"])
        host!(action.host)
        post(action.to_s, params: form.css("input").to_h { |input| [input["name"], input["value"]] }.compact)
      else
        assert_response :success
        return
      end
    end

    flunk("Auth admission did not settle on a page")
  end

  def commit_visa_continuation!
    assert_response :see_other
    visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
    host!(visa_location.host)
    get(visa_location.request_uri, headers: browser_navigation_headers)

    assert_response :see_other
    jump_rt_url_from_location_for_test(response.location)
  end

  def browser_navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }
  end

  def rp_query(location) = Rack::Utils.parse_nested_query(URI.parse(location).query)
end
