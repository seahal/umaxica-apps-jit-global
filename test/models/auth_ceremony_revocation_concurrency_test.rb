# frozen_string_literal: true

require "test_helper"
require "timeout"

# A committed row and separate writer connections expose the one-shot revocation boundary.
class AuthCeremonyRevocationConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  fixtures :client_statuses, :client_visibilities, :client_security_modes, :client_mfa_statuses
  fixtures :operator_statuses, :operator_visibilities, :operator_security_modes, :operator_mfa_statuses

  test "credential changes racing authentication evidence leave no usable unfinished sign-in flow" do
    %i(app org).each do |surface|
      actor = token = flow = threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actors, tokens, flows, _, tickets, token_key =
          case surface
          when :app then [Client, ClientToken, ClientSignInFlow, ClientAuthCeremonySession, OpBaseAppRecord, :user_id]
          when :org then [Operator, OperatorToken, OperatorSignInFlow, OperatorAuthCeremonySession, OpBaseOrgRecord,
                          :staff_id,]
          end
        actor = actors.create!(security_mode_id: SecurityModeTestDefault.id_for(actors))
        token = tokens.create!(:authentication_epoch => 0, token_key => actor.id, :id => 9_920_000_000_010)
        flow = SignInFlowTestFactory.create!(surface:, principal_id: actor.id)
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
                      flows.find(flow.id).record_authentication_evidence!(method: "passkey")
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
        assert_predicate flow.reload, :sign_in_halted?
        assert_nil flow.result_digest
        assert_nil flow.base_finalized_at
        assert_predicate token.reload, :currently_usable?
        assert_raises(AuthCeremonySession::InvalidTransition) do
          flow.record_authentication_evidence!(method: "passkey")
        end
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        flows.where(id: flow.id).delete_all if flow
        delete_admission_bindings_for(token) if token
        tokens.where(id: token.id).delete_all if token
        case actor
        when Client
          ClientChronicle.where(actor_type: "Client", actor_id: actor.id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
        when Operator
          OperatorChronicle.where(actor_type: "Operator", actor_id: actor.id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all if actor
      end
    end
  end

  test "independent removal writers preserve the last compatible method on each surface" do
    %i(app org totp).each do |surface|
      actor = nil
      tokens = []
      evidences = []
      grants = []
      threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actor, model, owner_key, token_model, token_key =
          case surface
          when :app then [Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL), ClientPasskey, :user_id,
                          ClientToken, :user_id,]
          when :totp then [Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL), ClientTotpCredential,
                           :user_id, ClientToken, :user_id,]
          when :org then [Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED), OperatorPasskey,
                          :staff_id, OperatorToken, :staff_id,]
          end
        if surface == :totp
          actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "unknown-uv-key")
          credentials =
            Array.new(2) do
              model.create!(
                owner_key => actor.id,
                :user_identity_totp_credential_status_id => ClientTotpCredentialStatus::ACTIVE,
              )
            end
        else
          credentials =
            Array.new(2) do |_index|
              model.create!(
                owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
                :public_key => "removal-race-key", :uv_verified_at => Time.current,
              )
            end
        end
        # D-132: ADVANCED keeps two active Passkeys, so ORG holds one more that neither writer removes.
        if surface == :org
          model.create!(
            owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
            :public_key => "removal-race-floor-key", :uv_verified_at => Time.current,
          )
        end
        # Exercise the writer against independently authorized existing sessions. ORG issuance
        # currently caps new sessions at one; retained older sessions can still reach this boundary.
        credentials.each_with_index do |credential, index|
          token = token_model.create!(
            :authentication_epoch => 0, token_key => actor.id, :id => 9_920_000_000_011 + index,
          )
          tokens << token
          token.rotate_refresh_token!
          device = token.device_session_record!
          evidence_ref = (surface == :org) ? credential.external_id : credential.public_id
          scope = (surface == :totp) ? "settings_totp" : "settings_passkey"
          method = (surface == :totp) ? "totp" : "passkey"
          audience = (surface == :org) ? "step_up:org" : "step_up:app"
          token.update!(
            last_step_up_at: token_model.database_now, last_step_up_scope: scope,
            last_step_up_method: method, last_step_up_credential_ref: evidence_ref,
            last_step_up_resource_ref: evidence_ref,
            last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
            last_step_up_audience: audience, last_step_up_phishing_resistant: true,
            last_step_up_user_verified: true, last_step_up_full_reauthentication: false,
          )
          op_record, grant_class, oidc_client, grant_owner =
            if surface == :org
              [OpBaseOrgRecord, OpOrgGrant, OidcClientRegistry.find!("base-org-ww"), :operator_token]
            else
              [OpBaseAppRecord, OpAppGrant, OidcClientRegistry.find!("base-app-ww"), :client_token]
            end
          op_now = op_record.database_now
          grant = grant_class.create!(
            :authentication_epoch => token.authentication_epoch, grant_owner => token,
            :device_session_id => device.id, :oidc_client_id => oidc_client.client_id,
            :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
            :oidc_auth_time => Time.at(op_now.to_time.to_i).utc, :oidc_acr => StepUpEvidenceResolver::STEP_UP_ACR,
            :oidc_amr => JSON.generate(["passkey"]), :refresh_token_expires_at => op_now + 10.minutes,
          )
          grant.issue_refresh_token!(now: op_now)
          grants << [grant_class, grant.id]
          evidences << StepUpEvidenceValue.new(
            acr: grant.oidc_acr, amr: ["passkey"], auth_time: grant.oidc_auth_time.to_i, sid: grant.public_id,
            sub: OidcSubject.for(actor, resource_type: (surface == :org) ? "operator" : "client"),
            client_id: oidc_client.client_id, aud: [oidc_client.aud], jti: grant.oidc_jti,
          )
        end
        ActiveRecord::Base.connection_handler.clear_active_connections!
        threads =
          credentials.zip(tokens, evidences).map do |credential, token, evidence|
            Thread.new do
              model.connection_class_for_self.connected_to(role: :writing) do
                model.connection_pool.with_connection do |connection|
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  IdentityCredentialRemovalCommitter.call!(
                    actor: actor.class.find(actor.id), credential: model.find(credential.id),
                    current_session: token_model.find(token.id), step_up_evidence: evidence,
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
            model.where(
              owner_key => actor.id,
              :user_identity_totp_credential_status_id => ClientTotpCredentialStatus::ACTIVE,
            )
          else
            model.active.where(owner_key => actor.id)
          end

        floor = (surface == :org) ? 2 : 1

        assert_equal floor, remaining.count, surface.to_s
        expected_total = (surface == :totp) ? 2 : floor

        assert_equal expected_total, model.where(owner_key => actor.id).count, surface.to_s
        tokens.each { |token| assert_predicate token.reload, :currently_usable?, surface.to_s }
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        device_class = (surface == :org) ? OperatorDeviceSession : ClientDeviceSession
        device_ids = tokens.filter_map(&:device_session_id)
        grants.each do |grant_class, grant_id|
          grant_class.where(id: grant_id).delete_all
        end
        token_model.where(id: tokens.map(&:id)).delete_all if tokens.any?
        device_class.where(id: device_ids).delete_all if device_ids.any?
        model.where(owner_key => actor.id).delete_all if actor && model
        case actor
        when Client
          ClientPasskey.where(user_id: actor.id).delete_all
          ClientChronicle.where(actor_type: "Client", actor_id: actor.id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
          Client.where(id: actor.id).delete_all
        when Operator
          OperatorChronicle.where(actor_type: "Operator", actor_id: actor.id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
          Operator.where(id: actor.id).delete_all
        end
      end
    end
  end

  test "independent writers can create only one remaining Passkey slot on each surface" do
    %i(app org).each do |surface|
      actor = nil
      threads = nil
      ready = Queue.new
      release = Queue.new
      begin
        actor, model, owner_key, writer =
          case surface
          when :app then [Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL), ClientPasskey, :user_id,
                          AppPrincipalRecord,]
          when :org then [Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED), OperatorPasskey,
                          :staff_id, OrgPrincipalRecord,]
          end
        9.times do |_index|
          model.create!(
            owner_key => actor.id, :webauthn_id => SecureRandom.uuid, :public_key => "slot-public-key",
          )
        end
        ActiveRecord::Base.connection_handler.clear_active_connections!
        threads =
          Array.new(2) do
            Thread.new do
              writer.connection_class_for_self.connected_to(role: :writing) do
                writer.connection_pool.with_connection do |connection|
                  ready << connection.select_value("SELECT pg_backend_pid()")
                  release.pop
                  begin
                    PasskeyRegistrationOperation.call!(
                      actor: actor.class.find(actor.id), passkey_class: model,
                      attributes: {
                        webauthn_id: SecureRandom.uuid, public_key: "competing-key",
                      },
                      audit: { event_type: "passkey.registered.settings", surface: surface.to_s },
                    )
                    :created
                  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
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
        assert_equal 10, model.active.where(owner_key => actor.id).count, surface.to_s
      ensure
        if threads
          2.times { release << true }
          threads.each { |thread| thread.kill unless thread.join(10) }
        end
        model.where(owner_key => actor.id).delete_all if actor && model
        case actor
        when Client
          ClientPasskeyAuditOutbox.where(actor_ref: actor.public_id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
          Client.where(id: actor.id).delete_all
        when Operator
          OperatorPasskeyAuditOutbox.where(actor_ref: actor.public_id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
          Operator.where(id: actor.id).delete_all
        end
      end
    end
  end

  test "APP competing Email OTP verification consumes one code and records one verification event" do
    actor = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::BOTH,
    )
    credential = actor.client_emails.create!(
      address: "otp-race-#{SecureRandom.hex(8)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
    token = ClientToken.create!(authentication_epoch: 0, id: 9_920_000_000_012, user: actor)
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
          OpBaseAppRecord.connected_to(role: :writing) do
            OpBaseAppRecord.connection_pool.with_connection do |connection|
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
    delete_admission_bindings_for(token) if token
    ClientToken.where(id: token.id).delete_all if token
    ClientEmail.where(id: credential.id).delete_all if credential
    if actor
      ClientAuthorityLock.where(client_id: actor.id).delete_all
      Client.where(id: actor.id).delete_all
    end
  end

  [
    [:app, Client, ClientToken, ClientStepUpCeremonyTransaction],
    [:org, Operator, OperatorToken, OperatorStepUpCeremonyTransaction],
  ].each do |surface, actors, tokens, transactions|
    test "#{surface} Base admission refuses OIDC step-up without OP context" do
      actor =
        case surface
        when :app
          Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
            visibility_id: ClientVisibility::BOTH,
          )
        when :org
          Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
        end
      token =
        case surface
        when :app then ClientToken.create!(authentication_epoch: 0, user: actor)
        when :org then OperatorToken.create!(authentication_epoch: 0, staff: actor)
        end
      requirement = StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        step_up_required: true, phishing_resistant_required: true, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, actor_ref: actor.public_id,
        resource_ref: nil, tenant_ref: nil, audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )
      transaction_count = transactions.count

      error =
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor:, token:, requirement:, return_to: "/identity/birthdate",
            base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
          )
        end

      assert_equal "malformed_request", error.code
      assert_equal transaction_count, transactions.count
      assert_nil token.reload.last_step_up_at
    ensure
      tokens.where(id: token.id).delete_all if token
      if actor
        case actor
        when Client
          ClientChronicle.where(actor_type: "Client", actor_id: actor.id).delete_all
          ClientAuthorityLock.where(client_id: actor.id).delete_all
        when Operator
          OperatorChronicle.where(actor_type: "Operator", actor_id: actor.id).delete_all
          OperatorAuthorityLock.where(operator_id: actor.id).delete_all
        end
        actors.where(id: actor.id).delete_all
      end
    end
  end

  [
    [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession, OpBaseAppRecord, :app],
    [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession, OpBaseOrgRecord, :org],
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
                  continuity_model.find(continuity.id).revoke!
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
        continuity_model.stub(:database_now, decision_time) do
          Timeout.timeout(10) do
            pids = [ready.pop, ready.pop]
            2.times { release << true }
            threads.map(&:value)
          end
        end

      assert_equal 2, pids.uniq.length
      assert_equal [:revoked, :terminal_refused], results.sort
      assert_equal decision_time.iso8601(6), continuity.reload.revoked_at.iso8601(6)
      assert_predicate continuity, :terminal?
      assert_not continuity.active?(now: decision_time)
      assert_raises(AuthCeremonySession::InvalidTransition) do
        continuity.record_authentication_evidence!(method: "passkey")
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
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
    )
    continuity.update!(expires_at: now - 8.days)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      Array.new(2) do |index|
        Thread.new do
          OpBaseAppRecord.connected_to(role: :writing) do
            OpBaseAppRecord.connection_pool.with_connection do |connection|
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
                  ClientAuthCeremonySession.find(continuity.id).revoke!
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
      ClientAuthCeremonySession.stub(:database_now, now) do
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end
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
        continuity.record_authentication_evidence!(method: "passkey")
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

  def delete_admission_bindings_for(token)
    binding_model =
      case token
      when ClientToken then ClientAuthAdmissionBinding
      when OperatorToken then OperatorAuthAdmissionBinding
      else raise ArgumentError, "unsupported test token class: #{token.class.name}"
      end

    binding_model.where(base_token_id: token.id).delete_all
  end
end
