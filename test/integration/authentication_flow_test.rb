# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    host! @host
    @user = clients(:one)
    # Ensure master data needed for audit
    ClientChronicleEvent.ensure_defaults! if ClientChronicleEvent.respond_to?(:ensure_defaults!)
    ClientChronicleLevel.ensure_defaults! if ClientChronicleLevel.respond_to?(:ensure_defaults!)

    # Ensure user is active for refresh to work
    # We update status to something active if available, or just rely on 'active?' returning true.
    # NOTHING might be inactive?
    # Let's set it to 'ACTIVE' if possible, or 'ALIVE'.
    # ClientStatus constants: ACTIVE, ALIVE, etc.
    # We need to ensure the status exists too? ClientStatus::ACTIVE might need seeding?
    # Just in case, create ACTIVE status.
    if defined?(ClientStatus)
      ClientStatus.find_or_create_by!(id: ClientStatus::ACTIVE)
      @user.update!(status_id: ClientStatus::ACTIVE, withdrawn_at: nil)
    end
    ClientToken.where(user: @user).delete_all
  end

  test "guest can access login page" do
    begin
      fv5063 = auth_app_sign_in_path
      fv5062 = login_challenge_for_sign_in
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

    assert_response :ok
  end

  test "GET sign-in does not transparently mutate authentication state" do
    token_record = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    refresh_plain = token_record.rotate_refresh_token!
    before = token_record.reload.attributes

    cookies[:auth_refresh] = refresh_plain

    get auth_app_sign_in_path(ri: "jp"), params: { transaction_ref: login_challenge_for_sign_in },
                                         headers: { "Host" => @host }

    assert_response :bad_request
    assert_nil response.headers["Location"]
    assert_equal before, token_record.reload.attributes
  end

  test "GET sign-in with a refresh cookie leaves the refresh credential unchanged" do
    token_record = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    refresh_plain = token_record.rotate_refresh_token!
    before = token_record.reload.attributes

    cookies_header = "auth_refresh=#{refresh_plain}"
    get auth_app_sign_in_path(ri: "jp"), headers: { "Cookie" => cookies_header, "Host" => @host }

    assert_response :bad_request
    assert_equal before, token_record.reload.attributes
  end

  test "GET sign-in does not depend on the refresh audit writer" do
    token_record = ClientToken.create!(
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    refresh_plain = token_record.rotate_refresh_token!
    before = token_record.reload.attributes

    audit_attempts = 0
    audit_writer =
      lambda do |**|
        audit_attempts += 1
        false
      end

    AuthenticationAuditWriter.stub(:write, audit_writer) do
      cookies_header = "auth_refresh=#{refresh_plain}"
      get auth_app_sign_in_path(ri: "jp"), headers: { "Cookie" => cookies_header, "Host" => @host }

      assert_response :bad_request
      assert_equal 0, audit_attempts
      assert_equal before, token_record.reload.attributes
    end
  end

  test "GET sign-in does not revoke or delete an inactive resource's refresh credential" do
    inactive_user = clients(:two)

    assert_not_nil inactive_user, "Fixture clients(:two) must exist for this test"
    inactive_user.update!(withdrawn_at: Time.current)

    assert_not inactive_user.active?, "Client should be inactive after setting withdrawn_at"

    token_record = ClientToken.create!(
      user: inactive_user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    refresh_plain = token_record.rotate_refresh_token!
    token_id = token_record.id
    before = token_record.reload.attributes

    cookies_header = "auth_refresh=#{refresh_plain}"
    get auth_app_sign_in_path, headers: { "Cookie" => cookies_header, "Host" => @host }

    assert_response :redirect
    assert ClientToken.exists?(id: token_id), "GET navigation must not destroy the refresh credential"
    assert_equal before, token_record.reload.attributes,
                 "GET navigation must not revoke or rotate the refresh credential"
  end

  def login_challenge_for_sign_in
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app",
      intent: "sign_in",
      params: {
        response_type: "code",
        client_id: "core-app",
        redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: nil,
    ).reference
  end
end
