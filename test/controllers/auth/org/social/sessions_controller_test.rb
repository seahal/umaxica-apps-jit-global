# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Social::SessionsControllerTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    host! @host
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  teardown do
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  test "staff sign-in page offers the Entra ceremony entry point" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "edit-org",
        redirect_uri: OidcClientRegistry.find!("edit-org").redirect_uris.first,
        code_challenge: "challenge",
        code_challenge_method: "S256",
        state: "state",
        nonce: "nonce",
        scope: "openid profile",
      },
    )
    begin
      fv5063 = "/sign/in"
      fv5062 = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: issuance.transaction,
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        base_token: nil,
      ).reference
      fv5061 = :entry_ref
      fv5060 = { ri: "jp" }
      fv5059 = {}
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
                  fv5023.cookies.merge( # rubocop:disable Lint/Void
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
    entra = inertia_props.fetch("methods").find { |method| method.fetch("key") == "entra" }

    assert_equal "provider", entra.fetch("kind")
    assert_equal auth_org_social_entra_session_path(ri: "jp"), entra.fetch("href")
  end

  # The tenant is fixed in configuration, so the ceremony starts on the press
  # alone -- the same shape as the app surface's Google and Apple buttons.
  test "POST hands the ceremony off with a 307" do
    post auth_org_social_entra_session_path(ri: "jp")

    assert_response :temporary_redirect
    assert_equal "http://#{@host}/social/entra", response.location
  end

  test "POST refuses a provider that does not belong to this surface" do
    post "/social/google/session", params: {}

    assert_response :not_found
  end

  test "GET new renders the ceremony form and asks the operator for nothing" do
    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
    assert_equal "auth/org/social/sessions/new", inertia_component
    assert_equal "/social/entra", inertia_props.fetch("form").fetch("action")
    # The tenant is fixed in configuration, so the page asks the operator for nothing.
    assert_select "input[type=?]", "text", count: 0
  end

  test "GET new renders a form and cannot start the ceremony on its own" do
    # A GET carries no CSRF token, so a GET that started a ceremony would be
    # login CSRF (CVE-2015-9284) - the reason the app surface has no GET entry
    # at all. This GET is a landing page only: it renders the button and sends
    # nothing to Microsoft until a person presses it. Only #create hands off.
    get new_auth_org_social_entra_session_path(ri: "jp")

    assert_response :success
    assert_no_match(
      /\.submit\(\)/, response.body,
      "the landing page must not submit itself: a person has to press the button",
    )
  end

  test "the ceremony start endpoint is not reachable by GET" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :get)
    end
  end

  test "POST fails closed and starts no ceremony when the Entra provider is unavailable" do
    disabled = Object.new
    disabled.define_singleton_method(:start_decision) { |**|
      ExternalAuthentication::AvailabilityDecision.new(
        state: :disabled, source: "test", configuration_version: nil, reason_code: "test_disabled",
        incident_id: nil, observed_at: Time.current,
      )
    }

    ExternalAuthentication::ProviderAvailabilityFactory.stub(:current, disabled) do
      post auth_org_social_entra_session_path(ri: "jp")
    end

    assert_response :service_unavailable
    assert_equal I18n.t("sign.org.authentication.entra.errors.provider_unavailable"),
                 inertia_props.fetch("unavailable_notice")
    assert_nil inertia_props["form"]
  end

  test "POST is rate limited per client address" do
    21.times do
      post auth_org_social_entra_session_path(ri: "jp")
    end

    assert_response :too_many_requests
  end

  test "route recognizes the ceremony start endpoint" do
    route = Rails.application.routes.recognize_path("http://#{@host}/social/entra/session", method: :post)

    assert_equal "auth/org/social/sessions", route[:controller]
    assert_equal "create", route[:action]
    assert_equal "entra", route[:provider]
  end
end
