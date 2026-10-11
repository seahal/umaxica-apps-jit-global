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
    ["app", ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")],
    ["com", ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")],
    ["org", ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")],
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

  test "the Base-owned local admission form carries the region" do
    %w(jp us).each do |region|
      host! ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
      get base_app_root_path, params: { ri: region }

      assert_response :success

      sign_in_action = inertia_props.dig("sign_in", "action")
      query = Rack::Utils.parse_nested_query(URI.parse(sign_in_action).query)

      assert_equal region, query["ri"],
                   "the local admission form dropped the #{region} region: #{sign_in_action}"
    end
  end

  # A bare, un-bridged hit on an entry page now bounces to Base (`AuthCeremonyAdmission
  # #bridge_to_base_admission!`) instead of rendering -- Auth is ceremony-only and requires a
  # Base-issued admission code. Redeeming a real one is the only way to reach the rendered page
  # this test needs to scan.
  test "every generated link on an entry page carries the requested region" do
    SURFACES.each do |surface, host|
      ENTRY_PATHS.each do |path|
        %w(jp us).each do |region|
          host! host
          get path, params: { ri: region, admission: admission_code_for(surface, path) }

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
  def admission_code_for(surface, path)
    client = OidcClientRegistry.find!("core-next-rp")
    transaction =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: INTENT_BY_PATH.fetch(path),
        params: {
          response_type: "code",
          client_id: "core-next-rp",
          redirect_uri: client.redirect_uris_by_realm.fetch(REALM_BY_SURFACE.fetch(surface)).first,
          code_challenge: SecureRandom.urlsafe_base64(32),
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction).code
  end
end
