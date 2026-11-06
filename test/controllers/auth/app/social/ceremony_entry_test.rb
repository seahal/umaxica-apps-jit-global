# typed: false
# frozen_string_literal: true

require "test_helper"

# What the POST entry writes before handing the request to the OmniAuth request
# phase. The handoff itself and the absence of a GET entry are covered by
# test/integration/social_ceremony_entry_contract_test.rb.
class Auth::App::Social::CeremonyEntryTest < ActionDispatch::IntegrationTest
  setup do
    ri = "jp"
    @base_browser = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/sign", params: { ri: ri, pt: "/dashboard?ri=#{ri}" })
    form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    JitSecurityJwtRegistry.surface("BASE_APP")
    # The Base sign entry hands the browser to the Visa OP authorize endpoint, which
    # relays an unauthenticated browser to the Auth sign-in entry. The Auth admission
    # then runs its ceremony-binding confirmation on Visa and redeems the reference,
    # so the chain must be followed until Auth renders the sign-in page itself.
    admission_browser = @base_browser
    12.times do |admission_index|
      raise RuntimeError, "Social admission stopped before a redirect" unless admission_browser.response.redirect?

      target = URI.parse(admission_browser.response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      3.times do
        break unless target.host == "jump.umaxica.net"

        unwrapped = URI.parse(jump_rt_url_from_location_for_test(target.to_s))
        break if unwrapped.to_s == target.to_s

        target = unwrapped
      end
      if admission_index.zero?
        raise RuntimeError,
              "Base authorization host mismatch" unless target.host == visa_host_for_test_base_host(base_host)
      elsif admission_index == 1
        raise RuntimeError, "Auth admission host mismatch" unless target.host == auth_host
      end
      next_browser =
        if target.host.nil?
          admission_browser
        elsif target.host == auth_host
          self
        else
          @base_browser
        end
      next_browser.host!(target.host) if target.host
      next_browser.https!
      next_browser.get(
        target.request_uri, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        },
      )
      admission_browser = next_browser
      break if next_browser == self && !response.redirect?
    end

    assert_equal [auth_host, 200], [request.host, response.status]
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
  end

  test "sign-in entry binds provider state to the admitted SID without a signed social grant" do
    assert_no_difference(["ClientToken.count", "ClientSocialCeremonyTransaction.count"]) do
      post auth_app_social_google_session_path(provider: "google", ri: "jp")
    end

    assert_response :temporary_redirect
    assert_nil session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_STARTED_AT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PROVIDER_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PT_SESSION_KEY]
    state = session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    assert_predicate state, :present?
    assert_equal "google", session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_equal "sign_in", session[SocialAuth::SOCIAL_ENTRY_SESSION_KEY]
    assert ClientAuthCeremonySession.where.not(admitted_at: nil).any?(&:active?)
  end

  %w(google apple).each do |provider|
    test "#{provider} sign-up attempt issues its sign-up flow at the verified callback" do
      previous_test_mode = OmniAuth.config.test_mode
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider: provider, uid: "entry-flow-#{provider}-#{SecureRandom.hex(4)}", info: { name: "Fixture" },
        credentials: { token: "fixture", expires_at: 1.hour.from_now.to_i },
      )
      switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
      # The entry hands off to the provider without issuing a Flow; the verified
      # callback issues the attempt's one Flow (AppSocialCeremonyEntry).
      assert_no_difference("ClientSignUpFlow.count") do
        post(public_send(:"auth_app_social_#{provider}_registration_path", provider: provider, ri: "jp"))
      end

      assert_response :temporary_redirect
      state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

      assert_difference("ClientSignUpFlow.count", 1) do
        get(
          public_send(:"auth_app_social_#{provider}_callback_path"),
          params: { state: state, ri: "jp" },
          headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :found
      cycle = ClientSignUpFlow.order(:created_at).last

      assert_equal provider, cycle.entry_method
      assert_equal provider, cycle.social_provider
      assert_equal "checkpoint", cycle.step
      assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
    ensure
      OmniAuth.config.mock_auth[provider.to_sym] = nil
      OmniAuth.config.test_mode = previous_test_mode
    end
  end

  # WU-05c (R2-A, A05-3/A05-4): a sign-up attempt owns one Flow; a callback whose
  # admission already owns a Flow is refused and never creates a replacement.
  test "a sign-up callback whose entry Flow already exists is refused and creates no Flow" do
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: "entry-flow-#{SecureRandom.hex(4)}", info: { name: "Fixture" },
      credentials: { token: "fixture", expires_at: 1.hour.from_now.to_i },
    )
    switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
    post(auth_app_social_google_registration_path(ri: "jp"))

    assert_response :temporary_redirect
    state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    # The entry issues no Flow; stage the attempt's own Flow as an already-issued
    # one, which is the state a second issuance must never duplicate.
    binding = ClientAuthAdmissionBinding.order(:id).last
    now = Time.current
    ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 10.minutes,
      entry_method: "google",
      social_provider: "google",
      return_to: auth_app_sign_up_path(ri: "jp"),
    )

    assert_no_difference(["ClientSignUpFlow.count", "Client.count"]) do
      get(
        auth_app_social_google_callback_path, params: { state: state, ri: "jp" }, headers: {
          "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    # D-73: the callback must not issue a second Flow for an admission that already
    # owns one, so the uniform error ends nothing.
    assert_response :bad_request
  ensure
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.test_mode = previous_test_mode
  end

  # The provider comes from a route default, so an unsupported one is not
  # reachable through routing. Only the two supported providers have routes.
  test "no route exists for a provider outside the supported set" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/social/microsoft/session", method: :post)
    end
  end
end
