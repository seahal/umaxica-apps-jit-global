# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::Identity::SecretsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_service)
    ensure_client_reference_records!
    # A secret credential may only be registered once the client is contactable.
    @client = create_client_with_verified_email
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "index lists the recovery secrets the client already holds" do
    secret = create_secret_credential

    get base_app_identity_secrets_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
    assert_includes response.body, secret.public_id
  end

  test "index renders for a client with no recovery secret at all" do
    get base_app_identity_secrets_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "new issues a fresh raw secret and keeps only the prefix on the unsaved record" do
    get new_base_app_identity_secret_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
    assert_equal 0, @client.client_secret_credentials.reload.count
  end

  # `new` serializes the plaintext recovery secret into the Inertia page object, so the response
  # must never be reusable from a cache. The com and org surfaces carry the same guarantee.
  test "new forbids caching the page that reveals the plaintext recovery secret" do
    get new_base_app_identity_secret_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
    # Rails rebuilds Cache-Control from its own directive set on the way out, so the concern's
    # literal string is not what ships; `no-store` is the directive that carries the guarantee.
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "show renders a secret the client owns" do
    secret = create_secret_credential

    get base_app_identity_secret_url(secret.public_id, ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "edit renders a secret the client owns" do
    secret = create_secret_credential

    get edit_base_app_identity_secret_url(secret.public_id, ri: "jp", host: @host), headers: step_up_headers

    assert_response :success
  end

  test "show does not find a secret owned by another client" do
    other = create_client_with_verified_email
    foreign = create_secret_credential(client: other)

    get base_app_identity_secret_url(foreign.public_id, ri: "jp", host: @host), headers: step_up_headers

    assert_response :not_found
  end

  test "create persists the secret issued by new and redirects to it" do
    get new_base_app_identity_secret_url(ri: "jp", host: @host), headers: step_up_headers

    assert_response :success

    post base_app_identity_secrets_url(ri: "jp", host: @host),
         params: { user_secret_credential: { name: "Recovery secret" } },
         headers: step_up_headers

    assert_response :see_other
    assert_equal 1, @client.client_secret_credentials.reload.count
  end

  test "update with fresh step-up renames the secret" do
    secret = create_secret_credential

    patch base_app_identity_secret_url(secret.public_id, ri: "jp", host: @host),
          params: { user_secret_credential: { name: "Renamed" } }, headers: step_up_headers

    assert_response :see_other
    assert_equal "Renamed", secret.reload.name
  end

  test "update without fresh step-up is refused and keeps the secret unchanged" do
    secret = create_secret_credential
    original_name = secret.name

    patch base_app_identity_secret_url(secret.public_id, ri: "jp", host: @host),
          params: { user_secret_credential: { name: "Renamed", enabled: "0" } },
          headers: as_user_headers(@client, host: @host)

    assert_response :unauthorized
    assert_equal original_name, secret.reload.name
  end

  test "destroy without fresh step-up is refused and keeps the secret" do
    secret = create_secret_credential

    delete base_app_identity_secret_url(secret.public_id, ri: "jp", host: @host),
           headers: as_user_headers(@client, host: @host)

    assert_response :unauthorized
    assert_equal ClientSecretCredentialStatus::ACTIVE, secret.reload.user_identity_secret_status_id
  end

  private

  def create_client_with_verified_email
    client = Client.create!(status_id: ClientStatus::NOTHING)
    address = "app-secret-#{SecureRandom.hex(6)}@example.com"
    ClientEmail.create!(
      user_id: client.id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: SecureRandom.base64(24),
      otp_counter: "",
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    client.reload
  end

  def create_secret_credential(client: @client)
    ClientSecretCredential.create!(
      user: client,
      name: "Existing secret #{SecureRandom.hex(4)}",
      password: "a" * 32,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
      user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
  end

  # Authentication and step-up material go into the integration cookie jar rather than a literal
  # Cookie header, so the Rails session cookie set by one request survives into the next one.
  def step_up_headers
    return @step_up_headers if @step_up_headers

    headers = as_user_headers(@client, host: @host)
    token = authentication_harness_latest_token(@client)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_secret_credential")
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    access_token = headers["Cookie"].to_s[/#{Regexp.escape(AuthenticationBase::ACCESS_COOKIE_KEY)}=([^;]+)/, 1]
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    cookies[ClientVerification.cookie_name] = raw_token

    @step_up_headers = headers.except("Cookie", "HTTP_COOKIE")
  end

  def ensure_client_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    [
      ClientSecretCredentialStatus::ACTIVE,
      ClientSecretCredentialStatus::DELETED,
    ].each { |id| ClientSecretCredentialStatus.find_or_create_by!(id: id) }
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: ("step_up:app" if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end
end
