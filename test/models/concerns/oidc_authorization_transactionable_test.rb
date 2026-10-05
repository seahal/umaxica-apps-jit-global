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
    @secret_flow&.destroy!
  end

  test "app OIDC Secret flow reference is optional unique and restricts deletion of its durable proof" do
    now = ClientSignInFlow.database_now
    @secret_flow = ClientSignInFlow.create!(
      status_id: ClientSignInFlowStatus::PRIMARY_PENDING, step: "primary", state: "PRIMARY_PENDING",
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.base58(32)),
      issued_at: now, expires_at: now + 15.minutes,
    )
    transactions =
      Array.new(2) do |index|
        ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app", intent: "authentication", client_id: "secret-reference-test",
          redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
          state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
          code_challenge_method: "S256", login_challenge: "#{@transaction_prefix}-secret-#{index}",
          login_challenge_expires_at: now + 15.minutes, expires_at: now + 15.minutes, now: now,
        )
      end

    assert_nil transactions.first.secret_sign_in_flow
    transactions.first.update!(secret_sign_in_flow: @secret_flow)

    assert_equal @secret_flow.id, transactions.first.reload.secret_sign_in_flow.id
    assert_raises(ActiveRecord::RecordNotUnique) { transactions.last.update!(secret_sign_in_flow: @secret_flow) }
    assert_raises(ActiveRecord::InvalidForeignKey) { transactions.last.update!(secret_sign_in_flow_id: -1) }
    assert_raises(ActiveRecord::InvalidForeignKey) { @secret_flow.destroy! }
    assert ClientSignInFlow.exists?(@secret_flow.id)
    ENV["APP_SECRET_PURGE_DELAY_SECONDS"] = "86400"
    ENV["APP_SECRET_OUTBOX_RETENTION_SECONDS"] = "604800"
    due_at = ClientSignInFlow.database_now
    @secret_flow.update!(discard_at: due_at, purge_eligible_at: due_at)
    RetentionPurgeJob.perform_now(batch_size: 1)

    assert ClientSignInFlow.exists?(@secret_flow.id)
    assert_equal @secret_flow.id, transactions.first.reload.secret_sign_in_flow_id
  end

  test "OIDC admission expiry uses PostgreSQL microsecond neighbors before at and after each deadline" do
    [
      [ClientOidcAuthorizationTransaction, "app"],
      [VisitorOidcAuthorizationTransaction, "com"],
      [OperatorOidcAuthorizationTransaction, "org"],
    ].each do |model, surface|
      deadline = Time.utc(2026, 10, 4, 6, 0, 0, 500_000)
      [-1, 0, 1].each do |microseconds|
        decision_time = deadline + Rational(microseconds, 1_000_000)
        transaction = model.create_transaction!(
          surface: surface, intent: "authentication", client_id: "expiry-test",
          redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
          state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
          code_challenge_method: "S256", login_challenge: "#{@transaction_prefix}-#{surface}-#{microseconds}",
          login_challenge_expires_at: deadline, expires_at: deadline, now: deadline - 1.minute,
        )

        assert_equal microseconds >= 0, transaction.expired?(now: decision_time)
        assert_equal microseconds >= 0, transaction.login_challenge_expired?(now: decision_time)
        if microseconds.negative?
          transaction = transaction.register_authentication!(
            actor_ref: "expiry-test-actor", session_ref: nil, auth_method: "passkey", acr: "aal1",
            authentication_event_at: deadline - 1.minute, now: decision_time,
          )

          assert_predicate transaction, :authenticated?
          assert_equal deadline - 1.minute, transaction.authenticated_at
        else
          assert_raises(ArgumentError) do
            transaction.register_authentication!(
              actor_ref: "expiry-test-actor", session_ref: nil, auth_method: "passkey", acr: "aal1",
              authentication_event_at: deadline - 1.minute, now: decision_time,
            )
          end
          assert_equal "pending", transaction.reload.status
          assert_nil transaction.authenticated_at
        end
      end
    end
  end

  test "OIDC opaque result validation rejects malformed generations and all effective deadline boundaries" do
    [
      [ClientOidcAuthorizationTransaction, "app"],
      [VisitorOidcAuthorizationTransaction, "com"],
      [OperatorOidcAuthorizationTransaction, "org"],
    ].each do |model, surface|
      now = Time.utc(2026, 10, 4, 6, 1, 0, 500_000)
      transaction = model.create_transaction!(
        surface: surface, intent: "authentication", client_id: "result-test",
        redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
        state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
        code_challenge_method: "S256", login_challenge: "#{@transaction_prefix}-result-#{surface}",
        login_challenge_expires_at: now + 20.seconds, expires_at: now + 30.seconds, now: now,
      )
      transaction = transaction.register_authentication!(
        actor_ref: "result-test-actor", session_ref: nil, auth_method: "passkey", acr: "aal1",
        authentication_event_at: now, now: now + 1.second,
      )
      digest = SecureRandom.hex(32)
      transaction, generation = transaction.prepare_result_delivery!(
        result_digest: digest, ttl: 1.minute, now: now + 1.second,
      )

      assert_equal transaction.login_challenge_expires_at, transaction.result_expires_at
      assert transaction.result_delivery_matches?(
        result_digest: digest, result_generation: generation,
        now: now + 2.seconds,
      )
      [nil, 0, 2, "", "1", "1suffix", "1\0", 1.0, false, [], {}].each do |invalid_generation|
        assert_not transaction.result_delivery_matches?(
          result_digest: digest, result_generation: invalid_generation, now: now + 2.seconds,
        ), invalid_generation.inspect
      end
      [nil, "", 0, false, [], {}, "a" * 63, "a" * 65, "\0" * 64].each do |invalid_digest|
        assert_not transaction.result_delivery_matches?(
          result_digest: invalid_digest, result_generation: generation, now: now + 2.seconds,
        ), invalid_digest.inspect
      end
      [-1, 0, 1].each do |microseconds|
        assert_equal microseconds.negative?, transaction.result_delivery_matches?(
          result_digest: digest, result_generation: generation,
          now: transaction.result_expires_at + Rational(microseconds, 1_000_000),
        )
      end
      # Legacy oversized transport expiry must not outlive either durable admission deadline.
      transaction.update!(result_expires_at: now + 10.minutes)

      [transaction.login_challenge_expires_at, transaction.expires_at].each do |deadline|
        assert_not transaction.result_delivery_matches?(
          result_digest: digest, result_generation: generation,
          now: deadline,
        )
      end

      assert_equal now, transaction.authenticated_at
      assert_equal generation, transaction.reload.result_generation
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
