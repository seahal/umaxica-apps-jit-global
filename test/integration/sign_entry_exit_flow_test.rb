# typed: false
# frozen_string_literal: true

require "test_helper"

# D05/D06/D09 on App: Cancel and Switch from the first Sign In page, through the real Base RP start,
# Visa OP admission, Auth exit endpoint, Base RP continuation and Base RP commit.
class SignEntryExitFlowTest < ActionDispatch::IntegrationTest
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
    get(visa_location.request_uri, headers: browser_navigation_headers)

    assert_response :see_other
    first = jump_rt_url_from_location_for_test(response.location)
    canceled_at = transaction.reload.canceled_at
    get(visa_location.request_uri, headers: browser_navigation_headers)

    assert_response :see_other
    assert_equal first, jump_rt_url_from_location_for_test(response.location)
    assert_equal canceled_at, transaction.reload.canceled_at
  end

  test "a canceled parent refuses a later authentication result" do
    transaction = start_at_auth_sign_in!
    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")
    commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location)))

    assert_raises(ArgumentError) do
      transaction.reload.register_authentication!(
        actor_ref: clients(:one).public_id, session_ref: nil, auth_method: "email",
        acr: nil, authentication_event_at: Time.current,
      )
    end
    assert_predicate transaction.reload, :canceled?
  end

  test "Cancel is refused after the ceremony has recorded authentication evidence" do
    transaction = start_at_auth_sign_in!
    ceremony_session_for(transaction).record_authentication_evidence!(method: "email")

    post auth_app_sign_cancellation_url(host: @auth_host, protocol: "https", ri: "jp")

    assert_response :bad_request
    assert_equal "pending", transaction.reload.status
  end

  test "Switch keeps the parent, ends the old ceremony and admits Sign Up for the same parent" do
    transaction = start_at_auth_sign_in!
    old_ceremony = ceremony_session_for(transaction)

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
    location = commit_visa_continuation!(continuation)
    target = URI.parse(jump_rt_url_from_location_for_test(location))

    assert_equal @auth_host, target.host
    assert_equal "/sign/up/sentry", target.path
    entry_ref = Rack::Utils.parse_nested_query(target.query).fetch("entry_ref")
    drive_to_auth_page!(target.to_s)

    assert_equal "auth/app/sign_ups/new", inertia_component
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app")

    assert_equal transaction.id, binding.authorization_transaction_id
    assert_equal "pending", transaction.reload.status
  end

  test "switching to Sign Up and back to Sign In keeps one parent" do
    transaction = start_at_auth_sign_in!
    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_up" }
    sign_up = URI.parse(commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location))))
    drive_to_auth_page!(sign_up.to_s)

    assert_equal "auth/app/sign_ups/new", inertia_component
    assert_equal "sign_in", inertia_props.fetch("switch_form").fetch("to")

    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_in" }
    sign_in = URI.parse(commit_visa_continuation!(URI.parse(jump_rt_url_from_location_for_test(response.location))))

    assert_equal "/sign/in/sentry", sign_in.path
    entry_ref = Rack::Utils.parse_nested_query(sign_in.query).fetch("entry_ref")
    drive_to_auth_page!(sign_in.to_s)

    assert_equal "auth/app/sign_ins/new", inertia_component

    assert_equal transaction.id,
                 BaseAuthAdmissionCoordinator.find_admission_binding!(reference: entry_ref, surface: "app")
                   .authorization_transaction_id
    assert_equal "pending", transaction.reload.status
  end

  test "Switch to Sign Up is refused under prompt=login and leaves the ceremony usable" do
    transaction = start_at_auth_sign_in!(prompt: "login")

    post auth_app_sign_switch_url(host: @auth_host, protocol: "https", ri: "jp"), params: { to: "sign_up" }

    assert_response :bad_request
    assert_not_predicate ceremony_session_for(transaction).reload, :cancelled?
    assert_equal "pending", transaction.reload.status
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

    assert_response :see_other
    jump_rt_url_from_location_for_test(response.location)
  end

  def browser_navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }
  end
end
