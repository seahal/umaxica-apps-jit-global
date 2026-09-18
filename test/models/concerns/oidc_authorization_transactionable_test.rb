# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionableTest < ActiveSupport::TestCase
  test "create_transaction! persists a transaction and authorize_params mirrors the public contract" do
    transaction = create_transaction(ClientOidcAuthorizationTransaction, surface: "app")

    assert_equal "pending", transaction.status
    assert_equal(
      {
        response_type: "code",
        client_id: "core-next-rp",
        redirect_uri: "https://example.test/callback",
        scope: "openid email",
        state: "state-one",
        nonce: "nonce-one",
        code_challenge: "challenge-one",
        code_challenge_method: "S256",
      },
      transaction.authorize_params,
    )
  end

  test "persists prompt and max_age across authorization transaction resume" do
    transaction = create_transaction(
      ClientOidcAuthorizationTransaction,
      surface: "app",
      prompt: "login",
      max_age: 300,
    )

    assert_equal "login", transaction.oidc_prompt
    assert_equal 300, transaction.oidc_max_age
    assert_equal "login", transaction.authorize_params.fetch(:prompt)
    assert_equal 300, transaction.authorize_params.fetch(:max_age)
  end

  test "rejects unsupported prompt values and negative max_age" do
    transaction = ClientOidcAuthorizationTransaction.new(
      surface: "app",
      oidc_prompt: "consent",
      oidc_max_age: -1,
    )

    assert_not transaction.valid?
    assert_equal :inclusion, transaction.errors.details[:oidc_prompt].first.fetch(:error)
    assert_equal :greater_than_or_equal_to, transaction.errors.details[:oidc_max_age].first.fetch(:error)
  end

  test "register_authentication! and consume! advance the transaction state" do
    now = Time.zone.local(2026, 6, 19, 14, 0, 0)
    authentication_event_at = now - 5.minutes
    transaction = create_transaction(VisitorOidcAuthorizationTransaction, surface: "com")

    travel_to now do
      transaction = transaction.register_authentication!(
        actor_ref: "visitor-1",
        session_ref: "session-1",
        auth_method: "pwd",
        acr: "",
        authentication_event_at: authentication_event_at,
      )

      assert_predicate transaction, :authenticated?
      assert_equal "aal1", transaction.acr
      assert_equal "visitor-1", transaction.actor_ref
      assert_equal authentication_event_at, transaction.authenticated_at

      transaction = transaction.consume!

      assert_predicate transaction, :consumed?
      assert_equal now, transaction.consumed_at
    end
  end

  test "expired or consumed transactions reject further progress" do
    expired = create_transaction(OperatorOidcAuthorizationTransaction, surface: "org")
    expired.update!(expires_at: 1.minute.ago)

    error =
      assert_raises(ArgumentError) do
        expired.register_authentication!(
          actor_ref: "operator-1",
          session_ref: "session-1",
          auth_method: "pwd",
          acr: "aal2",
          authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
        )
      end
    assert_match(/expired/, error.message)

    transaction = create_transaction(OperatorOidcAuthorizationTransaction, surface: "org", unique: "two")
    transaction = transaction.register_authentication!(
      actor_ref: "operator-1",
      session_ref: "session-1",
      auth_method: "pwd",
      acr: "aal2",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
    transaction.consume!

    error = assert_raises(ArgumentError) { transaction.consume! }
    assert_match(/not authenticated/, error.message)
  end

  test "transaction surface must match the owning class" do
    {
      ClientOidcAuthorizationTransaction => "org",
      OperatorOidcAuthorizationTransaction => "com",
      VisitorOidcAuthorizationTransaction => "app",
    }.each do |transaction_class, invalid_surface|
      transaction = transaction_class.new(surface: invalid_surface)

      assert_not transaction.valid?
      assert_includes transaction.errors[:surface], "does not match transaction store"
    end
  end

  private

  def create_transaction(transaction_class, surface:, unique: "one", prompt: nil, max_age: nil)
    transaction_class.create_transaction!(
      surface: surface,
      intent: "sign_in",
      client_id: "core-next-rp",
      redirect_uri: "https://example.test/callback",
      response_type: "code",
      scope: "openid email",
      state: "state-#{unique}",
      nonce: "nonce-#{unique}",
      code_challenge: "challenge-#{unique}",
      code_challenge_method: "S256",
      login_challenge: "login-#{unique}",
      login_challenge_expires_at: 5.minutes.from_now,
      expires_at: 10.minutes.from_now,
      prompt: prompt,
      max_age: max_age,
    )
  end
end
