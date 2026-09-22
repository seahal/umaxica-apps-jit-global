# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationTransactionableTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @transaction_prefix = "oidc-authorization-transaction-test-#{SecureRandom.hex(8)}"
  end

  teardown do
    [
      ClientOidcAuthorizationTransaction,
      VisitorOidcAuthorizationTransaction,
      OperatorOidcAuthorizationTransaction,
    ].each do |transaction_class|
      transaction_class.where("login_challenge LIKE ?", "#{@transaction_prefix}-%").delete_all
    end
  end

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

      transaction = transaction.consume!(now: now)

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

  test "an authenticated transaction cannot be overwritten by another result" do
    transaction = create_transaction(ClientOidcAuthorizationTransaction, surface: "app")
    first_event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    second_event_at = first_event_at + 1.minute

    transaction.register_authentication!(
      actor_ref: "client-1",
      session_ref: "session-1",
      auth_method: "passkey",
      acr: "aal2",
      authentication_event_at: first_event_at,
    )

    error =
      assert_raises(ArgumentError) do
        transaction.register_authentication!(
          actor_ref: "client-2",
          session_ref: "session-2",
          auth_method: "password",
          acr: "aal1",
          authentication_event_at: second_event_at,
        )
      end

    assert_equal "authorization transaction is not pending", error.message
    transaction.reload

    assert_equal "client-1", transaction.actor_ref
    assert_equal "session-1", transaction.session_ref
    assert_equal first_event_at, transaction.authenticated_at
    assert_equal "aal2", transaction.acr
  end

  test "concurrent authentication results have exactly one winner" do
    transaction = create_transaction(VisitorOidcAuthorizationTransaction, surface: "com")
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    threads =
      Array.new(2) do |index|
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          VisitorOidcAuthorizationTransaction.connection_pool.with_connection do
            ready << true
            release.pop
            VisitorOidcAuthorizationTransaction.find(transaction.id).register_authentication!(
              actor_ref: "visitor-#{index}",
              session_ref: "session-#{index}",
              auth_method: "passkey",
              acr: "aal2",
              authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5) + index,
            )
            results << :success
          rescue ArgumentError => e
            results << e.message
          rescue StandardError => e
            results << e
          end
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)
    outcomes = 2.times.map { results.pop }

    assert_equal 1, outcomes.count(:success), outcomes.inspect
    assert_equal 1, outcomes.count("authorization transaction is not pending"), outcomes.inspect
    assert_predicate transaction.reload, :authenticated?

    assert_includes %w(visitor-0 visitor-1), transaction.actor_ref
  end

  test "concurrent authorization grant redemption has exactly one winner" do
    transaction = create_transaction(VisitorOidcAuthorizationTransaction, surface: "com")
    transaction.register_authentication!(
      actor_ref: "visitor-concurrent",
      session_ref: nil,
      auth_method: "passkey",
      acr: "aal2",
      authentication_event_at: Time.utc(2026, 1, 2, 3, 4, 5),
    )
    transaction.finalize_base! do |_locked, _now|
      { status: :success, browser_session_ref: "browser-session-concurrent" }
    end

    ActiveRecord::Base.connection_handler.clear_active_connections!
    results = Queue.new
    threads =
      2.times.map do
        Thread.new do # rubocop:disable ThreadSafety/NewThread
          VisitorOidcAuthorizationTransaction.connection_pool.with_connection do
            results << VisitorOidcAuthorizationTransaction.find(transaction.id).claim_authorization_grant!
          end
        rescue StandardError => e
          results << e
        end
      end
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }

    assert_equal 1, outcomes.count(true), outcomes.inspect
    assert_equal 1, outcomes.count(false), outcomes.inspect
    assert_predicate transaction.reload.authorization_grant_redeemed_at, :present?
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
    transaction = transaction_class.create_transaction!(
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
      login_challenge: "#{@transaction_prefix}-#{unique}",
      login_challenge_expires_at: 5.minutes.from_now,
      expires_at: 10.minutes.from_now,
      prompt: prompt,
      max_age: max_age,
    )
    transaction
  end
end
