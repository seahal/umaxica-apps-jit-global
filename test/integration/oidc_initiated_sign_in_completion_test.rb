# typed: false
# frozen_string_literal: true

require "test_helper"

# A sign-in that began at the OIDC authorization endpoint carries a login
# challenge through the auth surface. The sign-in checkpoint is where the
# issued session is bound to the authorization transaction and the browser is
# handed back to the relying party, instead of landing on the ordinary
# post-sign-in destination.
class OidcInitiatedSignInCompletionTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_credential_kinds,
           :client_secret_credential_statuses, :client_email_statuses,
           :client_telephone_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    ClientIdentityState.ensure_defaults!
    @user = clients(:one)
    @address = "oidc_signin_#{SecureRandom.hex(4)}@example.com"
    @user.client_emails.create!(address: @address, user_email_status_id: ClientEmailStatus::VERIFIED)
    @user.client_telephones.create!(number: "+819012345901")
    ClientToken.where(user_id: @user.id).delete_all
    _credential, @raw_secret_credential = ClientSecretCredential.issue!(
      name: "OIDC login",
      user_id: @user.id,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      uses: 10,
      status: :active,
    )
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the sign-in entry stores the login challenge for the rest of the ceremony" do
    admit_sign_in!

    assert_response :success
    assert_equal @transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "the primary factor sends the ceremony to the sign-in checkpoint" do
    admit_sign_in!

    submit_secret_credential!

    assert_response :redirect
    assert_equal auth_app_sign_in_check_path(ri: "jp"), URI.parse(response.location).request_uri
  end

  test "the checkpoint binds the signed-in actor to the authorization transaction" do
    admit_sign_in!
    submit_secret_credential!

    follow_redirect!

    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_equal @user.public_id, transaction.actor_ref
    assert_predicate transaction.authenticated_at, :present?
    assert_nil transaction.consumed_at, "the authorization endpoint consumes it, not the checkpoint"
  end

  test "the checkpoint hands the browser back to the authorization endpoint" do
    admit_sign_in!
    submit_secret_credential!

    follow_redirect!

    assert_response :redirect
    authorize_uri = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(authorize_uri.query)

    assert_equal "/oauth/authorize", authorize_uri.path
    assert_predicate query["result"], :present?
    assert_nil query["login_challenge"]
  end

  test "the checkpoint clears the login challenge from the session" do
    admit_sign_in!
    submit_secret_credential!

    follow_redirect!

    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "a sign-in that carries no login challenge leaves the transaction unauthenticated" do
    @transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_authorize_params(realm: "client"),
    ).transaction

    submit_secret_credential!

    assert_response :redirect
    transaction = ClientOidcAuthorizationTransaction.find_by!(login_challenge: @transaction.login_challenge)

    assert_nil transaction.actor_ref
    assert_nil transaction.authenticated_at
  end

  private

  def submit_secret_credential!
    post(
      auth_app_sign_in_secret_url(ri: "jp"), params: {
        secret_credential_login_form: {
          identifier: @address,
          secret_credential_value: @raw_secret_credential,
        },
        "cf-turnstile-response": "test_token",
      }, headers: { "Host" => @host },
    )
  end

  def admit_sign_in!
    @transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_in", params: oidc_authorize_params(realm: "client"),
    ).transaction
    code = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: @transaction).code
    get(auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host })

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
