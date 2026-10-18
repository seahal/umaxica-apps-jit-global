# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthOidcEntrancesTest < ActionDispatch::IntegrationTest
  setup do
    @sign_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @sign_host
    ClientIdentityState.ensure_defaults!
  end

  test "sign in entry accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: authorize_params,
    )

    begin
      fv5136 = admission_reference(issuance)
      fv5135 = { ri: "jp" }
      begin
        fv5134 = auth_app_sign_in_path
        fv5133 = fv5136
        fv5132 = :entry_ref
        fv5131 = fv5135
        fv5130 = { "Host" => @sign_host }
        fv5129 = false
        fv5128 = nil
        fv5127 = nil
        begin
          fv5073 = self
          fv5081 = fv5134
          fv5125 = fv5133
          fv5126 = fv5132
          fv5090 = fv5131
          fv5083 = fv5130
          fv5113 = fv5129
          fv5112 = fv5128
          fv5086 = fv5127
          fv5080 = fv5090.merge(fv5126 => fv5125)
          fv5073.get(fv5081, params: fv5080, headers: fv5083)
          fv5119 =
            begin
              fv5124 = fv5073.response.body
              fv5123 = true
              fv5122 = Nokogiri::HTML(fv5124).at_css("form")
              if fv5122.nil? && fv5123
                nil
              else
                raise RuntimeError, "Auth continuation form is missing" unless fv5122

                fv5121 = fv5122.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5121.blank?

                fv5120 = fv5122.css("input[type='hidden']").to_h do |fv5077|
                  [fv5077["name"], fv5077["value"]]
                end.except("authenticity_token")
                [fv5122["action"], fv5121, fv5120]
              end
            end
          if fv5119

            fv5118, fv5116, fv5117 = fv5119

            fv5073.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5073.post(
              fv5118, params: fv5117.merge(authenticity_token: fv5116),
                      headers: fv5083,
            )
            fv5115 = fv5073.response.location
            if fv5115.present?

              fv5111 = URI.parse(fv5115)
              fv5110 = fv5111.host
              fv5085 =
                begin
                  fv5114 = fv5110
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5114)
                end
              fv5084 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5085, reference: fv5111.path.split("/").fetch(-2),
              )

              if fv5113
                fv5092 = fv5112 || fv5073
                fv5092.host!(fv5110)
                fv5092.https!
                fv5092.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5109 = fv5111.request_uri
                fv5100 = fv5083.merge(
                  "Host" => fv5110,
                  "Origin" => "https://#{fv5110}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5092.get(fv5109, headers: fv5100)
                fv5103, fv5101, fv5102 =
                  begin
                    fv5108 = fv5092.response.body
                    fv5107 = false
                    fv5106 = Nokogiri::HTML(fv5108).at_css("form")
                    if fv5106.nil? && fv5107
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5106

                      fv5105 = fv5106.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5105.blank?

                      fv5104 = fv5106.css("input[type='hidden']").to_h do |fv5077|
                        [fv5077["name"], fv5077["value"]]
                      end.except("authenticity_token")
                      [fv5106["action"], fv5105, fv5104]
                    end
                  end
                fv5092.post(
                  fv5103,
                  params: fv5102.merge(authenticity_token: fv5101),
                  headers: fv5100,
                )
                begin
                  fv5093 = fv5092
                  fv5095 = "session"
                  fv5094 = fv5093.response.cookies[fv5095]
                  if fv5094.nil?
                    fv5099 = fv5093.response.headers["Set-Cookie"] || fv5093.response.headers["set-cookie"]
                    fv5098 =
                      if fv5099.is_a?(String) && fv5099.start_with?("[")
                        JSON.parse(fv5099)
                      else
                        Array(fv5099)
                      end
                    fv5096 =
                      fv5098.flat_map { |fv5097| fv5097.to_s.split("\n") }.find do |fv5097|
                        fv5097.split(";", 2).first.to_s.start_with?("#{fv5095}=")
                      end
                    if fv5096

                      _, fv5094 = fv5096.split(";", 2).first.to_s.split("=", 2)
                      fv5094 = Rack::Utils.unescape(fv5094.to_s)
                    end
                  end

                  unless fv5094.nil?
                    fv5093.cookies.delete(fv5095)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5093.cookies.merge(
                      "#{fv5095}=#{Rack::Utils.escape(fv5094)}",
                      URI.parse("https://#{fv5093.host}/"),
                    )
                  end
                end
                fv5091 = fv5092.response.location
                raise RuntimeError, "Base confirmation did not return to Auth" if fv5091.blank?

                fv5088 = URI.parse(fv5091)
                if fv5090[:ri].present?
                  fv5089 = Rack::Utils.parse_nested_query(fv5088.query.to_s)
                  fv5089["ri"] ||= fv5090[:ri].to_s
                  fv5088.query = URI.encode_www_form(fv5089)
                end
                fv5073.host!(fv5088.host)
                fv5073.https!
                fv5087 = fv5088.request_uri
                fv5069 = fv5083.merge("Host" => fv5088.host)
                fv5073.get(fv5087, headers: fv5069)
              else
                fv5084.confirm_base!(
                  base_token: fv5086,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5085,
                    entry_ref: fv5084.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5082 = fv5073.host
                fv5073.host!(fv5082)
                fv5073.https!
                fv5069 = fv5083.merge("Host" => fv5082)
                fv5073.get(
                  fv5081,
                  params: fv5080,
                  headers: fv5069,
                )
              end
              fv5072, fv5070, fv5071 =
                begin
                  fv5079 = fv5073.response.body
                  fv5078 = false
                  fv5076 = Nokogiri::HTML(fv5079).at_css("form")
                  if fv5076.nil? && fv5078
                    nil
                  else
                    raise RuntimeError, "Auth continuation form is missing" unless fv5076

                    fv5075 = fv5076.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5075.blank?

                    fv5074 = fv5076.css("input[type='hidden']").to_h do |fv5077|
                      [fv5077["name"], fv5077["value"]]
                    end.except("authenticity_token")
                    [fv5076["action"], fv5075, fv5074]
                  end
                end
              fv5073.post(
                fv5072,
                params: fv5071.merge(authenticity_token: fv5070),
                headers: fv5069,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success

    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal issuance.transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign up entry accepts a valid login challenge" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_up",
      params: authorize_params(screen_hint: "signup"),
    )

    begin
      fv5068 = admission_reference(issuance)
      fv5067 = { ri: "jp" }
      begin
        fv5066 = auth_app_sign_up_path
        fv5065 = fv5068
        fv5064 = :entry_ref
        fv5063 = fv5067
        fv5062 = { "Host" => @sign_host }
        fv5061 = false
        fv5060 = nil
        fv5059 = nil
        begin
          fv5005 = self
          fv5013 = fv5066
          fv5057 = fv5065
          fv5058 = fv5064
          fv5022 = fv5063
          fv5015 = fv5062
          fv5045 = fv5061
          fv5044 = fv5060
          fv5018 = fv5059
          fv5012 = fv5022.merge(fv5058 => fv5057)
          fv5005.get(
            fv5013,
            params: fv5012, headers: fv5015,
          )
          fv5051 =
            begin
              fv5056 = fv5005.response.body
              fv5055 = true
              fv5054 = Nokogiri::HTML(fv5056).at_css("form")
              if fv5054.nil? && fv5055
                nil
              else
                raise RuntimeError,
                      "Auth continuation form is missing" unless fv5054

                fv5053 = fv5054.at_css("input[name='authenticity_token']")&.[]("value")
                raise RuntimeError,
                      "Auth continuation is missing its CSRF token" if fv5053.blank?

                fv5052 = fv5054.css("input[type='hidden']").to_h do |fv5009|
                  [fv5009["name"], fv5009["value"]]
                end.except("authenticity_token")
                [fv5054["action"], fv5053,
                 fv5052,]
              end
            end
          if fv5051

            fv5050, fv5048, fv5049 = fv5051

            fv5005.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
              "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
            fv5005.post(
              fv5050, params: fv5049.merge(authenticity_token: fv5048),
                      headers: fv5015,
            )
            fv5047 = fv5005.response.location
            if fv5047.present?

              fv5043 = URI.parse(fv5047)
              fv5042 = fv5043.host
              fv5017 =
                begin
                  fv5046 = fv5042
                  {
                    ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                    ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                    ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                  }.fetch(fv5046)
                end
              fv5016 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                surface: fv5017, reference: fv5043.path.split("/").fetch(-2),
              )

              if fv5045
                fv5024 = fv5044 || fv5005
                fv5024.host!(fv5042)
                fv5024.https!
                fv5024.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                  "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                fv5041 = fv5043.request_uri
                fv5032 = fv5015.merge(
                  "Host" => fv5042,
                  "Origin" => "https://#{fv5042}",
                  "Sec-Fetch-Site" => "same-origin",
                )
                fv5024.get(
                  fv5041,
                  headers: fv5032,
                )
                fv5035, fv5033, fv5034 =
                  begin
                    fv5040 = fv5024.response.body
                    fv5039 = false
                    fv5038 = Nokogiri::HTML(fv5040).at_css("form")
                    if fv5038.nil? && fv5039
                      nil
                    else
                      raise RuntimeError,
                            "Auth continuation form is missing" unless fv5038

                      fv5037 = fv5038.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5037.blank?

                      fv5036 = fv5038.css("input[type='hidden']").to_h do |fv5009|
                        [fv5009["name"], fv5009["value"]]
                      end.except("authenticity_token")
                      [fv5038["action"], fv5037,
                       fv5036,]
                    end
                  end
                fv5024.post(
                  fv5035,
                  params: fv5034.merge(authenticity_token: fv5033),
                  headers: fv5032,
                )
                begin
                  fv5025 = fv5024
                  fv5027 = "session"
                  fv5026 = fv5025.response.cookies[fv5027]
                  if fv5026.nil?
                    fv5031 = fv5025.response.headers["Set-Cookie"] || fv5025.response.headers["set-cookie"]
                    fv5030 =
                      if fv5031.is_a?(String) && fv5031.start_with?("[")
                        JSON.parse(fv5031)
                      else
                        Array(fv5031)
                      end
                    fv5028 =
                      fv5030.flat_map { |fv5029|
                        fv5029.to_s.split("\n")
                      }.find do |fv5029|
                        fv5029.split(
                          ";",
                          2,
                        ).first.to_s.start_with?("#{fv5027}=")
                      end
                    if fv5028

                      _, fv5026 = fv5028.split(";", 2).first.to_s.split(
                        "=", 2,
                      )
                      fv5026 = Rack::Utils.unescape(fv5026.to_s)
                    end
                  end

                  unless fv5026.nil?
                    fv5025.cookies.delete(fv5027)
                    # Rack::Test's []= uses its default host. The current request may target a
                    # different surface, so install the cookie against the browser's active host.
                    fv5025.cookies.merge(
                      "#{fv5027}=#{Rack::Utils.escape(fv5026)}",
                      URI.parse("https://#{fv5025.host}/"),
                    )
                  end
                end
                fv5023 = fv5024.response.location
                raise RuntimeError,
                      "Base confirmation did not return to Auth" if fv5023.blank?

                fv5020 = URI.parse(fv5023)
                if fv5022[:ri].present?
                  fv5021 = Rack::Utils.parse_nested_query(fv5020.query.to_s)
                  fv5021["ri"] ||= fv5022[:ri].to_s
                  fv5020.query = URI.encode_www_form(fv5021)
                end
                fv5005.host!(fv5020.host)
                fv5005.https!
                fv5019 = fv5020.request_uri
                fv5001 = fv5015.merge("Host" => fv5020.host)
                fv5005.get(
                  fv5019,
                  headers: fv5001,
                )
              else
                fv5016.confirm_base!(
                  base_token: fv5018,
                  browser_digest: AuthAdmissionBinding.browser_digest(
                    surface: fv5017,
                    entry_ref: fv5016.entry_ref,
                    nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                  ),
                )
                fv5014 = fv5005.host
                fv5005.host!(fv5014)
                fv5005.https!
                fv5001 = fv5015.merge("Host" => fv5014)
                fv5005.get(
                  fv5013,
                  params: fv5012, headers: fv5001,
                )
              end
              fv5004, fv5002, fv5003 =
                begin
                  fv5011 = fv5005.response.body
                  fv5010 = false
                  fv5008 = Nokogiri::HTML(fv5011).at_css("form")
                  if fv5008.nil? && fv5010
                    nil
                  else
                    raise RuntimeError,
                          "Auth continuation form is missing" unless fv5008

                    fv5007 = fv5008.at_css("input[name='authenticity_token']")&.[]("value")
                    raise RuntimeError,
                          "Auth continuation is missing its CSRF token" if fv5007.blank?

                    fv5006 = fv5008.css("input[type='hidden']").to_h do |fv5009|
                      [fv5009["name"], fv5009["value"]]
                    end.except("authenticity_token")
                    [fv5008["action"], fv5007,
                     fv5006,]
                  end
                end
              fv5005.post(
                fv5004,
                params: fv5003.merge(authenticity_token: fv5002),
                headers: fv5001,
              )
            end
          end
        end
      end
    end

    assert_response :see_other
    follow_redirect!

    assert_response :success

    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal issuance.transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign in entry without login challenge is refused without admission and stores no challenge" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "sign up entry without login challenge is refused without admission and stores no challenge" do
    get auth_app_sign_up_url(ri: "jp"), headers: { "Host" => @sign_host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
  end

  private

  def admission_reference(issuance)
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: issuance.transaction,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    ).reference
  end

  def authorize_params(screen_hint: nil)
    params = {
      response_type: "code",
      client_id: "core-app-jp",
      redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
    params[:screen_hint] = screen_hint if screen_hint.present?
    params
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class AuthOidcEntrancesTest
  private
end

# DAMP local helper copy on the test class.
class AuthOidcEntrancesTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
