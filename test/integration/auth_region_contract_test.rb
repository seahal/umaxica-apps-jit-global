# typed: false
# frozen_string_literal: true

require "test_helper"

# The Auth credential gateway must carry the same region contract as Base: every browser-facing
# page normalizes a missing or unrecognized `ri` to the default region, and every URL it generates
# carries the region forward.
#
# The sign-in and sign-up pages used to skip `PreferenceGlobal#set_region`. A request without `ri`
# therefore rendered with no region in the request context and produced region-less links, and a
# request with an unrecognized `ri` propagated that unvalidated value into every generated URL.
class AuthRegionContractTest < ActionDispatch::IntegrationTest
  SURFACES = [
    ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL")],
    ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")],
    ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL")],
  ].freeze

  ENTRY_PATHS = %w(/sign/in /sign/up).freeze
  INTENT_BY_PATH = { "/sign/in" => "sign_in", "/sign/up" => "sign_up" }.freeze
  REALM_BY_SURFACE = { "app" => "client", "com" => "visitor", "org" => "operator" }.freeze

  test "a missing region is normalized on every credential gateway entry page" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        host! host
        get path

        assert_response :found, "#{surface} #{path} must normalize a missing region"
        assert_equal "http://#{host}#{path}?ri=jp", response.location
      end
    end
  end

  test "an unrecognized region is normalized instead of being propagated" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        host! host
        get path, params: { ri: "xx" }

        assert_response :found, "#{surface} #{path} must normalize an unrecognized region"
        assert_equal "http://#{host}#{path}?ri=jp", response.location
      end
    end
  end

  test "the Base root link to the neutral sign entry carries the region" do
    %w(jp us).each do |region|
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      get base_app_root_path, params: { ri: region }

      assert_response :success

      sign_in_href = inertia_props.dig("sign_in", "href")
      query = Rack::Utils.parse_nested_query(URI.parse(sign_in_href).query)

      assert_equal region, query["ri"],
                   "the neutral sign link dropped the #{region} region: #{sign_in_href}"
    end
  end

  # A bare hit on an entry page is refused (E01): Auth is ceremony-only and requires a Base-issued
  # admission code. Redeeming a real one is the only way to reach the rendered page this test needs
  # to scan.
  test "every generated link on an entry page carries the requested region" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        %w(jp us).each do |region|
          host! host
          begin
            fv5063 = path
            fv5062 = admission_reference_for(surface, path)
            fv5061 = :entry_ref
            fv5060 = { ri: region }
            fv5059 = { "Host" => host }
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
                fv5004.post(
                  fv5047,
                  params: fv5046.merge(authenticity_token: fv5045),
                  headers: fv5013,
                )
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
                        raise RuntimeError,
                              "Auth continuation form is missing" unless fv5007

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

          assert_response :see_other, "#{surface} #{path}?ri=#{region} admission redemption must succeed"
          follow_redirect!

          assert_response :success, "#{surface} #{path}?ri=#{region} must render"

          relative = response.body.scan(/(?:href|action)="(\/[^"]*)"/).flatten.uniq
          missing = relative.reject { |target| asset_target?(target) || target.include?("ri=#{region}") }

          assert_empty missing,
                       "#{surface} #{path}?ri=#{region} generated links without the region: #{missing.inspect}"
        end
      end
    end
  end

  private

  # The layout links its surface stylesheet, and a built environment additionally emits
  # `<link rel="modulepreload">` for the entrypoint's chunks. Those are assets rather than
  # navigation, and Vite serves them all from its own output directory, so the region does not and
  # must not travel on them.
  def asset_target?(target)
    target.start_with?("/#{ViteRuby.config.public_output_dir}/")
  end

  # Issues a real transaction and redeems it through `BaseAuthAdmissionCoordinator`, the same
  # path `AuthOidcEntrancesTest` and `AuthenticationFlowTest` use, so the code carries a genuine
  # signature rather than a stub -- `AuthCeremonyAdmission#admit_or_render_sign_ceremony!` verifies
  # it for real.
  def admission_reference_for(surface, path)
    client_id = { "app" => "core-app", "com" => "core-com", "org" => "core-org" }.fetch(surface)
    client = OidcClientRegistry.find!(client_id)
    transaction =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: INTENT_BY_PATH.fetch(path),
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch(REALM_BY_SURFACE.fetch(surface)).first,
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
