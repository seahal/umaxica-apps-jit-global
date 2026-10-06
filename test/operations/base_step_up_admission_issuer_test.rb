# frozen_string_literal: true

require "test_helper"

class BaseStepUpAdmissionIssuerTest < ActiveSupport::TestCase
  %i(app com org).each do |surface|
    test "#{surface} Base refuses adjacent operation paths and invalid target types without creating authority" do
      case surface
      when :app
        actor = clients(:one)
        token = ClientToken.create!(user: actor)
        parents = ClientStepUpCeremonyTransaction
        sessions = ClientStepUpSession
      when :com
        actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
        token = VisitorToken.create!(visitor: actor, skip_session_limit_check: true)
        parents = VisitorStepUpCeremonyTransaction
        sessions = VisitorStepUpSession
      when :org
        actor = Operator.create!
        token = OperatorToken.create!(staff: actor)
        parents = OperatorStepUpCeremonyTransaction
        sessions = OperatorStepUpSession
      end
      requirement = StepUpRequirement.new(
        step_up_required: true, scope: "settings_passkey", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )

      [
        nil, "", 0, {}, "/settings/passkeys-extra", "/settings/passkeys_extra", "/settings/passkeys\0extra",
      ].each do |path|
        assert_no_difference [-> { parents.count }, -> { sessions.count }] do
          assert_raises(BaseAuthAdmissionCoordinator::Denied, "target #{path.inspect}") do
            issue_base_step_up_admission!(
              actor: actor, token: token, requirement: requirement, return_to: path,
              base_browser_nonce: "test-browser-nonce", base_token: token,
            )
          end
        end
      end
      assert_nil token.reload.last_step_up_at
      assert_predicate token, :currently_usable?
    end
  end

  self.fixture_table_names = []

  fixtures :clients, :client_statuses, :visitors, :visitor_statuses

  test "regular registration requires existing Base proof and produces registration-only authority on each surface" do
    %i(app com org).each do |surface|
      actor, token, parents =
        case surface
        when :app
          actor = Client.create!(id: 9_112_000_000_000)
          [actor, ClientToken.create!(user: actor), ClientStepUpCeremonyTransaction]
        when :com
          actor = Visitor.create!(id: 9_112_000_000_000)
          [actor, VisitorToken.create!(visitor: actor), VisitorStepUpCeremonyTransaction]
        when :org
          actor = Operator.create!(id: 9_112_000_000_000)
          [actor, OperatorToken.create!(staff: actor), OperatorStepUpCeremonyTransaction]
        end
      requirement = StepUpRequirement.new(
        step_up_required: false, scope: "settings_passkey", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes,
        purpose: "credential_registration", audience: "step_up:#{surface}",
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      assert_no_difference(-> { parents.count }) do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          issue_base_step_up_admission!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/passkeys",
            base_browser_nonce: "test-browser-nonce", base_token: token,
          )
        end
      end
      # Synthetic prior Base evidence isolates permission issuance; WebAuthn is covered separately.
      event = parents.database_now
      token.update!(
        last_step_up_at: event, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_aal: "aal1", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_session_public_id: token.public_id,
        last_step_up_phishing_resistant: true, last_step_up_user_verified: false,
        last_step_up_credential_ref: "credential_1", last_step_up_full_reauthentication: false,
      )
      [
        [{ last_step_up_purpose: "bootstrap" }, { last_step_up_purpose: "step_up" }],
        [{ last_step_up_scope: "settings_birthdate" }, { last_step_up_scope: "settings_passkey" }],
        [{ last_step_up_session_public_id: "foreign-session" }, { last_step_up_session_public_id: token.public_id }],
        [{ last_step_up_audience: "step_up:foreign" }, { last_step_up_audience: "step_up:#{surface}" }],
        [{ last_step_up_method: nil }, { last_step_up_method: "passkey" }],
      ].each do |invalid, restored|
        token.update!(invalid)
        assert_no_difference(-> { parents.count }) do
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            issue_base_step_up_admission!(
              actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
              base_browser_nonce: "test-browser-nonce", base_token: token,
            )
          end
        end
        token.update!(restored)
      end
      [0, 1].each do |microseconds|
        parents.stub(:database_now, event + StepUpRequirement::DEFAULT_TTL + Rational(microseconds, 1_000_000)) do
          assert_no_difference(-> { parents.count }) do
            assert_raises(BaseAuthAdmissionCoordinator::Denied) do
              issue_base_step_up_admission!(
                actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
                base_browser_nonce: "test-browser-nonce", base_token: token,
              )
            end
          end
        end
      end
      issuance =
        parents.stub(:database_now, event + StepUpRequirement::DEFAULT_TTL - Rational(1, 1_000_000)) do
          issue_base_step_up_admission!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
            base_browser_nonce: "test-browser-nonce", base_token: token,
          )
        end

      assert_equal "credential_registration", issuance.transaction.purpose
      assert_equal "none", issuance.transaction.required_aal
      assert_not issuance.transaction.phishing_resistant_required
      assert_equal event, token.reload.last_step_up_at
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
        surface: surface.to_s,
        reference: issuance.reference,
      )
      _auth_session, raw_sid = prepare_binding_for_consumption!(binding, token)

      assert_equal issuance.transaction.transaction_id, BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: surface.to_s, expected_intent: "credential_registration",
        binding: binding, raw_auth_sid: raw_sid,
      ).fetch("subject_ref")
    end
  end

  test "APP TOTP registration accepts prior Email proof but rejects unrelated scopes and assurance claims" do
    actor = Client.create!(id: 9_113_000_000_000)
    token = ClientToken.create!(user: actor)
    event = ClientStepUpCeremonyTransaction.database_now
    # Synthetic Base evidence tests purpose and method separation, not Email code verification.
    token.update!(
      last_step_up_at: event, last_step_up_scope: "settings_totp", last_step_up_method: "email_otp",
      last_step_up_aal: "none", last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_session_public_id: token.public_id,
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "email-credential", last_step_up_full_reauthentication: false,
    )
    attributes = {
      step_up_required: false,
      scope: "settings_totp",
      allowed_methods: [:totp],
      phishing_resistant_required: false,
      user_verification_required: false,
      full_reauthentication_required: false,
      ttl: 15.minutes,
      purpose: "credential_registration",
      audience: "step_up:app",
      session_binding: token.public_id,
      token_binding: token.public_id,
      require_session_binding: true,
      actor_ref: actor.public_id,
      resource_ref: nil,
      tenant_ref: nil,
    }

    [
      { allowed_methods: [] }, { allowed_methods: [:passkey] }, { allowed_methods: [:email_otp] },
      { step_up_required: true },
      { scope: "settings_birthdate" }, { purpose: "credential_change" },
    ].each do |invalid|
      if invalid[:allowed_methods] == []
        assert_raises(ArgumentError) { StepUpRequirement.new(**attributes.merge(invalid)) }
        next
      end

      requirement =
        begin
          StepUpRequirement.new(**attributes.merge(invalid))
        rescue ArgumentError
          next
        end

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          issue_base_step_up_admission!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/totps",
            base_browser_nonce: "test-browser-nonce", base_token: token,
          )
        end
      end
    end
    assert_raises(ArgumentError) do
      StepUpRequirement.new(**attributes.merge(required_aal: :aal1))
    end
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token, requirement: StepUpRequirement.new(**attributes), return_to: "/identity/totps",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )

    assert_equal ["totp"], issuance.transaction.allowed_methods_array
    assert_equal "credential_registration", issuance.transaction.purpose
    assert_equal event, token.reload.last_step_up_at
  end

  test "a repeated Base start preserves the concrete transaction deadline and attempt count" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = issue_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    session_record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: first.transaction.transaction_id)
    session_record.update!(attempt_count: 3)
    deadline = first.transaction.expires_at
    second = issue_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )

    assert_equal first.reference, second.reference
    assert_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal deadline, second.transaction.expires_at
    assert_equal 3, session_record.reload.attempt_count
    assert_equal "step_up", second.transaction.purpose
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: second.reference)
    _auth_session, raw_sid = prepare_binding_for_consumption!(binding, token)
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: second.reference, surface: "app", expected_intent: "step_up",
      binding: binding, raw_auth_sid: raw_sid,
    )

    assert_equal second.transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "step_up_handoff", payload.fetch("purpose")
  end

  test "another scope cannot rewrite a pending transaction" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    first = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      issue_base_step_up_admission!(
        actor: actor, token: token,
        requirement: StepUpRequirement.new(
          step_up_required: true, scope: "settings_telephone", allowed_methods: [:passkey],
          phishing_resistant_required: false, user_verification_required: false,
          full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
          audience: "step_up:app", session_binding: token.public_id,
          token_binding: token.public_id, require_session_binding: true,
          actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
        ),
        return_to: "/identity/telephones",
        base_browser_nonce: "test-browser-nonce", base_token: token,
      )
    end
    assert_equal "settings_birthdate", first.transaction.reload.required_scope
  end

  # The expiry instant itself is decided on the database clock and is pinned in the transition
  # contract test; here the previous transaction is clearly past it.
  test "a new admission after the previous transaction expired records that expiry and starts a new one" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    first = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    ).transaction
    # Moves the deadline into the past; no public API shortens a live transaction.
    first.update_columns(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)

    second = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_telephone", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/telephones",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    ).transaction

    assert_not_equal first.transaction_id, second.transaction_id
    assert_equal "pending", second.status
    assert_equal "settings_telephone", second.required_scope
    assert_equal "expired", first.reload.status
    assert_nil first.canceled_at
    assert_nil first.consumed_at
    assert_equal second.transaction_id,
                 ClientStepUpSession.find_by!(user_token_id: token.id).step_up_ceremony_transaction_ref
  end

  test "a conflicting admission is refused with the conflict code and leaves the pending transaction open" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    first = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false,
        full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
        actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      ),
      return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    ).transaction

    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            step_up_required: true, scope: "settings_telephone", allowed_methods: [:passkey],
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
            audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true,
            actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
          ),
          return_to: "/identity/telephones",
          base_browser_nonce: "test-browser-nonce", base_token: token,
        )
      end

    assert_equal "transaction_conflict", error.code
    assert_equal "pending", first.reload.status
    assert_equal 1, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
  end

  test "an explicit restart cancels a redeemed pending ceremony and starts a new parent" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    first_requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = issue_base_step_up_admission!(
      actor:, token:, requirement: first_requirement, return_to: "/identity/birthdate",
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: first.reference)
    auth_session, raw_sid = prepare_binding_for_consumption!(binding, token)
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: first.transaction.transaction_id,
    )
    binding.redeem!(auth_session:, admitted_auth_session: admitted)

    second = issue_base_step_up_admission!(
      actor:, token:,
      requirement: StepUpRequirement.new(**first_requirement.to_h.merge(scope: "settings_telephone")),
      return_to: "/identity/telephones", restart_of: first.reference,
      base_browser_nonce: "test-browser-nonce", base_token: token,
    )

    assert_not_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal "canceled", first.transaction.reload.status
    assert_equal "pending", second.transaction.status
    assert_not_equal first.reference, second.reference
  end

  test "COM rejects TOTP and Base actor mismatch before creating a transaction" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    token = VisitorToken.create!(visitor: actor, skip_session_limit_check: true)

    assert_no_difference("VisitorStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            step_up_required: true, scope: "settings_birthdate", allowed_methods: [:totp],
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
            audience: "step_up:com", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true,
            actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
          ),
          return_to: "/identity/birthdate",
          base_browser_nonce: "test-browser-nonce", base_token: token,
        )
      end
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: clients(:one), token: token,
          requirement: StepUpRequirement.new(
            step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
            phishing_resistant_required: false, user_verification_required: false,
            full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
            audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true,
            actor_ref: clients(:one).public_id, resource_ref: nil, tenant_ref: nil,
          ),
          return_to: "/identity/birthdate",
          base_browser_nonce: "test-browser-nonce", base_token: token,
        )
      end
    end
  end

  private

  def prepare_binding_for_consumption!(binding, token)
    auth_session, raw_sid = binding.class.auth_admission_session_class.issue!
    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(
      surface: binding.class.auth_admission_surface_name,
      entry_ref: binding.entry_ref,
      nonce: "test-browser-nonce",
    )
    binding.confirm_base!(base_token: token, browser_digest: digest)
    [auth_session, raw_sid]
  end
end
