# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/authentication-security-mode.md D3: Step-Up evidence is bound to the operation (scope and
# audience), the target (resource), the actor and the session, and is consumed once. Window edges are
# checked one second inside, exactly at and one second past each Security Mode maximum.
class TokenStepUpEvidenceConsumptionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  NOW = Time.zone.parse("2026-10-25 00:00:00")
  SCOPE = "settings_passkey"
  TARGET = "passkey-target-1"

  test "APP evidence authorizes one operation and a second consumption is refused" do
    token = evidence_token(client)

    token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)

    assert_nil token.reload.last_step_up_at
    assert_not StepUpResolver.call(token: token, requirement: requirement(token), now: NOW).satisfied?
    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
    end
  end

  test "COM evidence authorizes one operation and a second consumption is refused" do
    token = evidence_token(visitor)

    token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
    end
  end

  test "ORG evidence authorizes one operation and a second consumption is refused" do
    token = evidence_token(operator, method: "passkey")

    token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
    end
  end

  test "evidence for another operation is refused and kept" do
    token = evidence_token(client)

    assert_refused_and_kept(token, requirement(token, scope: "settings_email"))
    assert_refused_and_kept(token, requirement(token, audience: "step_up:other"))
  end

  test "evidence for another target is refused and kept" do
    token = evidence_token(client)

    assert_refused_and_kept(token, requirement(token, resource_ref: "passkey-target-2"))
    assert_refused_and_kept(token, requirement(token, resource_ref: nil))
  end

  test "a requirement naming another actor is refused and the evidence is kept" do
    token = evidence_token(client)
    other = client

    assert_refused_and_kept(token, requirement(token, actor_ref: other.public_id))
  end

  test "evidence recorded for another session is refused and kept" do
    actor = client
    token = evidence_token(actor)
    other_session = authentication_harness_create_token(actor)

    assert_refused_and_kept(token, requirement(token, session_binding: other_session.public_id))
    token.update!(last_step_up_session_public_id: other_session.public_id)

    assert_refused_and_kept(token, requirement(token))
  end

  test "NORMAL evidence is consumable one second before 15 minutes and refused at and after 15 minutes" do
    assert consumed?(client, age: 15.minutes - 1.second)
    assert_not consumed?(client, age: 15.minutes)
    assert_not consumed?(client, age: 15.minutes + 1.second)
  end

  test "ADVANCED evidence is consumable one second before 5 minutes and refused at and after 5 minutes" do
    assert consumed?(operator, age: 5.minutes - 1.second, method: "passkey")
    assert_not consumed?(operator, age: 5.minutes, method: "passkey")
    assert_not consumed?(operator, age: 5.minutes + 1.second, method: "passkey")
  end

  test "a rolled-back operation keeps the evidence for a retry" do
    token = evidence_token(client)

    ClientToken.transaction do
      token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
      raise ActiveRecord::Rollback
    end

    assert_predicate StepUpResolver.call(token: token.reload, requirement: requirement(token), now: NOW), :satisfied?
  end

  test "a requirement that does not demand Step-Up cannot consume evidence" do
    token = evidence_token(client)
    not_required = StepUpRequirement.new(step_up_required: false)

    assert_raises(ArgumentError) { token.consume_step_up_evidence!(requirement: not_required, now: NOW) }
  end

  private

  def client = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)

  def visitor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL)

  def operator
    Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
  end

  def evidence_token(actor, method: "email_otp", age: 1.second)
    token = authentication_harness_create_token(actor)
    token.update!(
      last_step_up_at: NOW - age, last_step_up_scope: SCOPE, last_step_up_method: method,
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:test", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: false, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: TARGET,
    )
    token
  end

  def requirement(token, scope: SCOPE, audience: "step_up:test", resource_ref: TARGET,
                  actor_ref: token.actor_record.public_id, session_binding: token.public_id)
    StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: %i(email_otp passkey totp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, session_binding: session_binding, token_binding: token.public_id,
      ttl: 15.minutes, purpose: "step_up", audience: audience, require_session_binding: true,
      actor_ref: actor_ref, resource_ref: resource_ref, tenant_ref: nil,
    )
  end

  def assert_refused_and_kept(token, refused_requirement)
    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      token.consume_step_up_evidence!(requirement: refused_requirement, now: NOW)
    end
    assert_equal SCOPE, token.reload.last_step_up_scope
  end

  def consumed?(actor, age:, method: "email_otp")
    token = evidence_token(actor, method: method, age: age)
    token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
    true
  rescue TokenStatusManagement::StepUpEvidenceUnavailable
    false
  end
end
