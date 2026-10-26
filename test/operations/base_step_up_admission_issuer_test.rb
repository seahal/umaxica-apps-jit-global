# frozen_string_literal: true

require "test_helper"

class BaseStepUpAdmissionIssuerTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    test "#{surface} an expired predecessor is closed rather than treated as a conflicting intent" do
      actor_id = SecureRandom.random_number(1 << 60) + 1_000_000_000
      actor, token =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: actor_id, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor)]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: actor_id, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor)]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: actor_id)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor)]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      nonce = SecureRandom.hex(32)
      first = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys", base_browser_nonce: nonce, base_token: token,
      )
      # Public persistence arranges an expired parent; production observes expiry under its Ticket lock.
      first.transaction.update!(expires_at: first.transaction.class.database_now - Rational(1, 1_000_000))
      replacement = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement: StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          **requirement.to_h.merge(scope: "settings_email"),
        ),
        return_to: "/identity/emails", base_browser_nonce: nonce, base_token: token,
      )

      assert_not_equal first.transaction.id, replacement.transaction.id
      assert_equal ["expired", "pending", "settings_email", nil],
                   [first.transaction.reload.status, replacement.transaction.reload.status,
                    replacement.transaction.required_scope, token.reload.last_step_up_at,]
    end
  end

  test "each realm reuses exact intent and refuses changed scope target or purpose without extending authority" do
    %w(app com org).each do |surface|
      actor, token, model =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientStepUpCeremonyTransaction]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), VisitorStepUpCeremonyTransaction]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorStepUpCeremonyTransaction]
        end
      attributes = {
        scope: "settings_passkey",
        purpose: "step_up",
        step_up_required: true,
        allowed_methods: [:passkey],
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        audience: "step_up:#{surface}",
        session_binding: token.public_id,
        token_binding: token.public_id,
        require_session_binding: true,
        ttl: 15.minutes,
        actor_ref: actor.public_id,
        resource_ref: nil,
        tenant_ref: nil,
      }
      arguments = {
        actor: actor,
        token: token,
        requirement: StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          **attributes,
        ),
        return_to: "/identity/passkeys",
        base_browser_nonce: SecureRandom.urlsafe_base64(32),
        base_token: token,
      }
      first = BaseStepUpAdmissionIssuer.call!(**arguments)
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: surface, reference: first.reference)
      deadlines = [first.transaction.expires_at, binding.expires_at]
      repeated = BaseStepUpAdmissionIssuer.call!(**arguments)

      assert_equal [first.transaction.id, first.reference], [repeated.transaction.id, repeated.reference]
      assert_equal deadlines, [first.transaction.reload.expires_at, binding.reload.expires_at]

      [
        [{ scope: "settings_email" }, "/identity/emails"],
        [{}, "/identity/passkeys?ri=jp"],
        [{ purpose: "reauthentication", full_reauthentication_required: true }, "/identity/passkeys"],
      ].each do |change, target|
        error =
          assert_raises(BaseAuthAdmissionCoordinator::Denied, "#{surface}: #{change.keys}") do
            BaseStepUpAdmissionIssuer.call!(
              **arguments.merge(
                requirement: StepUpRequirement.new(
                  step_up_required: true,
                  phishing_resistant_required: false,
                  user_verification_required: false,
                  full_reauthentication_required: false,
                  **attributes.merge(change),
                ),
                return_to: target,
              ),
            )
          end

        assert_equal "transaction_conflict", error.code
        assert_equal 1, model.where(session_ref: token.public_id).count
        assert_equal ["pending", *deadlines, nil, nil],
                     [first.transaction.reload.status, first.transaction.expires_at, binding.reload.expires_at,
                      binding.retired_at, binding.redeemed_at,]
        assert_nil token.reload.last_step_up_at
      end
    end
  end

  test "issuance rejects revoked devices and displaced refresh roots in every realm without creating a parent" do
    %w(app com org).each do |surface|
      %i(revoked displaced).each do |condition|
        actor, token, model =
          case surface
          when "app"
            actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
            [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientStepUpCeremonyTransaction]
          when "com"
            actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
            [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), VisitorStepUpCeremonyTransaction]
          when "org"
            actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
            [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorStepUpCeremonyTransaction]
          end
        device = token.device_session
        if condition == :revoked
          device.revoke!(reason: "user_logout")
        else
          device.update!(current_refresh_token_id: nil)
        end
        requirement = StepUpRequirement.new(
          scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
          phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
          audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
          require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id,
          resource_ref: nil, tenant_ref: nil,
        )

        assert_no_difference -> { model.count } do
          assert_raises(BaseAuthAdmissionCoordinator::Denied, "#{surface}: #{condition}") do
            BaseStepUpAdmissionIssuer.call!(
              actor:, token:, requirement:, return_to: "/identity/passkeys",
              base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
            )
          end
        end
      end
    end
  end

  test "restart form lookup preserves each realm parent and rejects foreign proof or changed intent" do
    %w(app com org).each do |surface|
      actor, token, other_token =
        case surface
        when "app"
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor),
           ClientToken.create!(authentication_epoch: 0, user: actor),]
        when "com"
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor),
           VisitorToken.create!(authentication_epoch: 0, visitor: actor),]
        when "org"
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor),
           OperatorToken.create!(authentication_epoch: 0, staff: actor),]
        end
      requirement = StepUpRequirement.new(
        scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
        phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
        audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
      )
      nonce = SecureRandom.urlsafe_base64(32)
      issuance = BaseStepUpAdmissionIssuer.call!(
        actor:, token:, requirement:, return_to: "/identity/passkeys",
        base_browser_nonce: nonce, base_token: token,
      )
      binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
      arguments = {
        actor:,
        token:,
        requirement:,
        return_to: "/identity/passkeys",
        base_browser_nonce: nonce,
        base_token: token,
        restart_of: binding.entry_ref,
      }
      parent_deadline = issuance.transaction.expires_at

      assert_equal binding.id, BaseStepUpAdmissionIssuer.restart_binding_for_form!(**arguments).id
      [
        { base_browser_nonce: SecureRandom.urlsafe_base64(32) },
        { token: other_token, base_token: other_token },
        { return_to: "/identity/passkeys/changed" },
        { restart_of: nil }, { restart_of: "" }, { restart_of: 0 }, { restart_of: [binding.entry_ref] },
        { restart_of: {} }, { restart_of: "#{binding.entry_ref}x" },
      ].each do |invalid|
        assert_raises(BaseAuthAdmissionCoordinator::Denied, "#{surface}: #{invalid.keys}") do
          BaseStepUpAdmissionIssuer.restart_binding_for_form!(**arguments.merge(invalid))
        end
        assert_equal [nil, nil, nil, parent_deadline],
                     [binding.reload.auth_ceremony_session_id, binding.retired_at, binding.redeemed_at,
                      issuance.transaction.reload.expires_at,]
      end

      # Public persistence deliberately builds an expired fixture; production never changes this immutable deadline.
      binding.update_columns(expires_at: binding.class.database_now - Rational(1, 1_000_000))

      assert_equal binding.id, BaseStepUpAdmissionIssuer.restart_binding_for_form!(**arguments).id
      issuance.transaction.update!(expires_at: issuance.transaction.class.database_now - Rational(1, 1_000_000))
      assert_raises(BaseAuthAdmissionCoordinator::Denied, surface) do
        BaseStepUpAdmissionIssuer.restart_binding_for_form!(**arguments)
      end
      assert_equal [nil, nil], [binding.reload.retired_at, binding.redeemed_at]
    end
  end

  %i(app com org).each do |surface|
    test "#{surface} Base refuses adjacent operation paths and invalid target types without creating authority" do
      case surface
      when :app
        actor = clients(:one)
        token = ClientToken.create!(authentication_epoch: 0, user: actor)
        parents = ClientStepUpCeremonyTransaction
        sessions = ClientStepUpSession
      when :com
        actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
        token = VisitorToken.create!(authentication_epoch: 0, visitor: actor, skip_session_limit_check: true)
        parents = VisitorStepUpCeremonyTransaction
        sessions = VisitorStepUpSession
      when :org
        actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
        token = OperatorToken.create!(authentication_epoch: 0, staff: actor)
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
            BaseStepUpAdmissionIssuer.call!(
              actor: actor, token: token, requirement: requirement, return_to: path,
              base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
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
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_112_000_000_000)
          [actor, ClientToken.create!(authentication_epoch: 0, user: actor), ClientStepUpCeremonyTransaction]
        when :com
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_112_000_000_000)
          [actor, VisitorToken.create!(authentication_epoch: 0, visitor: actor), VisitorStepUpCeremonyTransaction]
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_112_000_000_000)
          [actor, OperatorToken.create!(authentication_epoch: 0, staff: actor), OperatorStepUpCeremonyTransaction]
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
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/passkeys",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
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
            BaseStepUpAdmissionIssuer.call!(
              actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
              base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
            )
          end
        end
        token.update!(restored)
      end
      # Consolidation ADR 2.3: the window is the shorter of the requirement TTL and the mode maximum.
      window = actor.security_mode_advanced? ? StepUpResolver::ADVANCED_MAXIMUM_TTL : StepUpRequirement::DEFAULT_TTL
      [0, 1].each do |microseconds|
        parents.stub(:database_now, event + window + Rational(microseconds, 1_000_000)) do
          assert_no_difference(-> { parents.count }) do
            assert_raises(BaseAuthAdmissionCoordinator::Denied) do
              BaseStepUpAdmissionIssuer.call!(
                actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
                base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
              )
            end
          end
        end
      end
      issuance =
        parents.stub(:database_now, event + window - Rational(1, 1_000_000)) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/passkeys",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
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
      _auth_session, raw_sid =
        begin
          fv5019 = binding
          fv5018 = token
          fv5016, fv5015 = fv5019.class.auth_admission_session_class.issue!
          fv5019.attach_auth_session!(
            auth_session: fv5016, confirmation_ref: SecureRandom.uuid,
          )
          fv5017 = AuthAdmissionBinding.browser_digest(
            surface: fv5019.class.auth_admission_surface_name,
            entry_ref: fv5019.entry_ref,
            nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          )
          fv5019.confirm_base!(
            base_token: fv5018,
            browser_digest: fv5017,
          )
          [fv5016, fv5015]
        end

      assert_equal issuance.transaction.transaction_id, BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: issuance.reference, surface: surface.to_s, expected_intent: "credential_registration",
        binding: binding, raw_auth_sid: raw_sid,
      ).fetch("subject_ref")
    end
  end

  test "APP TOTP registration accepts prior Email proof but rejects unrelated scopes and assurance claims" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_113_000_000_000)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
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
        assert_raises(ArgumentError) {
          StepUpRequirement.new(
            step_up_required: true,
            phishing_resistant_required: false,
            user_verification_required: false,
            full_reauthentication_required: false,
            **attributes.merge(invalid),
          )
        }
        next
      end

      requirement =
        begin
          StepUpRequirement.new(
            step_up_required: true,
            phishing_resistant_required: false,
            user_verification_required: false,
            full_reauthentication_required: false,
            **attributes.merge(invalid),
          )
        rescue ArgumentError
          next
        end

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement,
            return_to: "/identity/totps",
            base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
          )
        end
      end
    end
    assert_raises(ArgumentError) do
      StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        **attributes.merge(required_aal: :aal1),
      )
    end
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        **attributes,
      ), return_to: "/identity/totps",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_equal ["totp"], issuance.transaction.allowed_methods_array
    assert_equal "credential_registration", issuance.transaction.purpose
    assert_equal event, token.reload.last_step_up_at
  end

  test "a repeated Base start preserves the concrete transaction deadline and attempt count" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
      actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    session_record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: first.transaction.transaction_id)
    session_record.update!(attempt_count: 3)
    deadline = first.transaction.expires_at
    second = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_equal first.reference, second.reference
    assert_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal deadline, second.transaction.expires_at
    assert_equal 3, session_record.reload.attempt_count
    assert_equal "step_up", second.transaction.purpose
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: second.reference)
    _auth_session, raw_sid =
      begin
        fv5014 = binding
        fv5013 = token
        fv5011, fv5010 = fv5014.class.auth_admission_session_class.issue!
        fv5014.attach_auth_session!(
          auth_session: fv5011, confirmation_ref: SecureRandom.uuid,
        )
        fv5012 = AuthAdmissionBinding.browser_digest(
          surface: fv5014.class.auth_admission_surface_name,
          entry_ref: fv5014.entry_ref,
          nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        )
        fv5014.confirm_base!(
          base_token: fv5013,
          browser_digest: fv5012,
        )
        [fv5011, fv5010]
      end
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: second.reference, surface: "app", expected_intent: "step_up",
      binding: binding, raw_auth_sid: raw_sid,
    )

    assert_equal second.transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "step_up_handoff", payload.fetch("purpose")
  end

  test "another scope cannot rewrite a pending transaction" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = BaseStepUpAdmissionIssuer.call!(
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
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseStepUpAdmissionIssuer.call!(
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
        base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
      )
    end
    assert_equal "settings_birthdate", first.transaction.reload.required_scope
  end

  # The expiry instant itself is decided on the database clock and is pinned in the transition
  # contract test; here the previous transaction is clearly past it.
  test "a new admission after the previous transaction expired records that expiry and starts a new one" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = BaseStepUpAdmissionIssuer.call!(
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
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    ).transaction
    # Moves the deadline into the past; no public API shortens a live transaction.
    first.update_columns(expires_at: ClientStepUpCeremonyTransaction.database_now - 1.second)

    second = BaseStepUpAdmissionIssuer.call!(
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
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
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
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first = BaseStepUpAdmissionIssuer.call!(
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
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    ).transaction

    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
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
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
        )
      end

    assert_equal "transaction_conflict", error.code
    assert_equal "pending", first.reload.status
    assert_equal 1, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
  end

  test "an explicit restart cancels a redeemed pending ceremony and starts a new parent" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    first_requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement: first_requirement, return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: first.reference)
    auth_session, raw_sid =
      begin
        fv5009 = binding
        fv5008 = token
        fv5006, fv5005 = fv5009.class.auth_admission_session_class.issue!
        fv5009.attach_auth_session!(
          auth_session: fv5006, confirmation_ref: SecureRandom.uuid,
        )
        fv5007 = AuthAdmissionBinding.browser_digest(
          surface: fv5009.class.auth_admission_surface_name,
          entry_ref: fv5009.entry_ref,
          nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        )
        fv5009.confirm_base!(
          base_token: fv5008,
          browser_digest: fv5007,
        )
        [fv5006, fv5005]
      end
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: first.transaction.transaction_id,
    )
    binding.redeem!(auth_session:, admitted_auth_session: admitted)

    second = BaseStepUpAdmissionIssuer.call!(
      actor:, token:,
      requirement: StepUpRequirement.new(
        step_up_required: true,
        phishing_resistant_required: false,
        user_verification_required: false,
        full_reauthentication_required: false,
        **first_requirement.to_h.merge(scope: "settings_telephone"),
      ),
      return_to: "/identity/telephones", restart_of: first.reference,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_not_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal "canceled", first.transaction.reload.status
    assert_equal "pending", second.transaction.status
    assert_not_equal first.reference, second.reference
  end

  test "explicit same-intent restart cancels a redeemed pending ceremony instead of reopening it" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: first.reference)
    auth_session, raw_sid =
      begin
        fv5004 = binding
        fv5003 = token
        fv5001, fv5000 = fv5004.class.auth_admission_session_class.issue!
        fv5004.attach_auth_session!(
          auth_session: fv5001, confirmation_ref: SecureRandom.uuid,
        )
        fv5002 = AuthAdmissionBinding.browser_digest(
          surface: fv5004.class.auth_admission_surface_name,
          entry_ref: fv5004.entry_ref,
          nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
        )
        fv5004.confirm_base!(
          base_token: fv5003,
          browser_digest: fv5002,
        )
        [fv5001, fv5000]
      end
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: first.transaction.transaction_id,
    )
    binding.redeem!(auth_session:, admitted_auth_session: admitted)

    assert_no_difference "ClientAuthAdmissionBinding.count" do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor:, token:, requirement:, return_to: "/identity/birthdate",
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
        )
      end
    end

    second = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/birthdate", restart_of: first.reference,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_not_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal "canceled", first.transaction.reload.status
    assert_equal "pending", second.transaction.status
    assert_not_equal first.reference, second.reference
  end

  test "explicit restart replaces an expired unredeemed binding without extending its parent" do
    actor = clients(:one)
    token = ClientToken.create!(authentication_epoch: 0, user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: "settings_birthdate", allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, ttl: 15.minutes, purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
      require_session_binding: true, actor_ref: actor.public_id, resource_ref: nil, tenant_ref: nil,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/birthdate",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: first.reference)
    deadline = first.transaction.expires_at
    binding.update_columns(expires_at: binding.class.database_now - 1.second)

    second = BaseStepUpAdmissionIssuer.call!(
      actor:, token:, requirement:, return_to: "/identity/birthdate", restart_of: first.reference,
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
    )

    assert_equal first.transaction.id, second.transaction.id
    assert_equal deadline, second.transaction.expires_at
    assert_not_equal first.reference, second.reference
    assert_predicate binding.reload.retired_at, :present?
  end

  test "COM rejects TOTP and Base actor mismatch before creating a transaction" do
    actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
    token = VisitorToken.create!(authentication_epoch: 0, visitor: actor, skip_session_limit_check: true)

    assert_no_difference("VisitorStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
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
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
        )
      end
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
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
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", base_token: token,
        )
      end
    end
  end

  private
end
