# frozen_string_literal: true

require "test_helper"

class AppSecretStepUpBindingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  fixtures :clients, :client_statuses

  test "Secret root sessions cannot bootstrap a newly registered Step-Up method" do
    [[:passkey, "settings_passkey", "/settings/passkeys/new"],
     [:totp, "settings_totp", "/settings/totps/new"],].each do |method, scope, path|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor, established_authentication_method: "secret")
      requirement = StepUpRequirement.new(
        scope: scope, purpose: "bootstrap", step_up_required: false, allowed_methods: [method],
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_no_difference("ClientStepUpSession.count") do
          assert_raises(BaseAuthAdmissionCoordinator::Denied) do
            issue_base_step_up_admission!(actor: actor, token: token, requirement: requirement, return_to: path)
          end
        end
      end
      assert_nil token.reload.last_step_up_at
      assert_equal "secret", token.established_authentication_method
    end
  end

  test "canonical Secret management uses scoped bound Step-Up without an AAL threshold" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      allowed_methods: %i(passkey totp), session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    admission = issue_base_step_up_admission!(
      actor: actor, token: token, requirement: requirement, return_to: "/secrets/new?ri=jp",
    )

    assert_equal "settings_secret_credential", admission.transaction.required_scope
    assert_equal "none", admission.transaction.required_aal
    assert_equal "step_up", admission.transaction.purpose
    assert_equal "/secrets/new?ri=jp", admission.transaction.return_to
    assert_equal token.public_id, admission.transaction.session_ref
    assert_not requirement.method_allowed?(:secret)
    assert_equal "secret", token.reload.established_authentication_method
    assert_nil token.last_step_up_at
  end

  test "Secret management refuses bootstrap even before any authenticator is configured" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_secret_credential", purpose: "bootstrap",
      audience: "step_up:app", allowed_methods: [:passkey],
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/secrets/new",
      )
    end
  end

  test "Secret scope cannot authorize another operation legacy path or arbitrary destination" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      allowed_methods: [:passkey], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )

    ["/settings/secrets", "/settings/secret_credentials", "/secrets-extra", "/identity/emails",
     "https://untrusted.example/secrets", "//untrusted.example/secrets",].each do |path|
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(actor: actor, token: token, requirement: requirement, return_to: path)
      end
    end
  end

  test "Secret management refuses another session binding without a transaction" do
    actor = clients(:one)
    first = ClientToken.create!(user: actor)
    second = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      allowed_methods: [:passkey], session_binding: first.public_id,
      token_binding: first.public_id, require_session_binding: true,
    )

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: actor, token: second, requirement: requirement, return_to: "/secrets/new",
        )
      end
    end
  end

  test "Secret itself cannot be the method of Secret management Step-Up" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor, established_authentication_method: "secret")
    requirement = StepUpRequirement.new(
      scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:app",
      allowed_methods: [:secret], session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )

    assert_no_difference("ClientStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: actor, token: token, requirement: requirement, return_to: "/secrets/new",
        )
      end
    end
  end

  test "com and org retain their existing Secret management scope and reject app resource paths" do
    %w(com org).each do |surface|
      actor, token =
        case surface
        when "com"
          visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
          [visitor, VisitorToken.create!(visitor: visitor)]
        when "org"
          operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
          [operator, OperatorToken.create!(staff: operator)]
        else
          raise ArgumentError, "unsupported test surface"
        end
      requirement = StepUpRequirement.new(
        scope: "settings_secret_credential", purpose: "step_up", audience: "step_up:#{surface}",
        allowed_methods: [:passkey], session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
      )
      admission = issue_base_step_up_admission!(
        actor: actor, token: token, requirement: requirement, return_to: "/identity/secrets",
      )

      assert_equal surface, admission.transaction.surface
      assert_equal "/identity/secrets", admission.transaction.return_to
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        issue_base_step_up_admission!(
          actor: actor, token: token, requirement: requirement, return_to: "/secrets/new",
        )
      end
    end
  end
end
