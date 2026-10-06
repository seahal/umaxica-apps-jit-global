# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitResolutionTransactionableTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "client resolution binds the parent and revokes only an owned selected session" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    foreign_actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    token = ClientToken.create!(user: actor)
    foreign_token = ClientToken.create!(user: foreign_actor)
    binding = SecureRandom.urlsafe_base64(32)

    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    resolution = issuance.transaction

    assert_predicate resolution, :pending?
    assert_equal [flow.expires_at, resolution.started_at + SessionLimitResolutionTransactionable::TTL].min,
                 resolution.expires_at
    assert_raises(FlowInvalidTransition) do
      resolution.select_session!(
        actor: actor,
        challenge: issuance.challenge,
        session_ref: foreign_token.public_id,
        browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
      )
    end
    assert_predicate resolution.reload, :pending?

    resolution.select_session!(
      actor: actor,
      challenge: issuance.challenge,
      session_ref: token.public_id,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    resolution.resolve!(
      actor: actor,
      challenge: issuance.challenge,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )

    assert_predicate resolution.reload, :resolved?
    assert_not_predicate token.reload, :currently_usable?
    assert_predicate foreign_token.reload, :currently_usable?
    assert_predicate flow.reload, :sign_in_session_issuance_pending?
  end

  test "visitor and operator resolutions use their own realm state and token ownership" do
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    visitor_flow_record = visitor_flow(visitor)
    visitor_token = VisitorToken.create!(visitor: visitor, skip_session_limit_check: true)
    visitor_binding = SecureRandom.urlsafe_base64(32)
    visitor_issuance = VisitorSessionLimitResolutionTransaction.issue!(
      sign_in_flow: visitor_flow_record,
      actor: visitor,
      browser_binding_digest: VisitorSessionLimitResolutionTransaction.digest_challenge(visitor_binding),
    )
    visitor_resolution = visitor_issuance.transaction
    visitor_resolution.select_session!(
      actor: visitor,
      challenge: visitor_issuance.challenge,
      session_ref: visitor_token.public_id,
      browser_binding_digest: VisitorSessionLimitResolutionTransaction.digest_challenge(visitor_binding),
    )
    visitor_resolution.cancel!(
      actor: visitor,
      challenge: visitor_issuance.challenge,
      browser_binding_digest: VisitorSessionLimitResolutionTransaction.digest_challenge(visitor_binding),
    )

    operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    operator_flow_record = operator_flow(operator)
    operator_token = OperatorToken.create!(staff: operator)
    operator_binding = SecureRandom.urlsafe_base64(32)
    operator_issuance = OperatorSessionLimitResolutionTransaction.issue!(
      sign_in_flow: operator_flow_record,
      actor: operator,
      browser_binding_digest: OperatorSessionLimitResolutionTransaction.digest_challenge(operator_binding),
    )
    operator_resolution = operator_issuance.transaction
    operator_resolution.expire!

    assert_equal VisitorSessionLimitResolutionTransaction::CANCELLED, visitor_resolution.reload.state_id
    assert_equal OperatorSessionLimitResolutionTransaction::EXPIRED, operator_resolution.reload.state_id
    assert_predicate visitor_token.reload, :currently_usable?
    assert_predicate operator_token.reload, :currently_usable?
  end

  test "wrong browser binding and terminal replay cannot mutate a resolution" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    token = ClientToken.create!(user: actor)
    binding = SecureRandom.urlsafe_base64(32)
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    resolution = issuance.transaction
    digest = ClientSessionLimitResolutionTransaction.digest_challenge(binding)

    assert_raises(FlowInvalidTransition) do
      resolution.cancel!(
        actor: actor,
        challenge: issuance.challenge,
        browser_binding_digest: "0" * 64,
      )
    end
    resolution.cancel!(actor:, challenge: issuance.challenge, browser_binding_digest: digest)

    assert_same resolution, resolution.cancel!(actor:, challenge: issuance.challenge, browser_binding_digest: digest)
    assert_raises(FlowInvalidTransition) do
      resolution.select_session!(
        actor: actor,
        challenge: issuance.challenge,
        session_ref: token.public_id,
        browser_binding_digest: digest,
      )
    end
  end

  test "issue enforces actor ownership and realm ownership" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    foreign_actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)

    assert_raises(FlowInvalidTransition) do
      ClientSessionLimitResolutionTransaction.issue!(
        sign_in_flow: flow,
        actor: foreign_actor,
        browser_binding_digest: "a" * 64,
      )
    end

    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    assert_raises(ArgumentError) do
      VisitorSessionLimitResolutionTransaction.issue!(
        sign_in_flow: flow,
        actor: visitor,
        browser_binding_digest: "b" * 64,
      )
    end
  end

  test "resolution expiry uses the parent deadline and rejects at -1, exact, and +1" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    binding = SecureRandom.urlsafe_base64(32)
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    resolution = issuance.transaction

    writer_now = ClientSessionLimitResolutionTransaction.database_now
    resolution.update!(expires_at: writer_now - 0.000001)

    assert_not_predicate resolution.reload, :open?
    assert_raises(FlowInvalidTransition) do
      resolution.cancel!(
        actor: actor,
        challenge: issuance.challenge,
        browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
      )
    end
    assert_equal ClientSessionLimitResolutionTransaction::EXPIRED, resolution.reload.state_id

    exact_flow = client_flow(actor)
    exact = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: exact_flow,
      actor: actor,
      browser_binding_digest: "c" * 64,
    ).transaction
    exact.update!(expires_at: ClientSessionLimitResolutionTransaction.database_now)

    assert_not_predicate exact.reload, :open?

    future_flow = client_flow(actor)
    future = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: future_flow,
      actor: actor,
      browser_binding_digest: "d" * 64,
    ).transaction
    future.update!(expires_at: ClientSessionLimitResolutionTransaction.database_now + 1.second)

    assert_predicate future.reload, :open?
  end

  test "an expired parent cannot issue a child" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    now = ClientSignInFlow.database_now
    flow.update!(issued_at: now - 2.seconds, expires_at: now - 1.second)

    assert_raises(FlowInvalidTransition) do
      ClientSessionLimitResolutionTransaction.issue!(
        sign_in_flow: flow,
        actor: actor,
        browser_binding_digest: "e" * 64,
      )
    end
    assert_empty ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id)
  end

  test "a second selection cannot replace the first selected session" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    first_token = ClientToken.create!(user: actor)
    second_token = ClientToken.create!(user: actor)
    binding = SecureRandom.urlsafe_base64(32)
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    resolution = issuance.transaction
    digest = ClientSessionLimitResolutionTransaction.digest_challenge(binding)

    resolution.select_session!(
      actor:, challenge: issuance.challenge, session_ref: first_token.public_id, browser_binding_digest: digest,
    )
    resolution.select_session!(
      actor:, challenge: issuance.challenge, session_ref: first_token.public_id, browser_binding_digest: digest,
    )
    assert_raises(FlowInvalidTransition) do
      resolution.select_session!(
        actor:, challenge: issuance.challenge, session_ref: second_token.public_id, browser_binding_digest: digest,
      )
    end
    assert_equal first_token.public_id, resolution.reload.selected_session_ref
  end

  test "concurrent issue creates one open child and returns an opaque challenge for each caller" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    ActiveRecord::Base.connection_handler.clear_active_connections!
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new

    threads =
      2.times.map do
        Thread.new do
          AppTicketRecord.connection_pool.with_connection do
            barrier.wait
            binding = SecureRandom.urlsafe_base64(32)
            results << ClientSessionLimitResolutionTransaction.issue!(
              actor: Client.find(actor.id),
              sign_in_flow: ClientSignInFlow.find(flow.id),
              browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
            )
          end
        rescue StandardError => e
          results << e
        end
      end
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }

    assert outcomes.all? { |outcome| outcome.is_a?(SessionLimitResolutionTransactionable::Issuance) }, outcomes.inspect
    assert_equal 1, ClientSessionLimitResolutionTransaction.open.where(sign_in_flow_id: flow.id).count
    assert_equal 1, ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).count
    assert outcomes.map(&:challenge).all? { |challenge| challenge.present? }
  end

  test "concurrent conflicting selections have one winner and never revoke the losing choice" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow = client_flow(actor)
    first_token = ClientToken.create!(user: actor)
    second_token = ClientToken.create!(user: actor)
    binding = SecureRandom.urlsafe_base64(32)
    issuance = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: flow,
      actor: actor,
      browser_binding_digest: ClientSessionLimitResolutionTransaction.digest_challenge(binding),
    )
    digest = ClientSessionLimitResolutionTransaction.digest_challenge(binding)
    ActiveRecord::Base.connection_handler.clear_active_connections!
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new

    threads =
      [first_token, second_token].map do |token|
        Thread.new do
          AppTicketRecord.connection_pool.with_connection do
            barrier.wait
            results << resolution_for_thread(issuance.transaction.id).select_session!(
              actor: Client.find(actor.id), challenge: issuance.challenge, session_ref: token.public_id,
              browser_binding_digest: digest,
            )
          end
        rescue StandardError => e
          results << e
        end
      end
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }

    assert_equal 1, outcomes.count { |outcome| outcome == true }, outcomes.inspect
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(FlowInvalidTransition) }, outcomes.inspect
    assert_includes [first_token.public_id, second_token.public_id], issuance.transaction.reload.selected_session_ref
    assert_predicate first_token.reload, :currently_usable?
    assert_predicate second_token.reload, :currently_usable?
  end

  private

  def client_flow(actor)
    now = ClientSignInFlow.database_now
    ClientSignInFlow.create!(
      principal_id: actor.id,
      state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
  end

  def visitor_flow(actor)
    now = VisitorSignInFlow.database_now
    VisitorSignInFlow.create!(
      principal_id: actor.id,
      state_id: VisitorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: VisitorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
  end

  def operator_flow(actor)
    now = OperatorSignInFlow.database_now
    OperatorSignInFlow.create!(
      principal_id: actor.id,
      state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
      nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
  end

  def resolution_for_thread(id)
    ClientSessionLimitResolutionTransaction.find(id)
  end
end
