# frozen_string_literal: true

require "test_helper"

class BaseBootstrapAdmissionIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Base bootstrap is registration-only and retains the original protected return and deadline" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
    requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
      audience: "step_up:app", allowed_methods: %i(passkey totp),
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: first.transaction.transaction_id)
    record.update!(attempt_count: 2)
    repeated = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )

    assert_equal first.transaction.id, repeated.transaction.id
    assert_equal first.transaction.expires_at, repeated.transaction.expires_at
    assert_equal "bootstrap", first.transaction.purpose
    assert_equal "settings_birthdate", first.transaction.required_scope
    assert_equal "/identity/birthdate", first.transaction.return_to
    assert_equal "none", first.transaction.required_aal
    assert_not first.transaction.phishing_resistant_required
    assert_equal 2, record.reload.attempt_count
    assert_nil token.reload.last_step_up_at
    assert_equal "bootstrap_handoff", BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: repeated.reference, surface: "app", expected_intent: "bootstrap",
    ).fetch("purpose")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: first.reference, surface: "app", expected_intent: "step_up",
      )
    end
  end

  # Boundary on root_login_established_at + 10 minutes, decided on the database clock: one
  # microsecond inside the window, exactly at its end, and one microsecond past it.
  { 1 => true, 0 => false, -1 => false }.each do |microseconds, admitted|
    test "bootstrap with #{format("%+d", microseconds)} microseconds of primary-authentication freshness left is " \
         "#{admitted ? "admitted" : "refused"}" do
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      now = ClientStepUpCeremonyTransaction.database_now
      token = ClientToken.create!(
        user: actor,
        root_login_established_at: now - SecurityTokenLifetimes::BOOTSTRAP_PRIMARY_AUTHENTICATION_FRESHNESS +
          Rational(microseconds, 1_000_000),
      )
      requirement = StepUpRequirement.new(
        step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
        audience: "step_up:app", allowed_methods: %i(passkey totp),
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )

      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        if admitted
          issuance = BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
          )

          assert_equal "bootstrap", issuance.transaction.purpose
        else
          error =
            assert_raises(BaseAuthAdmissionCoordinator::Denied) do
              BaseStepUpAdmissionIssuer.call!(
                actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
              )
            end

          assert_equal "bootstrap_not_fresh", error.code
          assert_equal 0, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
        end
      end

      assert_nil token.reload.last_step_up_at
    end
  end

  test "bootstrap is refused for a session that records no root login" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: nil)

    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
            audience: "step_up:app", allowed_methods: %i(passkey totp),
            session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
          ), return_to: "/identity/birthdate",
        )
      end

    assert_equal "bootstrap_not_fresh", error.code
    assert_equal 0, ClientStepUpCeremonyTransaction.where(session_ref: token.public_id).count
  end

  test "an ordinary step-up is not subject to the bootstrap freshness window" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor, root_login_established_at: 3.hours.ago)

    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )

    assert_equal "step_up", issuance.transaction.purpose
  end

  test "refreshing or using the session does not move the bootstrap freshness anchor" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    established = 11.minutes.ago.change(usec: 0)
    token = ClientToken.create!(user: actor, root_login_established_at: established)
    token.rotate_refresh_token!
    token.update!(last_used_at: Time.current)

    assert_equal established, token.reload.root_login_established_at
    error =
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
            audience: "step_up:app", allowed_methods: %i(passkey totp),
            session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
          ), return_to: "/identity/birthdate",
        )
      end

    assert_equal "bootstrap_not_fresh", error.code
  end

  test "verified Email is configured and unavailable Passkey or TOTP history requires recovery rather than bootstrap" do
    %i(verified_email revoked_passkey inactive_totp revoked_totp).each do |state|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      case state
      when :verified_email
        actor.client_emails.create!(
          address: "#{SecureRandom.hex(8)}@example.com",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
      when :revoked_passkey
        actor.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "public",
          status_id: ClientPasskeyStatus::REVOKED,
        )
      when :inactive_totp, :revoked_totp
        actor.client_totp_credentials.create!(
          private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: (state == :inactive_totp) ?
            ClientTotpCredentialStatus::INACTIVE : ClientTotpCredentialStatus::REVOKED,
        )
      end
      token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
      requirement = StepUpRequirement.new(
        step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
        audience: "step_up:app", allowed_methods: %i(passkey totp),
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
          )
        end
      end
      assert_nil token.reload.last_step_up_at
    end
  end

  test "email is a bootstrap method where the surface supports email and is refused where it does not" do
    client = Client.create!(status_id: ClientStatus::ACTIVE)
    client_token = ClientToken.create!(user: client, root_login_established_at: Time.current)

    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: client, token: client_token,
      requirement: StepUpRequirement.new(
        step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap", audience: "step_up:app",
        allowed_methods: [:email_otp], session_binding: client_token.public_id,
        token_binding: client_token.public_id, require_session_binding: true,
      ), return_to: "/identity/birthdate",
    )

    assert_equal ["email_otp"], issuance.transaction.allowed_methods_array
    assert_equal "bootstrap", issuance.transaction.purpose
    assert_nil client_token.reload.last_step_up_at

    operator = Operator.create!
    operator_token = OperatorToken.create!(staff: operator, root_login_established_at: Time.current)

    assert_no_difference("OperatorStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: operator, token: operator_token,
          requirement: StepUpRequirement.new(
            step_up_required: false, scope: "settings_email", purpose: "bootstrap", audience: "step_up:org",
            allowed_methods: [:email_otp], session_binding: operator_token.public_id,
            token_binding: operator_token.public_id, require_session_binding: true,
          ), return_to: "/identity/emails",
        )
      end
    end
  end

  test "bootstrap refuses assurance claims and methods outside the registration matrix" do
    [
      { required_aal: :aal1 }, { phishing_resistant_required: true }, { step_up_required: true },
      { allowed_methods: [:secret_credential] }, { allowed_methods: %i(passkey secret_credential) },
      { allowed_methods: [] },
    ].each do |attributes|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor, root_login_established_at: Time.current)
      requirement = StepUpRequirement.new(
        **{
          step_up_required: false,
          scope: "settings_birthdate",
          purpose: "bootstrap",
          audience: "step_up:app",
          allowed_methods: %i(passkey totp),
          session_binding: token.public_id,
          token_binding: token.public_id,
          require_session_binding: true,
        }.merge(attributes),
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
          )
        end
      end
    end
  end
end
