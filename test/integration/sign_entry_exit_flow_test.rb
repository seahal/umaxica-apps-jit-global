# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on App: Cancel and Switch from the first Sign In page, through the real Base RP start,
# Visa OP admission, Auth exit endpoint, Base RP continuation and Base RP commit.
class SignEntryExitFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @visa_host = visa_host_for_test_surface(:app)
    @auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @client = OidcClientRegistry.find!("core-app-jp")
    @redirect_uri = @client.redirect_uris_by_realm.fetch("client").first
  end

  test "a pending authorization continuation returns a generic refusal without issuing a code" do
    transaction = start_at_auth_sign_in!
    before = transaction.reload.attributes
    host! @visa_host
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

  test "Visa continuation signatures accept 59 seconds and refuse 60 and 61 seconds" do
    [[59, :see_other], [60, :bad_request], [61, :bad_request]].each do |age, expected_status|
      started_at = Time.zone.at(Time.current.to_i)
      travel_to(started_at)
      transaction = start_at_auth_sign_in!
      post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")
      visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
      host!(visa_location.host)
      get(visa_location.request_uri, headers: browser_navigation_headers)

      assert_response :success
      form = response.parsed_body.at_css("form#visa-authorization-continuation-form")
      fields = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
      before = transaction.reload.attributes

      travel_to(started_at + age.seconds)
      post form["action"], params: fields, headers: {
        "Origin" => "https://#{visa_location.host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      }

      assert_response expected_status
      assert_equal before, transaction.reload.attributes if age >= 60
    end
  end

  test "tampered Visa continuation cannot cancel its authorization transaction" do
    transaction = start_at_auth_sign_in!
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")
    visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
    host!(visa_location.host)
    get(visa_location.request_uri, headers: browser_navigation_headers)
    form = response.parsed_body.at_css("form#visa-authorization-continuation-form")
    fields = form.css("input[type='hidden']").to_h { |input| [input["name"], input["value"]] }
    fields["continuation"] = "#{fields.fetch("continuation")}x"
    before = transaction.reload.attributes
    post form["action"], params: fields, headers: {
      "Origin" => "https://#{visa_location.host}",
      "Sec-Fetch-Site" => "same-origin",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }

    assert_response :bad_request
    assert_equal before, transaction.reload.attributes
  end

  test "Cancel on the first Sign In page returns access_denied with state and iss to the RP" do
    transaction = start_at_auth_sign_in!

    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")

    assert_response :see_other
    visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))

    assert_equal @visa_host, visa_location.host
    assert_equal "/oidc/cancellation", visa_location.path
    assert_predicate ceremony_session_for(transaction).reload, :cancelled?

    continuation = URI.parse(jump_rt_url_from_location_for_test(response.location))
    before = [transaction.reload.attributes,
              ClientAuthAdmissionBinding.where(
                authorization_transaction_id: transaction.id,
              ).order(:id).map(&:attributes),]
    host!(continuation.host)
    head(continuation.request_uri, headers: browser_navigation_headers)

    assert_response :bad_request
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    get(continuation.request_uri, headers: browser_navigation_headers.merge("Sec-Fetch-Dest" => "iframe"))

    assert_response :bad_request
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    get(continuation.request_uri, headers: browser_navigation_headers)

    assert_response :success
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    location = commit_visa_continuation!(visa_location)
    rp = URI.parse(location)
    query = Rack::Utils.parse_nested_query(rp.query)

    assert_equal @redirect_uri, "#{rp.scheme}://#{rp.host}#{rp.path}"
    assert_equal %w(error iss state), query.keys.sort
    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_predicate query.fetch("iss"), :present?
    assert_not query.key?("code")
    assert_predicate transaction.reload, :canceled?
  end

  test "replaying the committed Cancel converges on the same access_denied without a second outcome" do
    transaction = start_at_auth_sign_in!
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")
    visa_location = URI.parse(jump_rt_url_from_location_for_test(response.location))
    host!(visa_location.host)
    location = commit_visa_continuation!(visa_location)

    assert_response :see_other
    first = location
    canceled_at = transaction.reload.canceled_at

    # A new Auth admission owns the browser's current auth_sid while the old Visa Cancel is replayed.
    replacement = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    replacement_browser = open_session
    replacement_browser.host!(@auth_host)
    replacement_browser.https!
    admit_auth_ceremony_entry!(
      "/sign/in", reference: replacement.reference,
                  params: { ri: "jp" }, browser: replacement_browser,
    )
    replacement_binding = ClientAuthAdmissionBinding.find_by!(entry_ref: replacement.reference)
    replacement_ceremony = ClientAuthCeremonySession.find(replacement_binding.admitted_auth_ceremony_session_id)
    replacement_facts = [replacement.transaction.reload.attributes, replacement_binding.reload.attributes,
                         replacement_ceremony.reload.attributes,]
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    replacement_sid = replacement_browser.cookies[sid_cookie]

    assert_predicate replacement_sid, :present?
    assert_not_equal cookies[sid_cookie], replacement_sid
    store_raw_cookies(cookies, "#{sid_cookie}=#{replacement_sid}", URI.parse("https://#{@auth_host}/"))

    second = commit_visa_continuation!(visa_location)

    assert_response :see_other
    assert_equal first, second
    assert_equal canceled_at, transaction.reload.canceled_at
    assert_equal replacement_sid, cookies[sid_cookie]
    assert_equal replacement_facts, [replacement.transaction.reload.attributes, replacement_binding.reload.attributes,
                                     replacement_ceremony.reload.attributes,]
  end

  test "a canceled parent refuses a later authentication result" do
    transaction = start_at_auth_sign_in!
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")
    commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location)))

    assert_raises(ArgumentError) do
      transaction.reload.register_authentication!(
        actor_ref: actor.public_id, session_ref: nil, auth_method: "email",
        acr: nil, authentication_event_at: Time.current,
      )
    end
    assert_predicate transaction.reload, :canceled?
  end

  test "Cancel after authentication evidence ends the pending parent without undoing the evidence" do
    transaction = start_at_auth_sign_in!
    ceremony = ceremony_session_for(transaction)
    ceremony.record_authentication_evidence!(method: "email")
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    old_sid = cookies[sid_cookie]

    assert_predicate old_sid, :present?

    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")

    assert_response :see_other
    assert_equal AuthCeremonySession::STATUS_CANCELLED_AFTER_PROGRESS, ceremony.reload.status_id
    assert_equal "canceled", transaction.reload.status_name
    assert_equal "email", ceremony.authentication_method
    assert_predicate cookies[sid_cookie], :blank?

    canceled_facts = [transaction.reload.attributes, ceremony.reload.attributes]
    # Missing auth_sid is not evidence that this request belongs to the canceled browser.
    cookies.delete(sid_cookie)
    cleared_cookies = cookies.to_hash
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")

    assert_response :conflict
    assert_nil response.location
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
    response_header_names = response.headers.to_h.keys.map(&:downcase)

    assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
    assert_equal canceled_facts, [transaction.reload.attributes, ceremony.reload.attributes]
    assert_equal cleared_cookies, cookies.to_hash

    # A response lost after the Auth terminal commit may be retried only with that exact old SID.
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp"),
         headers: { "Cookie" => "#{sid_cookie}=#{old_sid}" }

    assert_response :see_other
    assert_predicate cookies[sid_cookie], :blank?

    rp_location = URI.parse(commit_visa_continuation!)
    query = Rack::Utils.parse_nested_query(rp_location.query)

    assert_equal @redirect_uri, "#{rp_location.scheme}://#{rp_location.host}#{rp_location.path}"
    assert_equal "access_denied", query.fetch("error")
    assert_equal "state", query.fetch("state")
    assert_predicate transaction.reload, :canceled?
    assert_equal "email", ceremony.reload.authentication_method
  end

  test "Switch keeps the parent, ends the old ceremony and admits Sign Up for the same parent" do
    transaction = start_at_auth_sign_in!
    old_ceremony = ceremony_session_for(transaction)
    old_binding = ClientAuthAdmissionBinding.find_by!(admitted_auth_ceremony_session_id: old_ceremony.id)

    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_up" }

    assert_response :see_other
    assert_predicate old_ceremony.reload, :cancelled?

    continuation = URI.parse(jump_rt_url_from_location_for_test(response.location))
    before = [transaction.reload.attributes,
              ClientAuthAdmissionBinding.where(
                authorization_transaction_id: transaction.id,
              ).order(:id).map(&:attributes),]
    host!(continuation.host)
    head(continuation.request_uri, headers: browser_navigation_headers)

    assert_response :bad_request
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    get(continuation.request_uri, headers: browser_navigation_headers.merge("Sec-Fetch-Dest" => "iframe"))

    assert_response :bad_request
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    get(continuation.request_uri, headers: browser_navigation_headers)

    assert_response :success
    assert_equal before, [transaction.reload.attributes,
                          ClientAuthAdmissionBinding.where(
                            authorization_transaction_id: transaction.id,
                          ).order(:id).map(&:attributes),]
    location = commit_visa_continuation!(continuation)
    target = URI.parse(jump_rt_url_from_location_for_test(location))

    assert_equal @auth_host, target.host
    assert_equal "/sign/up/sentry", target.path
    entry_ref = Rack::Utils.parse_nested_query(target.query).fetch("entry_ref")
    drive_to_auth_page!(target.to_s)

    assert_equal "auth/app/sign_ups/new", inertia_component
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app")

    assert_equal transaction.id, binding.authorization_transaction_id
    assert_predicate old_binding.reload, :switched?
    assert_predicate binding, :redeemed?
    assert_equal "pending", transaction.reload.status_name

    before_old_target = [
      old_binding.reload.attributes,
      old_ceremony.reload.attributes,
      binding.reload.attributes,
      transaction.reload.attributes,
      cookies.to_hash,
    ]
    get "/sign/in", params: { entry_ref: old_binding.entry_ref, ri: "jp" }, headers: browser_navigation_headers

    assert_equal 409, response.status
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    AuthPhaseRefusalResponseBoundary::COOKIE_NAMES.each { |name| assert_no_set_cookie(name) }
    response_header_names = response.headers.to_h.keys.map(&:downcase)

    assert_empty AuthPhaseRefusalResponseBoundary::DBSC_HEADERS & response_header_names
    assert_equal before_old_target, [
      old_binding.reload.attributes,
      old_ceremony.reload.attributes,
      binding.reload.attributes,
      transaction.reload.attributes,
      cookies.to_hash,
    ]
  end

  test "switching to Sign Up and back to Sign In keeps one parent" do
    transaction = start_at_auth_sign_in!
    original_ceremony = ceremony_session_for(transaction)
    original_binding = ClientAuthAdmissionBinding.find_by!(
      admitted_auth_ceremony_session_id: original_ceremony.id,
    )
    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_up" }
    sign_up = URI.parse(commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location))))
    drive_to_auth_page!(sign_up.to_s)

    assert_equal "auth/app/sign_ups/new", inertia_component
    assert_equal "sign_in", inertia_props.fetch("switch_form").fetch("to")
    sign_up_ref = Rack::Utils.parse_nested_query(sign_up.query).fetch("entry_ref")
    sign_up_binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: sign_up_ref, surface: "app")

    assert_predicate original_binding.reload, :switched?
    assert_predicate sign_up_binding, :redeemed?

    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_in" }
    sign_in = URI.parse(commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location))))

    assert_equal "/sign/in/sentry", sign_in.path
    entry_ref = Rack::Utils.parse_nested_query(sign_in.query).fetch("entry_ref")
    drive_to_auth_page!(sign_in.to_s)

    assert_equal "auth/app/sign_ins/new", inertia_component

    assert_equal transaction.id,
                 BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app")
                   .authorization_transaction_id
    assert_predicate sign_up_binding.reload, :switched?
    assert_predicate BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app"),
                     :redeemed?
    assert_equal "pending", transaction.reload.status_name
  end

  test "Switch to Sign Up is refused under prompt=login and leaves the ceremony usable" do
    transaction = start_at_auth_sign_in!(prompt: "login")

    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_up" }

    assert_response :conflict
    assert_not_predicate ceremony_session_for(transaction).reload, :cancelled?
    assert_equal "pending", transaction.reload.status_name
  end

  private

  def start_at_auth_sign_in!(prompt: nil)
    host!(@visa_host)
    https!
    params = {
      response_type: "code",
      client_id: @client.client_id,
      redirect_uri: @redirect_uri,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
    params[:prompt] = prompt if prompt
    get("/oauth/authorize", params: params, headers: browser_navigation_headers)

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

    assert_equal "auth/app/sign_ins/new", inertia_component

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app")
    ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
  end

  # Follows the real browser path from an Auth entry URL: redirects (unwrapping Jump) and the
  # same-origin continuation forms that Auth and Base render, until an Inertia page is reached.
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

  def ceremony_session_for(transaction)
    binding = ClientAuthAdmissionBinding.where(authorization_transaction_id: transaction.id)
      .where.not(admitted_auth_ceremony_session_id: nil).order(:id).first!
    admitted_auth_ceremony_session_for_test(binding)
  end

  def commit_visa_continuation!(visa_location = nil)
    assert_response :see_other if visa_location.nil?
    visa_location ||= URI.parse(jump_rt_url_from_location_for_test(response.location))
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

    response_detail =
      if response.media_type == "text/html"
        response.parsed_body.at_css("body")&.text&.squish&.truncate(120)
      else
        response.media_type
      end

    assert_response :see_other, "Visa continuation returned HTTP #{response.status}: #{response_detail}"
    jump_rt_url_from_location_for_test(response.location)
  end

  def browser_navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }
  end
end
