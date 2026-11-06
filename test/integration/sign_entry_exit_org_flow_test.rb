# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on Org through the real Base RP start, Visa OP admission, Auth exit endpoint, Base RP
# continuation and Base RP commit. Org has no public Sign Up, so it offers Cancel but never Switch.
# The corporate surface owns no credential ceremony (two.md WU-3), so it has no entry or exit flow.
class SignEntryExitOrgFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

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

  test "Org emergency Passkey entry exposes Cancel and returns access_denied to the RP" do
    transaction = start_at_auth_sign_in!
    get "/sign/in/emergency/passkey/new", params: { ri: "jp" }, headers: browser_navigation_headers

    assert_response :success
    cancel = inertia_props.fetch("parent_cancel")

    assert_equal "post", cancel.fetch("method")
    assert_equal "/sign/cancellation?ri=jp", cancel.fetch("action")
    post cancel.fetch("action")
    query = rp_query(commit_visa_continuation!)

    assert_equal "access_denied", query.fetch("error")
    assert_not query.key?("code")
    assert_predicate transaction.reload, :canceled?
  end

  test "Org Cancel after Entra evidence returns access_denied and preserves the evidence" do
    transaction = start_at_auth_sign_in!
    binding = OperatorAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    ceremony = OperatorAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    ceremony.record_authentication_evidence!(method: "entra")
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    old_sid = cookies[sid_cookie]

    assert_predicate old_sid, :present?

    post "https://#{auth_host}/sign/cancellation?ri=jp"

    assert_response :see_other
    assert_equal AuthCeremonySession::STATUS_CANCELLED_AFTER_PROGRESS, ceremony.reload.status_id
    assert_equal "entra", ceremony.authentication_method
    assert_predicate transaction.reload, :canceled?
    assert_predicate cookies[sid_cookie], :blank?

    canceled_facts = [transaction.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    first_visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))

    # A missing browser SID does not establish ownership of the canceled ceremony.
    cookies.delete(sid_cookie)
    cleared_cookies = cookies.to_hash
    post "https://#{auth_host}/sign/cancellation?ri=jp"

    assert_response :conflict
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    response_header_names = response.headers.to_h.keys.map(&:downcase)

    assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
    assert_equal canceled_facts, [transaction.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    assert_equal cleared_cookies, cookies.to_hash

    # Simulate a lost Auth response: retry only with the exact pre-Cancel browser SID.
    post "https://#{auth_host}/sign/cancellation?ri=jp", headers: { "Cookie" => "#{sid_cookie}=#{old_sid}" }

    assert_response :see_other
    assert_predicate cookies[sid_cookie], :blank?
    assert_equal canceled_facts, [transaction.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    retry_visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))

    assert_equal first_visa_location.host, retry_visa_location.host
    assert_equal first_visa_location.path, retry_visa_location.path
    assert_equal Rack::Utils.parse_nested_query(first_visa_location.query),
                 Rack::Utils.parse_nested_query(retry_visa_location.query)

    query = rp_query(commit_visa_continuation!(retry_visa_location))

    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_predicate transaction.reload, :canceled?
    assert_equal "entra", ceremony.reload.authentication_method
  end

  test "Org replays the committed Cancel without changing its durable outcome" do
    transaction = start_at_auth_sign_in!
    binding = OperatorAuthAdmissionBinding.find_by!(authorization_transaction_id: transaction.id)
    ceremony = OperatorAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
    post "https://#{auth_host}/sign/cancellation?ri=jp"
    visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
    first = commit_visa_continuation!(visa_location)
    before = [transaction.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    cookie_names = cookies.to_hash.keys.sort

    assert_equal "access_denied", rp_query(first).fetch("error")
    assert_equal "state", rp_query(first).fetch("state")
    assert_predicate ceremony, :cancelled?

    # A new Auth admission owns the browser's current auth_sid while the old Visa Cancel is replayed.
    replacement = OidcTestEntry.issue!(
      surface: "org", intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    replacement_browser = open_session
    replacement_browser.host!(auth_host)
    replacement_browser.https!
    admit_auth_ceremony_entry!(
      "/sign/in", reference: replacement.reference,
                  params: { ri: "jp" }, browser: replacement_browser,
    )
    replacement_binding = OperatorAuthAdmissionBinding.find_by!(entry_ref: replacement.reference)
    replacement_ceremony = OperatorAuthCeremonySession.find(replacement_binding.admitted_auth_ceremony_session_id)
    replacement_facts = [replacement.transaction.reload.attributes, replacement_binding.reload.attributes,
                         replacement_ceremony.reload.attributes,]
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    replacement_sid = replacement_browser.cookies[sid_cookie]

    assert_predicate replacement_sid, :present?
    assert_not_equal cookies[sid_cookie], replacement_sid
    store_raw_cookies(cookies, "#{sid_cookie}=#{replacement_sid}", URI.parse("https://#{auth_host}/"))

    replay = commit_visa_continuation!(visa_location)

    assert_equal first, replay
    assert_equal before, [transaction.reload.attributes, binding.reload.attributes, ceremony.reload.attributes]
    assert_equal cookie_names, cookies.to_hash.keys.sort
    assert_equal replacement_sid, cookies[sid_cookie]
    assert_equal replacement_facts, [replacement.transaction.reload.attributes, replacement_binding.reload.attributes,
                                     replacement_ceremony.reload.attributes,]
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

  def commit_visa_continuation!(visa_location = nil)
    if visa_location.nil?
      assert_response :see_other
      visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
    end

    host!(visa_location.host)
    get(visa_location.request_uri, headers: browser_navigation_headers)

    assert_response :success
    form = response.parsed_body.at_css("form#visa-authorization-continuation-form")

    assert form, "Visa continuation GET must render a POST form"
    fields = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{visa_location.host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )

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
