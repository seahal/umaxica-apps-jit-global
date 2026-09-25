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
    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path, reference: login_challenge_for_sign_in,
                             params: { ri: "jp" }, headers: { "Host" => @host },
    )

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

    assert_response :success
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

    assert_response :see_other
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
    audit_writer = lambda do |**|
      audit_attempts += 1
      false
    end

    AuthenticationAuditWriter.stub(:write, audit_writer) do
      cookies_header = "auth_refresh=#{refresh_plain}"
      get auth_app_sign_in_path(ri: "jp"), headers: { "Cookie" => cookies_header, "Host" => @host }

      assert_response :see_other
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
        client_id: "core-next-rp",
        redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
        code_challenge: SecureRandom.urlsafe_base64(32),
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
      },
    ).transaction
    BaseAuthAdmissionCoordinator.issue_handoff!(transaction: transaction).reference
  end
end
