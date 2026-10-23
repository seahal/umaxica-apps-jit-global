# typed: false
# frozen_string_literal: true

require "test_helper"

class CredentialSecurityTransitionTest < ActiveSupport::TestCase
  test "credential changes end only owned unfinished sign-in flows without revoking retained root sessions" do
    %i(app com org).each do |surface|
      [true, false].each_with_index do |revoke_step_up, index|
        actor, foreign, token, =
          case surface
          when :app
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_119_000_000_000 + index)
            [
              actor,
              Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_120_000_000_000 + index),
              ClientToken.create!(authentication_epoch: 0, user: actor),
              ClientSignInFlow,
              ClientAuthCeremonySession,
            ]
          when :com
            actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_119_000_000_000 + index)
            [
              actor,
              Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_120_000_000_000 + index),
              VisitorToken.create!(authentication_epoch: 0, visitor: actor),
              VisitorSignInFlow,
              VisitorAuthCeremonySession,
            ]
          when :org
            actor = Operator.create!(
              security_mode_id: SecurityModeConfigurable::ADVANCED,
              id: 9_119_000_000_000 + index,
            )
            [
              actor,
              Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_120_000_000_000 + index),
              OperatorToken.create!(authentication_epoch: 0, staff: actor),
              OperatorSignInFlow,
              OperatorAuthCeremonySession,
            ]
          end
        # Synthetic proof isolates revocation; real authentication is exercised by integration tests.
        flow = SignInFlowTestFactory.create!(surface: surface.to_s, principal_id: nil)
        flow.update!(principal_id: actor.id)
        flow.record_authentication_evidence!(method: "passkey")
        flow.advance_sign_in_to_guardrail!
        flow.advance_sign_in_to_checkpoint!
        flow.advance_sign_in_to_selector!
        flow.advance_sign_in_to_session_issuance!
        event = flow.authentication_event_at
        foreign_flow = SignInFlowTestFactory.create!(surface: surface.to_s, principal_id: nil)
        foreign_flow.update!(principal_id: foreign.id)
        completed = SignInFlowTestFactory.create!(surface: surface.to_s, principal_id: nil)
        completed.update!(principal_id: actor.id, token_id: token.id)
        completed.record_authentication_evidence!(method: "passkey", authenticated_at: event)
        completed.advance_sign_in_to_guardrail!
        completed.advance_sign_in_to_checkpoint!
        completed.advance_sign_in_to_selector!
        completed.advance_sign_in_to_session_issuance!
        completed.complete_sign_in!

        result = CredentialSecurityTransition.call(
          actor: actor, current_session: token, reason: :mfa_reset, affected_surface: surface,
          revoke_current: false, revoke_other_sessions: false, revoke_step_up: revoke_step_up,
        )

        assert_predicate flow.reload, :sign_in_halted?
        assert_equal event, flow.authentication_event_at
        assert_predicate token.reload, :currently_usable?
        assert_equal 0, result.revoked_session_count
        assert_predicate foreign_flow.reload, :sign_in_primary_pending?
        assert_predicate completed.reload, :sign_in_completed?
      end
    end
  end

  test "credential changes end a sign-in flow immediately before at and after its expiry" do
    %i(app com org).each do |surface|
      [-1, 0, 1].each_with_index do |microseconds, index|
        actor, token, flow_model, =
          case surface
          when :app
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_122_000_000_000 + index)
            [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientSignInFlow,
             ClientAuthCeremonySession,]
          when :com
            actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_122_000_000_000 + index)
            [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), VisitorSignInFlow,
             VisitorAuthCeremonySession,]
          when :org
            actor = Operator.create!(
              security_mode_id: SecurityModeConfigurable::ADVANCED,
              id: 9_122_000_000_000 + index,
            )
            [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorSignInFlow,
             OperatorAuthCeremonySession,]
          end
        flow = SignInFlowTestFactory.create!(surface: surface.to_s, principal_id: nil)
        now = flow_model.database_now
        flow.update!(
          principal_id: actor.id, issued_at: now - 1.minute,
          expires_at: now + Rational(microseconds, 1_000_000),
        )
        expiry = flow.expires_at

        flow_model.stub(:database_now, now) do
          CredentialSecurityTransition.call(
            actor: actor, current_session: token, reason: :mfa_reset, affected_surface: surface,
            revoke_current: false, revoke_other_sessions: false,
          )
        end

        assert_equal expiry, flow.reload.expires_at
        assert_equal microseconds.positive?, flow.sign_in_halted?
        assert_predicate token.reload, :currently_usable?
        assert_nil flow.authentication_event_at
      end
    end
  end

  test "credential changes expire only owned unfinished OIDC authentication and preserve consumed history" do
    %i(app com org).each do |surface|
      actor, foreign, token, transactions, ceremonies =
        case surface
        when :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_123_000_000_000)
          [actor, Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_124_000_000_000,
          ), ClientToken.create!(authentication_epoch: 0, user: actor),
           ClientOidcAuthorizationTransaction, ClientAuthCeremonySession,]
        when :com
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_123_000_000_000)
          [actor, Visitor.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_124_000_000_000,
          ), VisitorToken.create!(authentication_epoch: 0, visitor: actor),
           VisitorOidcAuthorizationTransaction, VisitorAuthCeremonySession,]
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_123_000_000_000)
          [actor, Operator.create!(
            security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_124_000_000_000,
          ), OperatorToken.create!(authentication_epoch: 0, staff: actor),
           OperatorOidcAuthorizationTransaction, OperatorAuthCeremonySession,]
        end
      rows =
        [actor, foreign, actor].each_with_index.map do |owner, index|
          now = transactions.database_now
          transaction = transactions.create_transaction!(
            surface: surface, intent: "authentication", client_id: "revocation-test",
            redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
            state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
            code_challenge_method: "S256", login_challenge: SecureRandom.hex(32),
            login_challenge_expires_at: now + 5.minutes, expires_at: now + 5.minutes,
          )
          transaction = transaction.register_authentication!(
            actor_ref: owner.public_id, session_ref: nil, auth_method: "passkey", acr: "aal1",
            authentication_event_at: now,
          )
          transaction, generation = transaction.prepare_result_delivery!(result_digest: SecureRandom.hex(32))
          ceremony, = ceremonies.rotate_and_admit!(
            admission_purpose: "authentication_handoff", authorization_transaction_ref: transaction.transaction_id,
          )
          if index == 2
            transaction.finalize_base!(result_generation: generation) do
              { status: :success, browser_session_ref: token.public_id }
            end
            ceremony.complete!
          end
          [transaction, ceremony, transaction.expires_at, transaction.authenticated_at,
           transaction.result_generation,]
        end
      resolutions =
        if surface == :app
          [actor, foreign].each_with_index.map do |owner, index|
            flow = SignInFlowTestFactory.create!(surface: "app", principal_id: nil)
            flow.update!(principal_id: owner.id)
            flow.record_authentication_evidence!(method: "passkey")
            flow.advance_sign_in_to_guardrail!
            flow.advance_sign_in_to_checkpoint!
            flow.advance_sign_in_to_selector!
            flow.advance_sign_in_to_session_issuance!
            ClientSessionLimitResolutionTransaction.issue!(
              sign_in_flow: flow, actor: owner, browser_binding_digest: SecureRandom.hex(32),
              oidc_authorization_transaction: rows.fetch(index).first,
            ).transaction
          end
        else
          []
        end
      CredentialSecurityTransition.call(
        actor: actor, current_session: token, reason: :mfa_reset, affected_surface: surface,
        revoke_current: false, revoke_other_sessions: false,
      )
      owned, continuity, _, event, generation = rows.first

      assert owned.reload.expired?(now: transactions.database_now)
      assert_not_nil continuity.reload.revoked_at
      assert_equal event, owned.authenticated_at
      assert_equal generation, owned.result_generation
      assert_not owned.result_delivery_matches?(
        result_digest: owned.result_digest, result_generation: generation,
      )
      assert_raises(ArgumentError) do
        owned.finalize_base!(result_generation: generation) { flunk "expired evidence reached root issuance" }
      end
      rows.drop(1).each do |row, ceremony, expiry, historical_event, historical_generation|
        assert_equal expiry, row.reload.expires_at
        assert_nil ceremony.reload.revoked_at
        assert_equal historical_event, row.authenticated_at
        assert_equal historical_generation, row.result_generation
      end
      if surface == :app
        assert_predicate resolutions.first.reload, :expired?
        assert_predicate resolutions.last.reload, :pending?
      end

      assert_predicate token.reload, :currently_usable?
    end
  end

  test "OIDC continuity failure rolls back authorization expiry and preserves the retained root token" do
    %i(app com org).each do |surface|
      actor, token, transactions, ceremonies =
        case surface
        when :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_126_000_000_000)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientOidcAuthorizationTransaction,
           ClientAuthCeremonySession,]
        when :com
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_126_000_000_000)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), VisitorOidcAuthorizationTransaction,
           VisitorAuthCeremonySession,]
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_126_000_000_000)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorOidcAuthorizationTransaction,
           OperatorAuthCeremonySession,]
        end
      now = transactions.database_now
      parent = transactions.create_transaction!(
        surface: surface, intent: "authentication", client_id: "revocation-test",
        redirect_uri: "https://rp.example.test/callback", response_type: "code", scope: "openid",
        state: SecureRandom.hex(16), nonce: SecureRandom.hex(16), code_challenge: "a" * 43,
        code_challenge_method: "S256", login_challenge: SecureRandom.hex(32),
        login_challenge_expires_at: now + 5.minutes, expires_at: now + 5.minutes,
      )
      parent = parent.register_authentication!(
        actor_ref: actor.public_id, session_ref: nil, auth_method: "passkey", acr: "aal1",
        authentication_event_at: now,
      )
      parent, = parent.prepare_result_delivery!(result_digest: SecureRandom.hex(32))
      continuity, = ceremonies.rotate_and_admit!(
        admission_purpose: "authentication_handoff", authorization_transaction_ref: parent.transaction_id,
      )
      expiry = parent.expires_at
      result_expiry = parent.result_expires_at
      challenge_expiry = parent.login_challenge_expires_at
      failure = -> { raise ActiveRecord::ConnectionNotEstablished, "injected OIDC continuity clock failure" }

      ceremonies.stub(:database_now, failure) do
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          CredentialSecurityTransition.call(
            actor: actor, current_session: token, reason: :mfa_reset, affected_surface: surface,
            revoke_current: true,
          )
        end
      end

      assert_equal expiry, parent.reload.expires_at
      assert_equal result_expiry, parent.result_expires_at
      assert_equal challenge_expiry, parent.login_challenge_expires_at
      assert_predicate parent, :authenticated?
      assert_nil continuity.reload.revoked_at
      assert_predicate token.reload, :currently_usable?
    end
  end

  %i(app com org).each do |surface|
    %i(other_actor other_surface).each do |mismatch|
      test "#{surface} credential transition refuses current-session #{mismatch} before changing tokens" do
        case surface
        when :app
          actor = clients(:one)
          owned_token = ClientToken.create!(authentication_epoch: 0, user: actor)
          foreign_token =
            if mismatch == :other_actor
              ClientToken.create!(authentication_epoch: 0, user: clients(:two))
            else
              OperatorToken.create!(authentication_epoch: 0, staff: operators(:one))
            end
        when :com
          actor = visitors(:reserved_visitor)
          owned_token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
          foreign_token =
            if mismatch == :other_actor
              VisitorToken.create!(
                authentication_epoch: 0,
                visitor: Visitor.create!(
                  security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE,
                ),
              )
            else
              ClientToken.create!(authentication_epoch: 0, user: clients(:one))
            end
        when :org
          actor = operators(:one)
          owned_token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
          foreign_token =
            if mismatch == :other_actor
              OperatorToken.create!(authentication_epoch: 0, staff: operators(:two))
            else
              ClientToken.create!(authentication_epoch: 0, user: clients(:one))
            end
        end

        assert_raises(ArgumentError) do
          CredentialSecurityTransition.call(
            actor: actor, current_session: foreign_token, reason: :mfa_reset, affected_surface: surface,
          )
        end
        assert_predicate owned_token.reload, :currently_usable?
        assert_predicate foreign_token.reload, :currently_usable?
      end
    end

    test "#{surface} absent current-session reference preserves the explicit other-session policy" do
      case surface
      when :app
        actor = clients(:one)
        AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
        token = ClientToken.create!(authentication_epoch: 0, user: actor)
      when :com
        actor = visitors(:reserved_visitor)
        AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
        token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
      when :org
        actor = operators(:one)
        AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
        token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
      end
      retained = CredentialSecurityTransition.call(
        actor: actor, current_session: nil, reason: :mfa_reset, affected_surface: surface,
        revoke_current: true, revoke_other_sessions: false,
      )

      assert_equal 0, retained.revoked_session_count
      assert_predicate token.reload, :currently_usable?

      revoked = CredentialSecurityTransition.call(
        actor: actor, current_session: nil, reason: :mfa_reset, affected_surface: surface,
        revoke_current: false, revoke_other_sessions: true,
      )

      assert_equal 1, revoked.revoked_session_count
      assert_predicate token.reload, :revoked?
    end

    [[false, false], [false, true], [true, false], [true, true]].each do |revoke_current, revoke_others|
      test "#{surface} session revocation honors current #{revoke_current} and other #{revoke_others} independently" do
        case surface
        when :app
          actor = clients(:one)
          AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
          current_token = ClientToken.create!(authentication_epoch: 0, user: actor)
          other_token = ClientToken.create!(authentication_epoch: 0, user: actor)
        when :com
          actor = visitors(:reserved_visitor)
          AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
          current_token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
          other_token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
        when :org
          actor = operators(:one)
          AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
          current_token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
          other_token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
        end
        result = CredentialSecurityTransition.call(
          actor: actor, current_session: current_token, reason: :mfa_reset, affected_surface: surface,
          revoke_current: revoke_current, revoke_other_sessions: revoke_others,
        )

        assert_equal revoke_current, current_token.reload.revoked?
        assert_equal revoke_others, other_token.reload.revoked?
        assert_equal [revoke_current, revoke_others].count(true), result.revoked_session_count
        assert_nil current_token.last_step_up_at
        assert_nil other_token.last_step_up_at
      end
    end
  end

  test "COM credential changes enumerate revocation targets on the writer inside a reading request" do
    actor = visitors(:reserved_visitor)
    AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
    current_token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
    other_token = VisitorToken.create!(authentication_epoch: 0, visitor: actor)
    roles = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        if payload.fetch(:sql).match?(/\ASELECT .*FROM "visitor_tokens"/)
          roles << payload.fetch(:connection).pool.role
        end
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      OpBaseComRecord.connected_to(role: :reading, prevent_writes: true) do
        CredentialSecurityTransition.call(
          actor: actor, current_session: current_token, reason: :email_address_verified, affected_surface: "com",
        )
      end
    end

    assert_not_empty roles
    assert_equal [:writing], roles.uniq
    assert_predicate current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
  end

  test "ORG credential changes enumerate revocation targets on the writer inside a reading request" do
    actor = operators(:one)
    AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
    current_token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    other_token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
    roles = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        if payload.fetch(:sql).match?(/\ASELECT .*FROM "operator_tokens"/)
          roles << payload.fetch(:connection).pool.role
        end
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      OpBaseOrgRecord.connected_to(role: :reading, prevent_writes: true) do
        CredentialSecurityTransition.call(
          actor: actor, current_session: current_token, reason: :recovery_codes_rotated, affected_surface: "org",
        )
      end
    end

    assert_not_empty roles
    assert_equal [:writing], roles.uniq
    assert_predicate current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
  end

  test "credential changes enumerate revocation targets on the writer inside a reading request" do
    actor = clients(:one)
    current_token = ClientToken.create!(authentication_epoch: 0, user: actor)
    other_token = ClientToken.create!(authentication_epoch: 0, user: actor)
    roles = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        if payload.fetch(:sql).match?(/\ASELECT .*FROM "client_tokens"/)
          roles << payload.fetch(:connection).pool.role
        end
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      OpBaseAppRecord.connected_to(role: :reading, prevent_writes: true) do
        CredentialSecurityTransition.call(
          actor: actor, current_session: current_token, reason: :mfa_disabled, affected_surface: "app",
        )
      end
    end

    assert_not_empty roles
    assert_equal [:writing], roles.uniq
    assert_predicate current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
  end

  test "credential changes revoke pending ceremonies even before freshness exists" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: true,
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
      ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true,
    )
    transaction = BaseStepUpAdmissionIssuer.call!(
      actor: actor,
      token: token,
      requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: token,
    ).transaction
    ceremony, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: transaction.transaction_id,
    )

    CredentialSecurityTransition.call(
      actor: actor, current_session: token, reason: :mfa_disabled, affected_surface: "app",
      revoke_other_sessions: false,
    )

    assert_equal "revoked", transaction.reload.status
    assert_not_nil transaction.revoked_at
    assert_predicate ceremony.reload, :terminal?
    assert_not_nil ceremony.revoked_at
    assert_predicate token.reload, :currently_usable?
    assert_nil token.last_step_up_at
  end

  test "revokes other client sessions and all step-up grants while retaining current session" do
    actor = clients(:one)
    AuthenticationSessionRevoker.tokens_for(actor).find_each(&:revoke!)
    current_token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      last_step_up_at: 1.minute.ago,
      last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2",
      last_step_up_method: "totp",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "app",
      last_step_up_session_public_id: "current_session",
    )
    other_token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      last_step_up_at: 1.minute.ago,
      last_step_up_scope: "settings_mfa",
      last_step_up_aal: "aal2",
      last_step_up_method: "totp",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "app",
      last_step_up_session_public_id: "other_session",
    )
    ClientStepUpSession.create!(
      user_token: other_token,
      scope: "settings_mfa",
      return_to: "/identity/mfa/challenge",
      status: "VERIFIED",
      method: "totp",
      verified_at: 1.minute.ago,
      discard_at: 10.minutes.from_now,
    )
    ClientStepUpSession.create!(
      user_token: current_token,
      scope: "settings_mfa",
      return_to: "/identity/mfa/challenge",
      status: "VERIFIED",
      method: "totp",
      verified_at: 1.minute.ago,
      discard_at: 10.minutes.from_now,
    )
    step_up_selects = []
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql].to_s
        step_up_selects << sql if sql.match?(/\ASELECT .*FROM "client_step_up_sessions"/)
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      assert_difference -> {
        ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).count
      }, 1 do
        result = CredentialSecurityTransition.call(
          actor: actor,
          current_session: current_token,
          reason: :mfa_disabled,
          affected_surface: "app",
        )

        assert_equal 1, result.revoked_session_count
        assert_equal 2, result.revoked_step_up_count
      end
    end
    assert_equal 3, step_up_selects.length
    assert step_up_selects.all? { |sql| sql.include?("FOR UPDATE") }

    assert_predicate current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :revoked?
    assert_nil current_token.last_step_up_at
    assert_nil other_token.last_step_up_at
    assert_operator current_token.step_up_session.reload.discard_at, :<=, Time.current
    assert_operator other_token.step_up_session.reload.discard_at, :<=, Time.current

    audit =
      ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).order(:created_at).last

    assert_equal "credential_security_transition.mfa_disabled", audit.context.fetch("action")
    assert_equal "mfa_disabled", audit.context.fetch("reason")
    assert_equal "app", audit.context.fetch("surface")
    assert_equal 1, audit.context.fetch("revoked_session_count")
    assert_equal 2, audit.context.fetch("revoked_step_up_count")
    assert_not_includes audit.context.to_s, current_token.public_id
    assert_not_includes audit.context.to_s, other_token.public_id
  end

  test "rejects unknown transition reason fail closed" do
    error =
      assert_raises(ArgumentError) do
        CredentialSecurityTransition.call(
          actor: clients(:one),
          current_session: nil,
          reason: :unknown,
          affected_surface: "app",
        )
      end

    assert_match(/unsupported credential transition reason/, error.message)
  end
end
