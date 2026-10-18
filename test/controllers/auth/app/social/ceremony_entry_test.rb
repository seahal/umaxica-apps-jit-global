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
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    2.times do |index|
      target = URI.parse(@base_browser.response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
      if index.zero?
        raise RuntimeError, "Base authorization host mismatch" unless target.host == base_host

        @base_browser.get(target.request_uri)
        form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        @base_browser.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
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
          "Origin" => "https://#{(index == 1) ? base_host : auth_host}", "Sec-Fetch-Site" => "same-origin",
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

  # The provider comes from a route default, so an unsupported one is not
  # reachable through routing. Only the two supported providers have routes.
  test "no route exists for a provider outside the supported set" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/social/microsoft/session", method: :post)
    end
  end
end
