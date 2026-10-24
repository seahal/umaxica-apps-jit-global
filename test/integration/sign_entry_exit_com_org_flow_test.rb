# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on Com and Org through the real Base RP start, Visa OP admission, Auth exit endpoint,
# Base RP continuation and Base RP commit. Org has no public Sign Up, so it offers Cancel but never
# Switch.
class SignEntryExitComOrgFlowTest < ActionDispatch::IntegrationTest
  SURFACES = {
    "com" => {
      base_host: "PUBLIC_BASE_CORPORATE_URL",
      visa_surface: :com,
      auth_host: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com-jp",
      realm: "visitor",
      sign_in_component: "auth/com/sign_ins/new",
      transaction_class: VisitorOidcAuthorizationTransaction,
    },
    "org" => {
      base_host: "PUBLIC_BASE_STAFF_URL",
      visa_surface: :org,
      auth_host: "PUBLIC_AUTH_STAFF_URL",
      client_id: "core-org-jp",
      realm: "operator",
      sign_in_component: "auth/org/sign/ins/show",
      transaction_class: OperatorOidcAuthorizationTransaction,
    },
  }.freeze

  test "Com Cancel on the first Sign In page returns access_denied to the RP" do
    transaction = start_at_auth_sign_in!("com")

    post "https://#{auth_host("com")}/sign/cancellation?ri=jp"
    query = rp_query(commit_visa_continuation!)

    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_not query.key?("code")
    assert_predicate transaction.reload, :canceled?
  end

  test "Com Switch to Sign Up keeps the parent and opens Sign Up" do
    transaction = start_at_auth_sign_in!("com")

    assert_equal "sign_up", inertia_props.fetch("switch_form").fetch("to")

    post "https://#{auth_host("com")}/sign/switch?ri=jp", params: { to: "sign_up" }
    target = URI.parse(commit_visa_continuation!)

    assert_equal "/sign/up/sentry", target.path
    drive_to_auth_page!(target.to_s)

    assert_equal "auth/com/sign_ups/new", inertia_component
    assert_equal "pending", transaction.reload.status
  end

  test "Org Cancel returns access_denied, and Org offers no Switch" do
    transaction = start_at_auth_sign_in!("org")

    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")

    post "https://#{auth_host("org")}/sign/cancellation?ri=jp"
    query = rp_query(commit_visa_continuation!)

    assert_equal "access_denied", query.fetch("error")
    assert_predicate transaction.reload, :canceled?
  end

  test "Org refuses a Switch request even for its neutral parent" do
    transaction = start_at_auth_sign_in!("org")

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_switch_request!(transaction:, target: "sign_up")
    end
  end

  private

  def auth_host(surface) = ENV.fetch(SURFACES.fetch(surface).fetch(:auth_host))

  def start_at_auth_sign_in!(surface)
    config = SURFACES.fetch(surface)
    client = OidcClientRegistry.find!(config.fetch(:client_id))
    host!(visa_host_for_test_surface(config.fetch(:visa_surface)))
    https!
    get(
      "/oauth/authorize",
      params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:realm)).first,
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

    assert_equal config.fetch(:sign_in_component), inertia_component

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface:)
    config.fetch(:transaction_class).find(binding.authorization_transaction_id)
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
