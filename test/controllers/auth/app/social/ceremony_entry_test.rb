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
    2.times do |index|
      target = URI.parse(@base_browser.response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        target = URI.parse(jump_rt_url_from_location_for_test(target.to_s))
      end
      if index.zero?
        raise RuntimeError,
              "Base authorization host mismatch" unless target.host == visa_host_for_test_base_host(base_host)

        @base_browser.host!(target.host)
        @base_browser.get(target.request_uri)
        form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        @base_browser.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{visa_host_for_test_base_host(base_host)}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      else
        raise RuntimeError, "Auth admission host mismatch" unless target.host == auth_host

        host!(auth_host)
        https!
        get(target.request_uri)
      end
    end
    3.times do |index|
      sender = (index == 1) ? @base_browser : self
      form = Nokogiri::HTML(sender.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      sender.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{(index == 1) ? visa_host_for_test_base_host(base_host) : auth_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      raise RuntimeError, "Social admission failed at step #{index}" unless sender.response.status == 303
      next if index == 2

      receiver = index.zero? ? @base_browser : self
      receiver.get(URI.parse(sender.response.location).request_uri)
    end
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
    test "#{provider} sign-up entry issues a sign-up flow" do
      switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
      assert_difference("ClientSignUpFlow.count", 1) do
        post public_send(:"auth_app_social_#{provider}_registration_path", provider: provider, ri: "jp")
      end

      assert_response :temporary_redirect

      cycle = ClientSignUpFlow.order(:created_at).last

      assert_equal provider, cycle.entry_method
      assert_equal provider, cycle.social_provider
      assert_equal "social_callback", cycle.step
      assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
    end
  end

  # WU-05c (R2-A, A05-3/A05-4): the entry creates the attempt's one Flow; a callback whose Flow is
  # gone is refused and never creates a replacement.
  test "a sign-up callback without its entry Flow is refused and creates no Flow" do
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
    ClientSignUpFlow.order(:id).last.destroy!

    assert_no_difference(["ClientSignUpFlow.count", "Client.count"]) do
      get(
        auth_app_social_google_callback_path, params: { state: state, ri: "jp" }, headers: {
          "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    # D-73: the browser's hint names a Flow its Binding no longer owns, so the uniform error ends nothing.
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
