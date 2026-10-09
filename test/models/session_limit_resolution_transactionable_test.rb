# typed: false
# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"

class SessionLimitResolutionTransactionableTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "client resolution binds the parent and revokes only an owned selected session" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    foreign_actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow =
      begin
        fv5030 = actor
        fv5029 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5030.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5029,
          expires_at: fv5029 + 5.minutes,
        )
      end
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
    visitor_flow_record =
      begin
        fv5028 = visitor
        fv5027 = VisitorSignInFlow.database_now
        VisitorSignInFlow.create!(
          principal_id: fv5028.id,
          state_id: VisitorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: VisitorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5027,
          expires_at: fv5027 + 5.minutes,
        )
      end
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
    operator_flow_record =
      begin
        fv5026 = operator
        fv5025 = OperatorSignInFlow.database_now
        OperatorSignInFlow.create!(
          principal_id: fv5026.id,
          state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5025,
          expires_at: fv5025 + 5.minutes,
        )
      end
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
    flow =
      begin
        fv5024 = actor
        fv5023 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5024.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5023,
          expires_at: fv5023 + 5.minutes,
        )
      end
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
    flow =
      begin
        fv5022 = actor
        fv5021 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5022.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5021,
          expires_at: fv5021 + 5.minutes,
        )
      end

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
    flow =
      begin
        fv5020 = actor
        fv5019 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5020.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5019,
          expires_at: fv5019 + 5.minutes,
        )
      end
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

    exact_flow =
      begin
        fv5018 = actor
        fv5017 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5018.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5017,
          expires_at: fv5017 + 5.minutes,
        )
      end
    exact = ClientSessionLimitResolutionTransaction.issue!(
      sign_in_flow: exact_flow,
      actor: actor,
      browser_binding_digest: "c" * 64,
    ).transaction
    exact.update!(expires_at: ClientSessionLimitResolutionTransaction.database_now)

    assert_not_predicate exact.reload, :open?

    future_flow =
      begin
        fv5016 = actor
        fv5015 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5016.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5015,
          expires_at: fv5015 + 5.minutes,
        )
      end
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
    flow =
      begin
        fv5014 = actor
        fv5013 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5014.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5013,
          expires_at: fv5013 + 5.minutes,
        )
      end
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
    flow =
      begin
        fv5012 = actor
        fv5011 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5012.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5011,
          expires_at: fv5011 + 5.minutes,
        )
      end
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
    flow =
      begin
        fv5010 = actor
        fv5009 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5010.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5009,
          expires_at: fv5009 + 5.minutes,
        )
      end
    ActiveRecord::Base.connection_handler.clear_active_connections!
    barrier = Concurrent::CyclicBarrier.new(2)
    results = Queue.new

    threads =
      2.times.map do
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
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
        ensure
          # Model-clock leases must return before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    threads.each(&:wait)

    outcomes = 2.times.map { results.pop }

    assert_empty outcomes.reject { |outcome| outcome.is_a?(SessionLimitResolutionTransactionable::Issuance) }
    assert_equal 1, ClientSessionLimitResolutionTransaction.open.where(sign_in_flow_id: flow.id).count
    assert_equal 1, ClientSessionLimitResolutionTransaction.where(sign_in_flow_id: flow.id).count
    assert outcomes.map(&:challenge).all? { |challenge| challenge.present? }
  end

  test "concurrent conflicting selections have one winner and never revoke the losing choice" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    flow =
      begin
        fv5008 = actor
        fv5007 = ClientSignInFlow.database_now
        ClientSignInFlow.create!(
          principal_id: fv5008.id,
          state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
          nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: fv5007,
          expires_at: fv5007 + 5.minutes,
        )
      end
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
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          AppTicketRecord.connection_pool.with_connection do
            barrier.wait
            results << begin
              fv5006 = issuance.transaction.id
              ClientSessionLimitResolutionTransaction.find(fv5006)
            end.select_session!(
              actor: Client.find(actor.id), challenge: issuance.challenge, session_ref: token.public_id,
              browser_binding_digest: digest,
            )
          end
        rescue StandardError => e
          results << e
        ensure
          # Model-clock leases must return before the dedicated worker exits.
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end
      end
    threads.each(&:wait)

    outcomes = 2.times.map { results.pop }

    assert_equal 1, outcomes.count { |outcome| outcome == true }, outcomes.inspect
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(FlowInvalidTransition) }, outcomes.inspect
    assert_includes [first_token.public_id, second_token.public_id], issuance.transaction.reload.selected_session_ref
    assert_predicate first_token.reload, :currently_usable?
    assert_predicate second_token.reload, :currently_usable?
  end

  # D-30: capacity is decided at session commit under the actor lock. Two logins racing for the
  # last slot must leave the actor exactly at the limit: one commits, the other is sent to the
  # ordinary resolution and issues nothing.
  [
    ["app", Base::App::AuthorityController, "PUBLIC_BASE_SERVICE_URL", ClientToken, :user_id,
     ClientToken::MAX_SESSIONS_PER_USER, ClientSessionLimitResolutionTransaction,],
    ["com", Base::Com::AuthorityController, "PUBLIC_BASE_CORPORATE_URL", VisitorToken, :visitor_id,
     VisitorToken::MAX_SESSIONS_PER_VISITOR, VisitorSessionLimitResolutionTransaction,],
    ["org", Base::Org::AuthorityController, "PUBLIC_BASE_STAFF_URL", OperatorToken, :staff_id,
     OperatorToken::MAX_SESSIONS_PER_STAFF, OperatorSessionLimitResolutionTransaction,],
  ].each do |surface, controller_class, host_env, token_class, owner_key, limit, resolution_class|
    test "#{surface} concurrent root logins for the last slot commit one session and resolve the other" do
      previous_cooldown = login_cooldown
      self.login_cooldown = 0.seconds
      actor, flows =
        case surface
        when "app"
          client = Client.create!(status_id: ClientStatus::ACTIVE)
          [client, Array.new(2) {
            begin
              fv5005 = client
              fv5004 = ClientSignInFlow.database_now
              ClientSignInFlow.create!(
                principal_id: fv5005.id,
                state_id: ClientSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
                nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: fv5004,
                expires_at: fv5004 + 5.minutes,
              )
            end
          },]
        when "com"
          visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
          [visitor, Array.new(2) {
            begin
              fv5003 = visitor
              fv5002 = VisitorSignInFlow.database_now
              VisitorSignInFlow.create!(
                principal_id: fv5003.id,
                state_id: VisitorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
                nonce_digest: VisitorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: fv5002,
                expires_at: fv5002 + 5.minutes,
              )
            end
          },]
        when "org"
          operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
          [operator, Array.new(2) {
            begin
              fv5001 = operator
              fv5000 = OperatorSignInFlow.database_now
              OperatorSignInFlow.create!(
                principal_id: fv5001.id,
                state_id: OperatorSignInFlow.state_id_for("SESSION_ISSUANCE_PENDING"),
                nonce_digest: OperatorSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: fv5000,
                expires_at: fv5000 + 5.minutes,
              )
            end
          },]
        end
      # This file is not transactional and fixture loading recycles primary keys, so rows left by
      # an earlier interrupted run can carry this actor's or a future token's id. Remove only
      # those leftovers: sessions under the recycled actor id, and flows bound to a token that no
      # longer exists.
      token_class.where(owner_key => actor.id).delete_all
      stale_flows = flows.first.class.where.not(token_id: nil).where.not(token_id: token_class.select(:id))
      resolution_class.where(sign_in_flow_id: stale_flows.select(:id)).delete_all
      stale_flows.delete_all
      (limit - 1).times { token_class.create!(owner_key => actor.id) }
      controllers =
        Array.new(2) do
          request = ActionDispatch::TestRequest.create
          request.host = ENV.fetch(host_env)
          request.session = ActionController::TestSession.new
          controller = controller_class.new
          controller.set_request!(request)
          controller.set_response!(controller_class.make_response!(request))
          controller
        end
      ActiveRecord::Base.connection_handler.clear_active_connections!
      barrier = Concurrent::CyclicBarrier.new(2)
      results = Queue.new

      threads =
        controllers.zip(flows).map do |controller, flow|
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            barrier.wait
            results << controller.log_in(
              actor.class.find(actor.id), establishment: :root_login, sign_in_flow: flow.class.find(flow.id),
            ).fetch(:status)
          rescue StandardError => e
            results << e
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      threads.each(&:wait)
      outcomes = 2.times.map { results.pop }

      assert_equal %i(session_limit_pending success), outcomes.map(&:to_s).sort.map(&:to_sym), outcomes.inspect
      assert_equal limit, token_class.where(owner_key => actor.id).count { |token| token.currently_usable? }
      assert_equal 1, resolution_class.open.where(sign_in_flow_id: flows.map(&:id)).count
    ensure
      self.login_cooldown = previous_cooldown
      if actor
        resolution_class.where(sign_in_flow_id: flows.map(&:id)).delete_all
        flows.first.class.where(id: flows.map(&:id)).delete_all
        token_class.where(owner_key => actor.id).delete_all
      end
    end
  end

  private
end
