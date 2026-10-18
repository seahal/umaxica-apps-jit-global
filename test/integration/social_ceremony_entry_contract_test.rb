# typed: false
# frozen_string_literal: true

require "test_helper"

# The social ceremony entry has two shapes and they must not blur into one:
#
#   POST /social/:provider/session      in-application buttons; the press supplies
#                                       the CSRF token, so the ceremony starts and
#                                       hands the same POST to the OmniAuth request
#                                       phase with a 307
#   GET  /social/:provider/session/new  arrivals that can only be a GET (shared
#                                       links, bookmarks, external sites); nothing
#                                       is sent to the provider until a person
#                                       presses the button
#
# A GET carries no CSRF token, so a GET that started the ceremony on its own would
# be login CSRF (CVE-2015-9284): a link in an email or on another site could sign
# a visitor into an account they did not choose. That is why the request phase is
# POST-only and why the cushion page must not submit itself.
class SocialCeremonyEntryContractTest < ActionDispatch::IntegrationTest
  PROVIDERS = %w(google apple).freeze

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
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
  end

  PROVIDERS.each do |provider|
    test "#{provider} in-application entry hands the POST to the OmniAuth request phase with a 307" do
      post public_send(:"auth_app_social_#{provider}_session_path", ri: "jp"),
           headers: { "Host" => @host }

      # 307 preserves the method and the body, so the authenticity token the
      # button carried reaches the request phase, which verifies it again.
      assert_response :temporary_redirect
      assert_equal "/social/#{provider}", URI.parse(response.location).path
    end

    test "#{provider} sign-up entry hands the POST to the OmniAuth request phase with a 307" do
      post public_send(:"auth_app_social_#{provider}_registration_path", ri: "jp"),
           headers: { "Host" => @host }

      assert_response :temporary_redirect
      assert_equal "/social/#{provider}", URI.parse(response.location).path
    end

    test "#{provider} ceremony cannot be started by a GET" do
      # Only :create is routed, and only as POST. A GET entry carries no token,
      # so a link could start a ceremony: that is the vulnerability this route
      # shape exists to prevent. There is no landing page to add back.
      %W(/social/#{provider}/session /social/#{provider}/session/new
         /social/#{provider}/registration /social/#{provider}/registration/new).each do |path|
        assert_raises(ActionController::RoutingError, "#{path} must not be reachable by GET") do
          Rails.application.routes.recognize_path(path, method: :get)
        end
      end
    end

    test "#{provider} button token is accepted by the OmniAuth request phase" do
      # The token is verified twice, at two different paths: here and again at
      # /social/:provider after the 307. A per-form token is bound to one path
      # and method, so it would pass the first check and fail the second,
      # breaking the handoff for every user. Only a global token survives both.
      issuance = OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id: "core-app-jp",
          redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: "state",
          nonce: "nonce",
          scope: "openid profile",
        },
      )
      begin
        fv5063 = auth_app_sign_in_path
        fv5062 = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        fv5061 = :entry_ref
        fv5060 = { ri: "jp" }
        fv5059 = { "Host" => @host }
        fv5058 = false
        fv5057 = nil
        fv5056 = nil
        begin
          fv5004 = self
          fv5011 = fv5063
          fv5054 = fv5062
          fv5055 = fv5061
          fv5020 = fv5060
          fv5013 = fv5059
          fv5042 = fv5058
          fv5041 = fv5057
          fv5016 = fv5056
          fv5010 = fv5020.merge(fv5055 => fv5054)
          fv5004.get(fv5011, params: fv5010, headers: fv5013)
          fv5048 =
            begin
              fv5053 = fv5004.response.body
              fv5052 = true
              fv5051 = Nokogiri::HTML(fv5053).at_css("form")
              if fv5051.nil? && fv5052
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5051

                fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5050.blank?

                fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                  [input["name"], input["value"]]
                end.except("authenticity_token")
                [fv5051["action"], fv5050, fv5049]
              end
            end
          if fv5048

            fv5047, fv5045, fv5046 = fv5048

            fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5004.post(fv5047, params: fv5046.merge(authenticity_token: fv5045), headers: fv5013)
            fv5044 = fv5004.response.location
            if fv5044.present?

              fv5040 = URI.parse(fv5044)
              fv5039 = fv5040.host
              fv5015 =
                begin
                  fv5043 = fv5039
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5043)
                end
              fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
              )

              if fv5042
                fv5022 = fv5041 || fv5004
                fv5022.host!(fv5039)
                fv5022.https!
                fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5038 = fv5040.request_uri
                fv5029 = fv5013.merge(
                  "Host" => fv5039,
                  "Origin" => "https://#{fv5039}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5022.get(fv5038, headers: fv5029)
                fv5032, fv5030, fv5031 =
                  begin
                    fv5037 = fv5022.response.body
                    fv5036 = false
                    fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                    if fv5035.nil? && fv5036
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5035

                      fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5034.blank?

                      fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5035["action"], fv5034, fv5033]
                    end
                  end
                fv5022.post(
                  fv5032,
                  params: fv5031.merge(authenticity_token: fv5030),
                  headers: fv5029,
                )
                begin
                  fv5023 = fv5022
                  fv5025 = "session"
                  fv5024 = fv5023.response.cookies[fv5025]
                  if fv5024.nil?
                    fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                    fv5027 =
                      if fv5028.is_a?(String) && fv5028.start_with?("[")
                        JSON.parse(fv5028)
                      else
                        Array(fv5028)
                      end
                    fv5026 =
                      fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                        entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                      end
                    if fv5026

                      _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                      fv5024 = Rack::Utils.unescape(fv5024.to_s)
                    end
                  end

                  unless fv5024.nil?
                    fv5023.cookies.delete(fv5025)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5023.cookies.merge(
                      "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                      URI.parse("https://#{fv5023.host}/"),
                    )
                  end
                end
                fv5021 = fv5022.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

                fv5018 = URI.parse(fv5021)
                if fv5020[:ri].present?
                  fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                  fv5019["ri"] ||= fv5020[:ri].to_s
                  fv5018.query = URI.encode_www_form(fv5019)
                end
                fv5004.host!(fv5018.host)
                fv5004.https!
                fv5017 = fv5018.request_uri
                fv5000 = fv5013.merge("Host" => fv5018.host)
                fv5004.get(fv5017, headers: fv5000)
              else
                fv5014.confirm_base!(
                  base_token: fv5016,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5015,
                    entry_ref: fv5014.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5012 = fv5004.host
                fv5004.host!(fv5012)
                fv5004.https!
                fv5000 = fv5013.merge("Host" => fv5012)
                fv5004.get(fv5011, params: fv5010, headers: fv5000)
              end
              fv5003, fv5001, fv5002 =
                begin
                  fv5009 = fv5004.response.body
                  fv5008 = false
                  fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                  if fv5007.nil? && fv5008
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5007

                    fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5006.blank?

                    fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                      [input["name"], input["value"]]
                    end.except("authenticity_token")
                    [fv5007["action"], fv5006, fv5005]
                  end
                end
              fv5004.post(
                fv5003,
                params: fv5002.merge(authenticity_token: fv5001),
                headers: fv5000,
              )
            end
          end
        end
      end

      assert_response :see_other
      follow_redirect!

      assert_response :success

      token = social_button_token(provider)

      assert_predicate token, :present?, "sign-in page carries no authenticity token for #{provider}"

      with_forgery_protection do
        post "/social/#{provider}",
             params: { authenticity_token: token },
             headers: { "Host" => @host, "Sec-Fetch-Site" => "same-origin" }
      end

      assert_response :redirect,
                      "the request phase rejected the request the sign-in button makes"
      assert_match(/\Ahttps:/, response.location)
    end

    test "#{provider} request phase rejects a cross-site submission" do
      # Login CSRF (CVE-2015-9284): a form on another site must not be able to
      # start the ceremony. This also keeps the assertion above from going
      # vacuous, since forgery protection is off by default in this environment.
      with_forgery_protection do
        post "/social/#{provider}",
             params: { authenticity_token: "not-a-real-token" },
             headers: { "Host" => @host, "Sec-Fetch-Site" => "cross-site" }
      end

      # The request phase rejects it, so OmniAuth routes to the failure endpoint
      # instead of the provider.
      assert_response :redirect
      assert_no_match(
        %r{accounts\.google\.com|appleid\.apple\.com}, response.location.to_s,
        "a cross-site submission reached the provider: login CSRF is not being blocked",
      )
    end
  end

  private

  # config/environments/test.rb keeps forgery protection off so the suite can
  # migrate in batches, which makes every CSRF assertion vacuous by default.
  # These requests opt back in.
  def with_forgery_protection
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def social_button_token(provider)
    action = public_send(:"auth_app_social_#{provider}_session_path", ri: "jp")
    button = inertia_props.fetch("social_providers").find { |entry| entry.fetch("action") == action }

    button&.fetch("authenticity_token")
  end
end
