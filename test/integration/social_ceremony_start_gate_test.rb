# typed: false
# frozen_string_literal: true

require "test_helper"

# `social_ceremony_app_{provider}` must stop the ceremony at its *start*, not
# only at the callback.
#
# The callback gate accepts `:draining` on purpose, so ceremonies issued before
# the switch was flipped can finish. That is only bounded if no new ceremony can
# start: with the start ungated, every new ceremony counts as "issued before the
# disable" and the drain never ends, leaving a switch that looks wired and stops
# nothing.
class SocialCeremonyStartGateTest < ActionDispatch::IntegrationTest
  PROVIDERS = { "google" => :social_ceremony_app_google, "apple" => :social_ceremony_app_apple }.freeze

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

  teardown do
    PROVIDERS.each_value { |feature| Flipper.enable(feature) }
  end

  PROVIDERS.each do |provider, feature|
    test "#{provider} sign-in entry hands off while the provider is enabled" do
      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_response :temporary_redirect
    end

    test "#{provider} sign-in entry is refused while the provider is disabled" do
      Flipper.disable(feature)

      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_response :see_other
      assert_equal auth_app_sign_in_path, URI.parse(response.location).path
    end

    test "#{provider} sign-up entry issues no sign-up flow while the provider is disabled" do
      Flipper.disable(feature)

      assert_no_difference -> { ClientSignUpFlow.count } do
        post public_send(:"auth_app_social_#{provider}_registration_path", ri: "jp")
      end

      assert_response :see_other
    end

    test "#{provider} entry writes no ceremony state while the provider is disabled" do
      Flipper.disable(feature)

      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")

      assert_nil session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]
      assert_nil session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    end
  end

  test "disabling one provider leaves the other running" do
    Flipper.disable(:social_ceremony_app_google)

    post auth_app_social_apple_session_path(ri: "jp")

    assert_response :temporary_redirect
  end
end
