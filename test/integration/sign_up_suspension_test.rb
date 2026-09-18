# typed: false
# frozen_string_literal: true

require "test_helper"

# `sign_up_suspended_{surface}` is an operational kill switch: it closes new
# registration on one trust boundary without touching sign-in and without
# affecting the other two surfaces.
#
# Ceremony entry pages require Base-issued opaque admission before they render.
# Suspension itself is enforced in a before_action, so 503 assertions still hit
# the entry URL directly; "open" / "unaffected" assertions redeem admission first.
class SignUpSuspensionRequestTest < ActionDispatch::IntegrationTest
  SURFACES = {
    app: { host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"), feature: :sign_up_suspended_app },
    com: { host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"), feature: :sign_up_suspended_com },
    org: { host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"), feature: :sign_up_suspended_org },
  }.freeze

  FIRST_PARTY_CLIENT_IDS = {
    app: "core-app",
    com: "core-com",
    org: "core-org",
  }.freeze

  teardown do
    SURFACES.each_value { |surface| Flipper.disable(surface.fetch(:feature)) }
  end

  SURFACES.each do |surface, config|
    test "#{surface} sign-up entry is open while the switch is off" do
      skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

      visit_admitted_ceremony!(surface: surface, intent: "sign_up")

      assert_response :success
    end

    test "#{surface} sign-up entry answers 503 while suspended" do
      Flipper.enable(config.fetch(:feature))
      host! config.fetch(:host)

      get sign_up_path_for(surface)

      assert_response :service_unavailable
      # The suspension notice is the prop the entry page renders in place of its registration
      # entry points; its presence is what "the page says sign-up is suspended" means now.
      assert_equal I18n.t("errors.messages.sign_up_suspended"), inertia_props.fetch("suspended_notice")
    end

    test "#{surface} sign-in entry is unaffected by the sign-up switch" do
      skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

      Flipper.enable(config.fetch(:feature))
      visit_admitted_ceremony!(surface: surface, intent: "sign_in")

      assert_response :success
    end
  end

  test "suspending one surface leaves the others open" do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

    Flipper.enable(:sign_up_suspended_app)

    visit_admitted_ceremony!(surface: :com, intent: "sign_up")

    assert_response :success

    visit_admitted_ceremony!(surface: :org, intent: "sign_up")

    assert_response :success
  end

  # The identifier entry is where a registration actually starts, so a suspended
  # surface must reject it too -- a landing page that merely hides its links
  # would still accept a direct POST.
  test "app email registration entry answers 503 while suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    # `ri` is supplied so the region redirect that precedes the guard does not
    # answer first; the assertion is about the guard, not about that redirect.
    get new_auth_app_sign_up_email_path(ri: "jp")

    assert_response :service_unavailable
  end

  # The social ceremony entry shares its concern with sign-in, so only the
  # sign-up branch may be closed, and it must be closed before any ceremony
  # state is written.
  test "app social registration entry answers 503 and issues no sign-up flow while suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    assert_no_difference -> { ClientSignUpFlow.count } do
      post auth_app_social_google_registration_path
    end

    assert_response :service_unavailable
  end

  test "app social sign-in entry still starts its ceremony while sign-up is suspended" do
    Flipper.enable(:sign_up_suspended_app)
    host! SURFACES.fetch(:app).fetch(:host)

    post auth_app_social_google_session_path

    assert_response :temporary_redirect
  end

  private

  # `ri` is supplied so the region normalization that precedes the guard does not answer first;
  # these assertions are about the guard, not about that redirect.
  def sign_up_path_for(surface)
    public_send(:"auth_#{surface}_sign_up_path", ri: "jp")
  end

  def sign_in_path_for(surface)
    public_send(:"auth_#{surface}_sign_in_path", ri: "jp")
  end

  def visit_admitted_ceremony!(surface:, intent:)
    host = SURFACES.fetch(surface).fetch(:host)
    host!(host)
    _transaction, code = issue_admission!(surface: surface.to_s, intent: intent)

    path =
      if intent == "sign_up"
        public_send(:"auth_#{surface}_sign_up_path", ri: "jp", admission: code)
      else
        public_send(:"auth_#{surface}_sign_in_path", ri: "jp", admission: code)
      end

    get(path, headers: { "Host" => host })

    assert_response :see_other
    follow_redirect!
  end

  def issue_admission!(surface:, intent:)
    client_id = FIRST_PARTY_CLIENT_IDS.fetch(surface.to_sym)
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: surface,
        intent: intent,
        params: {
          response_type: "code",
          client_id: client_id,
          redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      )
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: issuance.transaction)
    [issuance.transaction, handoff.code]
  end
end
