# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on Com and Org through the real Base start, Auth admission, Auth exit endpoint, Base
# continuation and Base commit. Org has no public Sign Up, so it offers Cancel but never Switch.
class SignEntryExitComOrgFlowTest < ActionDispatch::IntegrationTest
  SURFACES = {
    "com" => {
      base_host: "PUBLIC_BASE_CORPORATE_URL",
      auth_host: "PUBLIC_AUTH_CORPORATE_URL",
      client_id: "core-com-jp",
      realm: "visitor",
      sign_in_component: "auth/com/sign_ins/new",
      transaction_class: VisitorOidcAuthorizationTransaction,
    },
    "org" => {
      base_host: "PUBLIC_BASE_STAFF_URL",
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
    query = rp_query(commit_base_continuation!)

    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_not query.key?("code")
    assert_predicate transaction.reload, :canceled?
  end

  test "Com Switch to Sign Up keeps the parent and opens Sign Up" do
    transaction = start_at_auth_sign_in!("com")

    assert_equal "sign_up", inertia_props.fetch("switch_form").fetch("to")

    post "https://#{auth_host("com")}/sign/switch?ri=jp", params: { to: "sign_up" }
    target = URI.parse(commit_base_continuation!)

    assert_equal "/sign/up", target.path
    assert_equal "pending", transaction.reload.status
  end

  test "Org Cancel returns access_denied, and Org offers no Switch" do
    transaction = start_at_auth_sign_in!("org")

    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")

    post "https://#{auth_host("org")}/sign/cancellation?ri=jp"
    query = rp_query(commit_base_continuation!)

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
    host!(ENV.fetch(config.fetch(:base_host)))
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
    )

    assert_response :success
    form = response.parsed_body.at_css("form#base-authorization-ceremony-start-form")
    post(form["action"], params: form.css("input").to_h { |input| [input["name"], input["value"]] })
    sign_in = URI.parse(jump_rt_url_from_location_for_test(response.location))
    entry_ref = Rack::Utils.parse_nested_query(sign_in.query).fetch("entry_ref")
    drive_to_auth_page!(sign_in.to_s)

    assert_equal config.fetch(:sign_in_component), inertia_component

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface:)
    config.fetch(:transaction_class).find(binding.authorization_transaction_id)
  end

  # Follows redirects (unwrapping Jump) and same-origin continuation forms until a page settles.
  def drive_to_auth_page!(url)
    get(url)
    12.times do
      selector = "form[id$='continuation-form'], form[id$='confirmation-form']"
      form = response.redirect? ? nil : response.parsed_body.at_css(selector)
      if response.redirect?
        target = URI.parse(jump_rt_url_from_location_for_test(response.location))
        host!(target.host)
        get(target.to_s)
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

  def commit_base_continuation!
    assert_response :see_other
    base = URI.parse(jump_rt_url_from_location_for_test(response.location))
    host!(base.host)
    get(base.to_s)

    assert_response :success
    form = response.parsed_body.at_css("form#oidc-authorization-exit-form")
    post(form["action"], params: form.css("input[type=hidden]").to_h { |input| [input["name"], input["value"]] })

    assert_response :see_other
    jump_rt_url_from_location_for_test(response.location)
  end

  def rp_query(location) = Rack::Utils.parse_nested_query(URI.parse(location).query)
end
