# frozen_string_literal: true

require "test_helper"
require "timeout"

# A committed row and separate writer connections expose the one-shot revocation boundary.
# rubocop:disable ThreadSafety/NewThread
class AuthCeremonyRevocationConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  fixtures :client_statuses, :client_visibilities, :client_mfa_levels, :client_mfa_statuses
  fixtures :visitor_statuses, :visitor_visibilities, :visitor_mfa_levels, :visitor_mfa_statuses
  fixtures :operator_statuses, :operator_visibilities, :operator_mfa_levels, :operator_mfa_statuses

  test "credential changes racing local authentication evidence leave no usable unfinished admission" do
    %i(app com org).each do |surface|
      actor = token = flow = ceremony = threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actors, tokens, flows, ceremonies, tickets, token_key =
          case surface
          when :app then [Client, ClientToken, ClientSignInFlow, ClientAuthCeremonySession, AppTicketRecord, :user_id]
          when :com then [Visitor, VisitorToken, VisitorSignInFlow, VisitorAuthCeremonySession, ComTicketRecord,
                          :visitor_id,]
          when :org then [Operator, OperatorToken, OperatorSignInFlow, OperatorAuthCeremonySession, OrgTicketRecord,
                          :staff_id,]
          end
        actor = actors.create!
        token = tokens.create!(token_key => actor.id)
        flow = BaseAuthAdmissionCoordinator.issue_local_entry!(
          surface: surface.to_s, intent: "sign_in", base_browser_nonce: "test-browser-nonce", base_token: nil,
        ).transaction
        flow.update!(principal_id: actor.id)
        ceremony, = ceremonies.rotate_and_admit!(
          admission_purpose: "local_sign_in", local_sign_in_flow_ref: flow.public_id,
        )
        ActiveRecord::Base.connection_handler.clear_active_connections!
        threads =
          Array.new(2) do |index|
            Thread.new do
              tickets.connected_to(role: :writing) do
                tickets.connection_pool.with_connection do |connection|
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  if index.zero?
                    begin
                      # Synthetic evidence isolates the DB race; crypto is covered by HTTP tests.
                      flows.find(flow.id).record_local_authentication_evidence!(method: "passkey")
                      :recorded
                    rescue AuthCeremonySession::InvalidTransition
                      :refused
                    end
                  else
                    CredentialSecurityTransition.call(
                      actor: actors.find(actor.id), current_session: tokens.find(token.id),
                      reason: :mfa_reset, affected_surface: surface,
                      revoke_current: false, revoke_other_sessions: false,
                    )
                    :revoked
                  end
                end
              end
            end
          end
        pids = nil
        results =
          Timeout.timeout(10) do
            pids = [ready.pop, ready.pop]
            2.times { release << true }
            threads.map(&:value)
          end

        assert_equal 2, pids.uniq.length, surface.to_s
        assert_includes [:recorded, :refused], results.first
        assert_equal :revoked, results.last
        assert_predicate flow.reload, :sign_in_failed?
        assert_not_nil ceremony.reload.revoked_at
        assert_nil flow.result_digest
        assert_nil flow.base_finalized_at
        assert_predicate token.reload, :currently_usable?
        assert_raises(AuthCeremonySession::InvalidTransition) do
          flow.record_local_authentication_evidence!(method: "passkey")
        end
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        ceremonies.where(id: ceremony.id).delete_all if ceremony
        flows.where(id: flow.id).delete_all if flow
        tokens.where(id: token.id).delete_all if token
        case actor
        when Client
          ClientChronicle.where(actor_type: "Client", actor_id: actor.id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
        when Visitor
          ClientChronicle.where(actor_type: "Visitor", actor_id: actor.id).delete_all
          VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
        when Operator
          OperatorChronicle.where(actor_type: "Operator", actor_id: actor.id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all if actor
      end
    end
  end

  test "independent removal writers preserve the last compatible method on each surface" do
    %i(app com org totp).each do |surface|
      actor = nil
      token = nil
      contact = nil
      threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actor, model, owner_key, token_model, token_key =
          case surface
          when :app then [Client.create!, ClientPasskey, :user_id, ClientToken, :user_id]
          when :totp then [Client.create!, ClientTotpCredential, :user_id, ClientToken, :user_id]
          when :com then [Visitor.create!, VisitorPasskey, :visitor_id, VisitorToken, :visitor_id]
          when :org then [Operator.create!, OperatorPasskey, :staff_id, OperatorToken, :staff_id]
          end
        if surface == :com
          contact = actor.visitor_emails.create!(
            address: "removal-race-#{SecureRandom.hex(8)}@example.com",
            visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          )
        end
        if surface == :totp
          actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "unknown-uv-key")
          credentials =
            Array.new(2) do
              model.create!(owner_key => actor.id, :user_identity_totp_credential_status_id => ClientTotpCredentialStatus::ACTIVE)
            end
        else
          credentials =
            Array.new(2) do
              model.create!(
                owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
                :public_key => "removal-race-key", :uv_verified_at => Time.current,
              )
            end
        end
        # COM provisioning requires contact, but unverified contact is not a compatible fallback.
        contact&.update!(visitor_email_status_id: VisitorEmailStatus::UNVERIFIED)
        token = token_model.create!(token_key => actor.id)
        ActiveRecord::Base.connection_handler.clear_active_connections!
        threads =
          credentials.map do |credential|
            Thread.new do
              model.connection_class_for_self.connected_to(role: :writing) do
                model.connection_pool.with_connection do |connection|
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  IdentityCredentialRemovalCommitter.call!(
                    actor: actor.class.find(actor.id), credential: model.find(credential.id),
                    current_session: token_model.find(token.id),
                  )
                end
              end
            end
          end
        pids = nil
        results =
          Timeout.timeout(10) do
            pids = [ready.pop, ready.pop]
            2.times { release << true }
            threads.map(&:value)
          end

        assert_equal 2, pids.uniq.length, surface.to_s
        assert_equal 1, results.count(true), surface.to_s
        assert_equal 1, results.count(false), surface.to_s
        remaining =
          if surface == :totp
            model.where(owner_key => actor.id, :user_identity_totp_credential_status_id => ClientTotpCredentialStatus::ACTIVE)
          else
            model.active.where(owner_key => actor.id)
          end

        assert_equal 1, remaining.count, surface.to_s
        assert_equal 2, model.where(owner_key => actor.id).count, surface.to_s
        assert_predicate token.reload, :currently_usable?, surface.to_s
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        token_model.where(id: token.id).delete_all if token
        model.where(owner_key => actor.id).delete_all if actor && model
        VisitorEmail.where(id: contact.id).delete_all if contact
        case actor
        when Client
          ClientPasskey.where(user_id: actor.id).delete_all
          ClientChronicle.where(actor_type: "Client", actor_id: actor.id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
          Client.where(id: actor.id).delete_all
        when Visitor
          ClientChronicle.where(actor_type: "Visitor", actor_id: actor.id).delete_all
          VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
          Visitor.where(id: actor.id).delete_all
        when Operator
          OperatorChronicle.where(actor_type: "Operator", actor_id: actor.id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
          Operator.where(id: actor.id).delete_all
        end
      end
    end
  end

  test "independent writers can create only one remaining Passkey slot on each surface" do
    %i(app com org).each do |surface|
      actor = nil
      contact = nil
      threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actor, model, owner_key, writer =
          case surface
          when :app then [Client.create!, ClientPasskey, :user_id, AppPrincipalRecord]
          when :com then [Visitor.create!, VisitorPasskey, :visitor_id, ComPrincipalRecord]
          when :org then [Operator.create!, OperatorPasskey, :staff_id, OrgPrincipalRecord]
          end
        if surface == :com
          contact = actor.visitor_emails.create!(
            address: "passkey-slots-#{SecureRandom.hex(6)}@example.com",
            visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          )
        end
        3.times {
          model.create!(owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "slot-public-key")
        }
        ActiveRecord::Base.connection_handler.clear_active_connections!
        threads =
          Array.new(2) do
            Thread.new do
              writer.connection_class_for_self.connected_to(role: :writing) do
                writer.connection_pool.with_connection do |connection|
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  begin
                    model.create!(
                      owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
                      :public_key => "competing-key",
                    )
                    :created
                  rescue ActiveRecord::RecordInvalid
                    :full
                  end
                end
              end
            end
          end
        pids = nil
        results =
          Timeout.timeout(10) do
            pids = [ready.pop, ready.pop]
            2.times { release << true }
            threads.map(&:value)
          end

        assert_equal 2, pids.uniq.length, surface.to_s
        assert_equal [:created, :full], results.sort, surface.to_s
        assert_equal 4, model.active.where(owner_key => actor.id).count, surface.to_s
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        model.where(owner_key => actor.id).delete_all if actor && model
        VisitorEmail.where(id: contact.id).delete_all if contact
        case actor
        when Client
          ClientAuthorityLock.where(client_id: actor.id).delete_all
          Client.where(id: actor.id).delete_all
        when Visitor
          VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
          Visitor.where(id: actor.id).delete_all
        when Operator
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
          Operator.where(id: actor.id).delete_all
        end
      end
    end
  end

  test "APP competing Email OTP verification consumes one code and records one verification event" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
    credential = actor.client_emails.create!(
      address: "otp-race-#{SecureRandom.hex(8)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    token = ClientToken.create!(user: actor)
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: parent.transaction_id,
      scope: parent.required_scope, return_to: parent.return_to,
      status: "PENDING", discard_at: parent.expires_at,
    )
    generation = record.issue_bound_email_code!(
      transaction: parent, credential_ref: credential.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: parent, generation: generation, success: true)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      Array.new(2) do
        Thread.new do
          AppTicketRecord.connected_to(role: :writing) do
            AppTicketRecord.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              IdentityStepUpEmailVerificationCommitter.call!(
                actor: Client.find(actor.id), credential: ClientEmail.find(credential.id),
                transaction: ClientStepUpCeremonyTransaction.find(parent.id),
                session_record: ClientStepUpSession.find(record.id), code: "012345",
              )
            end
          end
        end
      end
    pids = nil
    results =
      Timeout.timeout(10) do
        pids = [ready.pop, ready.pop]
        2.times { release << true }
        threads.map(&:value)
      end

    assert_equal 2, pids.uniq.length
    assert_equal 1, results.count(true)
    assert_equal 1, results.count(false)
    assert_equal "verified", parent.reload.status
    assert_equal "email_otp", parent.method
    assert_equal "none", parent.aal
    assert_not parent.phishing_resistant
    assert_equal credential.public_id, parent.verified_credential_ref
    assert_not_nil record.reload.email_code_consumed_at
    event = parent.verified_at

    assert_equal 0, credential.reload.step_up_otp_failures
    assert_nil token.reload.last_step_up_at
    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: actor, credential: credential, transaction: parent, session_record: record, code: "012345",
    )
    assert_equal event, parent.reload.verified_at
    assert_equal 0, credential.reload.step_up_otp_failures
  ensure
    if threads
      2.times { release << true }
      threads.each { |thread| thread.kill unless thread.join(10) }
    end
    ClientStepUpSession.where(id: record.id).delete_all if record
    ClientStepUpCeremonyTransaction.where(id: parent.id).delete_all if parent
    ClientToken.where(id: token.id).delete_all if token
    ClientEmail.where(id: credential.id).delete_all if credential
    if actor
      ClientAuthorityLock.where(client_id: actor.id).delete_all
      Client.where(id: actor.id).delete_all
    end
  end

  test "COM competing Email OTP verification consumes one code and records one verification event" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    credential = actor.visitor_emails.create!(
      address: "otp-race-#{SecureRandom.hex(8)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: actor)
    parent = VisitorStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_email",
      required_aal: "none", allowed_methods: ["email_otp"], return_to: "/identity/emails",
    )
    record = VisitorStepUpSession.create!(
      visitor_token: token, step_up_ceremony_transaction_ref: parent.transaction_id,
      scope: parent.required_scope, return_to: parent.return_to,
      status: "PENDING", discard_at: parent.expires_at,
    )
    generation = record.issue_bound_email_code!(
      transaction: parent, credential_ref: credential.public_id, code: "012345",
    )
    record.mark_bound_email_delivery!(transaction: parent, generation: generation, success: true)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      Array.new(2) do
        Thread.new do
          ComTicketRecord.connected_to(role: :writing) do
            ComTicketRecord.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              IdentityStepUpEmailVerificationCommitter.call!(
                actor: Visitor.find(actor.id), credential: VisitorEmail.find(credential.id),
                transaction: VisitorStepUpCeremonyTransaction.find(parent.id),
                session_record: VisitorStepUpSession.find(record.id), code: "012345",
              )
            end
          end
        end
      end
    pids = nil
    results =
      Timeout.timeout(10) do
        pids = [ready.pop, ready.pop]
        2.times { release << true }
        threads.map(&:value)
      end

    assert_equal 2, pids.uniq.length
    assert_equal 1, results.count(true)
    assert_equal 1, results.count(false)
    assert_equal "verified", parent.reload.status
    assert_equal "email_otp", parent.method
    assert_equal "none", parent.aal
    assert_not parent.phishing_resistant
    assert_equal credential.public_id, parent.verified_credential_ref
    assert_not_nil record.reload.email_code_consumed_at
    event = parent.verified_at

    assert_equal 0, credential.reload.step_up_otp_failures
    assert_nil token.reload.last_step_up_at
    assert_not IdentityStepUpEmailVerificationCommitter.call!(
      actor: actor, credential: credential, transaction: parent, session_record: record, code: "012345",
    )
    assert_equal event, parent.reload.verified_at
    assert_equal 0, credential.reload.step_up_otp_failures
  ensure
    if threads
      2.times { release << true }
      threads.each { |thread| thread.kill unless thread.join(10) }
    end
    VisitorStepUpSession.where(id: record.id).delete_all if record
    VisitorStepUpCeremonyTransaction.where(id: parent.id).delete_all if parent
    VisitorToken.where(id: token.id).delete_all if token
    VisitorEmail.where(id: credential.id).delete_all if credential
    if actor
      VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
      Visitor.where(id: actor.id).delete_all
    end
  end

  [
    [:app, Client, ClientToken, ClientPasskey, ClientStepUpCeremonyTransaction,
     ClientAuthCeremonySession, ClientStepUpSession, AppTicketRecord,],
    [:com, Visitor, VisitorToken, VisitorPasskey, VisitorStepUpCeremonyTransaction,
     VisitorAuthCeremonySession, VisitorStepUpSession, ComTicketRecord,],
    [:org, Operator, OperatorToken, OperatorPasskey, OperatorStepUpCeremonyTransaction,
     OperatorAuthCeremonySession, OperatorStepUpSession, OrgTicketRecord,],
  ].each do |surface, actors, tokens, passkeys, transactions, continuities, sessions, tickets|
    test "#{surface} logout racing Base finalization leaves no usable authority or reusable result" do
      case surface
      when :app
        actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
        credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = ClientToken.create!(user: actor)
        credential_ref = credential.public_id
      when :com
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::BOTH)
        contact = actor.visitor_emails.create!(
          address: "logout-race-#{SecureRandom.hex(8)}@example.com",
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        )
        credential = actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = VisitorToken.create!(visitor: actor)
        credential_ref = credential.public_id
      when :org
        actor = Operator.create!
        credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = OperatorToken.create!(staff: actor)
        credential_ref = credential.external_id
      end
      requirement = StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      )
      parent = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      # Synthetic evidence isolates finalization and logout, not WebAuthn signature verification.
      parent.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: transactions.database_now, verified_credential_ref: credential_ref,
      )
      continuity, = continuities.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
      )
      issuance = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: parent, ceremony_session_ref: continuity.id.to_s,
      )
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        Array.new(2) do |index|
          Thread.new do
            tickets.connected_to(role: :writing) do
              tickets.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                if index.zero?
                  begin
                    IdentityStepUpCeremonyFreshnessCommitter.call!(
                      actor: actors.find(actor.id), token: tokens.find(token.id),
                      transaction: transactions.find(parent.id), requirement: requirement,
                      raw_result: issuance.code,
                    )
                    :finalized
                  rescue IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied
                    :finalization_refused
                  end
                else
                  tokens.find(token.id).revoke!
                  :revoked
                end
              end
            end
          end
        end
      pids = nil
      results =
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end

      assert_equal 2, pids.uniq.length
      assert_equal :revoked, results.last
      assert_includes [:finalized, :finalization_refused], results.first
      assert_predicate token.reload, :revoked?
      assert_not token.currently_usable?
      assert_nil token.last_step_up_at
      assert_not StepUpResolver.call(token: token, requirement: requirement).satisfied?
      if results.first == :finalized
        assert_equal "consumed", parent.reload.status
        assert_predicate continuity.reload, :completed?
      else
        assert_equal "revoked", parent.reload.status
        assert_predicate continuity.reload, :terminal?
      end
      assert_raises(IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied) do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor: actor, token: token, transaction: parent, requirement: requirement, raw_result: issuance.code,
        )
      end
      assert_nil token.reload.last_step_up_at
    ensure
      if threads
        2.times { release << true }
        threads.each { |thread| thread.kill unless thread.join(10) }
      end
      if parent
        continuities.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        sessions.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        transactions.where(id: parent.id).delete_all
      end
      tokens.where(id: token.id).delete_all if token
      passkeys.where(id: credential.id).delete_all if credential
      VisitorEmail.where(id: contact.id).delete_all if contact
      if actor
        case surface
        when :app then ClientAuthorityLock.where(client_id: actor.id).delete_all
        when :com then VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
        when :org then OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all
      end
    end

    test "#{surface} credential revocation racing Base finalization clears authority and rejects result reuse" do
      case surface
      when :app
        actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
        credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = ClientToken.create!(user: actor)
        credential_ref = credential.public_id
      when :com
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::BOTH)
        contact = actor.visitor_emails.create!(
          address: "credential-revocation-race-#{SecureRandom.hex(8)}@example.com",
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        )
        credential = actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = VisitorToken.create!(visitor: actor)
        credential_ref = credential.public_id
      when :org
        actor = Operator.create!
        credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = OperatorToken.create!(staff: actor)
        credential_ref = credential.external_id
      end
      requirement = StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      )
      parent = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      # Synthetic evidence isolates finalization and credential revocation, not WebAuthn signature verification.
      parent.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: transactions.database_now, verified_credential_ref: credential_ref,
      )
      continuity, = continuities.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
      )
      issuance = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: parent, ceremony_session_ref: continuity.id.to_s,
      )
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        Array.new(2) do |index|
          Thread.new do
            tickets.connected_to(role: :writing) do
              tickets.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                if index.zero?
                  begin
                    IdentityStepUpCeremonyFreshnessCommitter.call!(
                      actor: actors.find(actor.id), token: tokens.find(token.id),
                      transaction: transactions.find(parent.id), requirement: requirement,
                      raw_result: issuance.code,
                    )
                    :finalized
                  rescue IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound
                    :finalization_refused
                  end
                else
                  actors.connection_class_for_self.connected_to(role: :writing) do
                    changing_actor = actors.find(actor.id)
                    changing_actor.with_lock do
                      changing_credential = passkeys.lock.find(credential.id)
                      revoked_status =
                        case surface
                        when :app then ClientPasskeyStatus::REVOKED
                        when :com then VisitorPasskeyStatus::REVOKED
                        when :org then OperatorPasskeyStatus::REVOKED
                        end
                      changing_credential.update!(status_id: revoked_status)
                      CredentialSecurityTransition.call(
                        actor: changing_actor, current_session: tokens.find(token.id), reason: :mfa_reset,
                        affected_surface: surface, revoke_other_sessions: false,
                      )
                    end
                  end
                  :credential_revoked
                end
              end
            end
          end
        end
      pids = nil
      results =
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end

      assert_equal 2, pids.uniq.length
      assert_equal :credential_revoked, results.last
      assert_not_equal 1, credential.reload.status_id, "ACTIVE has ID 1 on each actor's Passkey status table"
      assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
      assert_includes [:finalized, :finalization_refused], results.first
      assert_predicate token.reload, :currently_usable?
      assert_not_predicate token, :revoked?
      assert_nil token.last_step_up_at
      assert_not StepUpResolver.call(token: token, requirement: requirement).satisfied?
      if results.first == :finalized
        assert_equal "consumed", parent.reload.status
        assert_predicate continuity.reload, :completed?
      else
        assert_equal "revoked", parent.reload.status
        assert_predicate continuity.reload, :terminal?
      end
      assert_raises(
        IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied, ActiveRecord::RecordNotFound,
      ) do
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor: actor, token: token, transaction: parent, requirement: requirement, raw_result: issuance.code,
        )
      end
      assert_nil token.reload.last_step_up_at
    ensure
      if threads
        2.times { release << true }
        threads.each { |thread| thread.kill unless thread.join(10) }
      end
      if parent
        continuities.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        sessions.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        transactions.where(id: parent.id).delete_all
      end
      tokens.where(id: token.id).delete_all if token
      passkeys.where(id: credential.id).delete_all if credential
      VisitorEmail.where(id: contact.id).delete_all if contact
      if actor
        case surface
        when :app then ClientAuthorityLock.where(client_id: actor.id).delete_all
        when :com then VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
        when :org then OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all
      end
    end

    test "#{surface} cancellation racing Base finalization retains exactly one coherent terminal outcome" do
      case surface
      when :app
        actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::BOTH)
        credential = actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = ClientToken.create!(user: actor)
        credential_ref = credential.public_id
      when :com
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::BOTH)
        contact = actor.visitor_emails.create!(
          address: "cancellation-race-#{SecureRandom.hex(8)}@example.com",
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
        )
        credential = actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = VisitorToken.create!(visitor: actor)
        credential_ref = credential.public_id
      when :org
        actor = Operator.create!
        credential = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public")
        token = OperatorToken.create!(staff: actor)
        credential_ref = credential.external_id
      end
      requirement = StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      )
      parent = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
      ).transaction
      # Synthetic evidence isolates finalization and cancellation, not WebAuthn signature verification.
      parent.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: transactions.database_now, verified_credential_ref: credential_ref,
      )
      continuity, = continuities.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
      )
      issuance = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: parent, ceremony_session_ref: continuity.id.to_s,
      )
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        Array.new(2) do |index|
          Thread.new do
            tickets.connected_to(role: :writing) do
              tickets.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                if index.zero?
                  begin
                    IdentityStepUpCeremonyFreshnessCommitter.call!(
                      actor: actors.find(actor.id), token: tokens.find(token.id),
                      transaction: transactions.find(parent.id), requirement: requirement,
                      raw_result: issuance.code,
                    )
                    :finalized
                  rescue IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied
                    :finalization_refused
                  end
                else
                  canceled = IdentityStepUpCeremonyCancellationCommitter.call!(
                    actor: actors.find(actor.id), token: tokens.find(token.id),
                    transaction: transactions.find(parent.id),
                  )
                  canceled ? :canceled : :cancellation_refused
                end
              end
            end
          end
        end
      pids = nil
      results =
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end

      assert_equal 2, pids.uniq.length
      assert_predicate token.reload, :currently_usable?
      assert_not_predicate token, :revoked?
      if results.first == :finalized
        assert_equal :cancellation_refused, results.last
        assert_equal "consumed", parent.reload.status
        assert_predicate continuity.reload, :completed?
        assert_equal parent.verified_at, token.last_step_up_at
        assert_predicate StepUpResolver.call(token: token, requirement: requirement), :satisfied?
        event = token.last_step_up_at
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor: actor, token: token, transaction: parent, requirement: requirement, raw_result: issuance.code,
        )

        assert_equal event, token.reload.last_step_up_at
        assert_not IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: parent)
      else
        assert_equal :finalization_refused, results.first
        assert_equal :canceled, results.last
        assert_equal "canceled", parent.reload.status
        assert_not_nil parent.canceled_at
        assert_not_nil continuity.reload.cancelled_at
        assert_not_predicate continuity, :completed?
        assert_nil token.last_step_up_at
        assert_not_predicate StepUpResolver.call(token: token, requirement: requirement), :satisfied?
        assert IdentityStepUpCeremonyCancellationCommitter.call!(actor: actor, token: token, transaction: parent)
        assert_raises(IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            actor: actor, token: token, transaction: parent, requirement: requirement, raw_result: issuance.code,
          )
        end
        assert_nil token.reload.last_step_up_at
      end
    ensure
      if threads
        2.times { release << true }
        threads.each { |thread| thread.kill unless thread.join(10) }
      end
      if parent
        continuities.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        sessions.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        transactions.where(id: parent.id).delete_all
      end
      tokens.where(id: token.id).delete_all if token
      passkeys.where(id: credential.id).delete_all if credential
      VisitorEmail.where(id: contact.id).delete_all if contact
      if actor
        case surface
        when :app then ClientAuthorityLock.where(client_id: actor.id).delete_all
        when :com then VisitorAuthorityLock.where(visitor_id: actor.id).delete_all
        when :org then OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all
      end
    end
  end

  [
    [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession, AppTicketRecord, :app],
    [VisitorStepUpCeremonyTransaction, VisitorAuthCeremonySession, ComTicketRecord, :com],
    [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession, OrgTicketRecord, :org],
  ].each do |parent_model, continuity_model, writer_model, surface|
    test "#{surface} writer connections close expired continuity once and refuse its competing transition" do
      parent = parent_model.create_transaction!(
        actor_ref: "concurrency-actor", session_ref: "concurrency-session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"],
      )
      continuity, = continuity_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id, ttl: 1.second,
      )
      decision_time = continuity.expires_at
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        Array.new(2) do
          Thread.new do
            writer_model.connected_to(role: :writing) do
              writer_model.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                begin
                  continuity_model.find(continuity.id).revoke!(now: decision_time)
                  :revoked
                rescue AuthCeremonySession::InvalidTransition
                  :terminal_refused
                end
              end
            end
          end
        end
      pids = nil
      results =
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end

      assert_equal 2, pids.uniq.length
      assert_equal [:revoked, :terminal_refused], results.sort
      assert_equal decision_time.iso8601(6), continuity.reload.revoked_at.iso8601(6)
      assert_predicate continuity, :terminal?
      assert_not continuity.active?(now: decision_time)
      assert_raises(AuthCeremonySession::InvalidTransition) do
        continuity.record_authentication_evidence!(method: "passkey", now: decision_time)
      end
    ensure
      if threads
        2.times { release << true }
        threads.each do |thread|
          thread.kill unless thread.join(10)
        end
      end
      if parent
        continuity_model.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        parent_model.where(id: parent.id).delete_all
      end
    end
  end

  test "APP cleanup racing expired continuity revocation either retains the complete cohort or removes it atomically" do
    now = Time.current
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "cleanup-race-actor", session_ref: "cleanup-race-session", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
    )
    continuity, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id, now: now - 9.days,
    )
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      Array.new(2) do |index|
        Thread.new do
          AppTicketRecord.connected_to(role: :writing) do
            AppTicketRecord.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              if index.zero?
                begin
                  count = IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(:app)
                  (count == 1) ? :purged : :retained
                rescue ActiveRecord::InvalidForeignKey
                  :cleanup_refused
                end
              else
                begin
                  ClientAuthCeremonySession.find(continuity.id).revoke!(now: now)
                  :revoked
                rescue ActiveRecord::RecordNotFound
                  :already_purged
                end
              end
            end
          end
        end
      end
    pids = nil
    results =
      Timeout.timeout(10) do
        pids = [ready.pop, ready.pop]
        2.times { release << true }
        threads.map(&:value)
      end
    parent_present = ClientStepUpCeremonyTransaction.exists?(parent.id)
    continuity_present = ClientAuthCeremonySession.exists?(continuity.id)

    assert_equal 2, pids.uniq.length
    assert_equal parent_present, continuity_present
    if parent_present
      assert_includes [:retained, :cleanup_refused], results.first
      assert_equal :revoked, results.last
      assert_equal now.iso8601(6), continuity.reload.revoked_at.iso8601(6)
      assert_not continuity.active?(now: now)
      assert_raises(AuthCeremonySession::InvalidTransition) do
        continuity.record_authentication_evidence!(method: "passkey", now: now)
      end
    else
      assert_equal :purged, results.first
      assert_equal :already_purged, results.last
      assert_nil ClientAuthCeremonySession.find_by(id: continuity.id)
    end
  ensure
    if threads
      2.times { release << true }
      threads.each { |thread| thread.kill unless thread.join(10) }
    end
    if parent
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
      ClientStepUpCeremonyTransaction.where(id: parent.id).delete_all
    end
  end
end
# rubocop:enable ThreadSafety/NewThread
