# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-in that began at the OIDC authorization endpoint carries a login
# challenge through the auth surface. The sign-in checkpoint is where the
# issued session is bound to the authorization transaction and the browser is
# handed back to the relying party, instead of landing on the ordinary
# post-sign-in destination.
class OidcInitiatedSignInCompletionTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses,
           :client_telephone_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    ClientIdentityState.ensure_defaults!
    @user = clients(:one)
    @address = "oidc_signin_#{SecureRandom.hex(4)}@example.com"
    @email_record = @user.client_emails.create!(address: @address, user_email_status_id: ClientEmailStatus::VERIFIED)
    @user.client_telephones.create!(number: "+819012345901")
    ClientToken.where(user_id: @user.id).delete_all
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the sign-in entry stores the authorization transaction in Auth continuity" do
    admit_sign_in!

    assert_response :success
    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal @transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
  end

  test "the primary factor sends the ceremony to the sign-in checkpoint" do
    admit_sign_in!

    token_count = ClientToken.where(user_id: @user.id).count
    submit_email_otp!

    assert_response :redirect
    assert_equal auth_app_sign_in_check_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_equal token_count, ClientToken.where(user_id: @user.id).count

    ceremony = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_equal "email", ceremony.authentication_method
    assert_predicate ceremony.authentication_event_at, :present?
  end

  test "the local handoff POST binds the signed-in actor to the authorization transaction" do
    admit_sign_in!
    submit_email_otp!

    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_equal @user.public_id, transaction.actor_ref
    assert_nil transaction.session_ref
    assert_predicate transaction.authenticated_at, :present?
    assert_nil transaction.consumed_at, "the authorization endpoint consumes it, not the checkpoint"
  end

  test "the local handoff POST hands the browser to the Base authorization endpoint" do
    admit_sign_in!
    submit_email_otp!

    follow_redirect_to_oidc_handoff!
    post_oidc_handoff!

    assert_response :success
    assert_select "form#oidc-authorization-result-form[method=post]", 1
    assert_select "input[name=result][value]", 1
    assert_select "form#oidc-authorization-result-form" do |forms|
      result_uri = URI.parse(forms.first.attributes.fetch("action").value)
      base_uri = URI.parse(OidcIssuer.absolute_url(ENV.fetch("PUBLIC_BASE_SERVICE_URL")))

      assert_equal "/oauth/authorize", result_uri.path
      assert_equal base_uri.host, result_uri.host
    end
  end

  test "the checkpoint clears the login challenge from the session" do
    admit_sign_in!
    submit_email_otp!

    follow_redirect!

    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "a sign-in that carries no login challenge leaves the transaction unauthenticated" do
    @transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_authorize_params(realm: "client"),
    ).transaction

    post "/sign/in/secret", params: {
      secret_credential_login_form: { identifier: @address, secret_credential_value: "unused" },
    }

    assert_response :not_found
    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_nil transaction.actor_ref
    assert_nil transaction.authenticated_at
  end

  private

  def submit_email_otp!
    post(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { address: @address }, "cf-turnstile-response": "test_token" },
      headers: { "Host" => @host },
    )
    assert_response :found

    otp_private_key = ROTP::Base32.random_base32
    otp_counter = 55_555
    pass_code = ROTP::HOTP.new(otp_private_key).at(otp_counter).to_s
    @email_record.store_otp(otp_private_key, otp_counter, 12.minutes.from_now.to_i)

    patch(
      auth_app_sign_in_email_url(ri: "jp"),
      params: { user_email: { pass_code: pass_code } },
      headers: { "Host" => @host },
    )
  end

  def post_oidc_handoff!
    post(
      auth_app_sign_oidc_handoff_path(ri: "jp"),
      headers: { "Host" => @host },
    )
  end

  def follow_redirect_to_oidc_handoff!
    follow_redirect!
    follow_redirect!
  end

  def admit_sign_in!
    @transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_authorize_params(realm: "client"),
    ).transaction
    reference = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: @transaction).reference
    redeem_auth_ceremony_entry!(
      auth_app_sign_in_path, reference: reference,
                             params: { ri: "jp" }, headers: { "Host" => @host },
    )

    assert_response :see_other
    follow_redirect!
  end

  def oidc_authorize_params(realm:)
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
end
