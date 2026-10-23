# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Sign::In::SecretsControllerTest < ActionDispatch::IntegrationTest
  rate_limit_counters!
  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @identifier = "secret-bound-#{SecureRandom.hex(4)}@example.com"
    @client.client_emails.create!(
      address: @identifier, user_email_status_id: ClientEmailStatus::VERIFIED,
    ).finalize_binding!
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  [
    ["missing", :missing], ["null", nil], ["empty", ""], ["numeric zero", 0],
    ["array", []], ["object", {}], ["31 characters", "a" * 31], ["33 characters", "a" * 33],
    ["invalid Base58", "0" * 32], ["embedded NUL", ("a" * 31) + "\0"],
    ["exact case mismatch", "A" * 32], ["unknown 32-character value", "z" * 32],
  ].each_with_index do |(label, value), index|
    test "admitted HTTP Secret rejects #{label} without credential or session mutation" do
      host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      host! host
      https!
      # Distinct real request addresses keep independent input cases within the
      # existing online limits; rate-limit behavior is not stubbed or disabled.
      headers = {
        "REMOTE_ADDR" => "192.0.2.#{index + 10}",
        "Origin" => "https://#{host}",
        "Sec-Fetch-Site" => "same-origin",
      }
      admission, = open_admitted_secret_page(headers)
      page = JSON.parse(response.parsed_body.at_css("script[data-page='app']").text)
      payload = { "identifier" => @identifier, "cf-turnstile-response" => "synthetic" }
      payload[:secret] = value unless value == :missing
      before = ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      token_count = ClientToken.count
      outbox_count = ClientSecretAuditOutbox.count
      post(
        auth_app_sign_in_secret_path(ri: "jp"),
        params: payload,
        as: :json,
        headers: headers.merge("X-CSRF-Token" => page.fetch("props").fetch("authenticity_token")),
      )

      assert_response :unprocessable_content
      assert_equal before,
                   ClientSecretCredential.order(:id).pluck(:id, :claimed_at, :consumed_at, :revoked_at, :discard_at)
      assert_equal token_count, ClientToken.count
      assert_equal outbox_count, ClientSecretAuditOutbox.count
      assert_nil admission.transaction.reload.secret_sign_in_flow_id
    end
  end

  test "admitted Secret page links back to the sign-in method selection" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = { "REMOTE_ADDR" => "192.0.2.40", "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
    open_admitted_secret_page(headers)

    assert_response :ok
    back_link = inertia_props.fetch("back_link")

    assert_equal I18n.t("sign.app.authentication.new.back"), back_link.fetch("label")
    back_uri = URI.parse(back_link.fetch("href"))

    assert_equal URI.parse(auth_app_sign_in_path(ri: "jp")).path, back_uri.path
    query = Rack::Utils.parse_nested_query(back_uri.query)

    assert_equal "jp", query.fetch("ri")
    assert_nil query["fb"]
  end

  test "known and unknown identifiers reach the same limit across request addresses" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    https!
    headers = { "REMOTE_ADDR" => "192.0.2.80",
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin", }
    admission = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: "n" * 43, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    ceremony, raw_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session: ceremony, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: binding.entry_ref, nonce: "n" * 43,
      ),
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[cookie_name] = raw_sid
    get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: admission.reference }, headers: headers
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post auth_app_sign_in_path(ri: "jp"),
         params: { entry_ref: admission.reference, authenticity_token: csrf }, headers: headers

    assert_response :see_other
    phase_binding = nil
    get new_auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding), headers: headers
    csrf = inertia_props.fetch("authenticity_token")

    # Failed challenges cannot spend a chosen identifier's shared attempt budget.
    TurnstileVerifierStub.challenge_response = { "success" => false }
    6.times do |index|
      post auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding),
           params: { identifier: @identifier, secret: "z" * 32 },
           headers: headers.merge("REMOTE_ADDR" => "192.0.2.#{200 + index}", "X-CSRF-Token" => csrf)

      assert_response :unprocessable_content
    end
    TurnstileVerifierStub.challenge_response = { "success" => true }
    results = []
    [@identifier, "secret-unknown@example.test"].each_with_index do |identifier, partition|
      statuses = []
      7.times do |index|
        submitted_identifier = (index >= 5) ? " #{identifier.upcase} " : identifier
        post auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding),
             params: { :identifier => submitted_identifier,
                       :secret => "z" * 32,
                       "cf-turnstile-response" => "synthetic", },
             headers: headers.merge(
               "REMOTE_ADDR" => "192.0.2.#{100 + (partition * 10) + index}",
               "X-CSRF-Token" => csrf,
             )
        statuses << response.status

        assert_nil response.headers["Location"]
      end
      results << statuses
    end

    assert_equal [422, 422, 422, 422, 422, 429, 429], results.first
    assert_equal results.first, results.last
    assert_nil admission.transaction.reload.secret_sign_in_flow_id
  end

  test "legacy Secret GET remains absent while canonical actions require browser admission" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host

    get "/sign/in/secret"

    assert_response :not_found

    assert_no_difference("ClientSecretCredential.count") do
      get new_auth_app_sign_in_secret_path(ri: "jp")

      assert_response :bad_request
    end
    assert_no_difference -> { ClientSecretCredential.where.not(claimed_at: nil).count } do
      assert_no_difference("ClientToken.count") do
        post auth_app_sign_in_secret_path(ri: "jp"), params: { secret: "a" * 32 }

        assert_response :bad_request
      end
    end
  end

  private

  # Admits a Base local sign-in entry into this browser and opens the Secret page through the
  # canonical continuation, returning the admission and the PRIMARY_PENDING phase binding.
  def open_admitted_secret_page(headers)
    admission = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: admission.reference)
    admission_session, raw_auth_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session: admission_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: binding.class.auth_admission_surface_name,
        entry_ref: binding.entry_ref,
        nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      ),
    )
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies[cookie_name] = raw_auth_sid
    get(auth_app_sign_in_path(ri: "jp"), params: { entry_ref: admission.reference }, headers: headers)
    csrf = response.parsed_body.at_css('input[name="authenticity_token"]')["value"]
    post(
      auth_app_sign_in_path(ri: "jp"), params: {
        entry_ref: admission.reference, authenticity_token: csrf,
      }, headers: headers,
    )

    assert_response :see_other
    phase_binding = nil
    get(new_auth_app_sign_in_secret_path(ri: "jp", fb: phase_binding), headers: headers)
    [admission, phase_binding]
  end
end
