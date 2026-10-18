# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAuthenticationMethodLockPolicyTest < ActiveSupport::TestCase
  test "is not locked when no enforcement case exists for the principal" do
    client = clients(:one)
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    assert_not policy.locked?(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: client.public_id,
      authentication_method: "google",
    )
  end

  test "is locked when an in-force method_protection case has an unusable effect on that method" do
    client = clients(:one)
    operator = operators(:one)
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "google",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert policy.locked?(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: client.public_id,
      authentication_method: "google",
    )
    assert_not policy.locked?(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: client.public_id,
      authentication_method: "apple",
    )
  end

  # chk_app_enforcement_method_effects_no_social_freeze forbids permanently_frozen
  # on google/apple; only unusable and mutation_locked are legal for social
  # methods in the app realm, so permanently_frozen coverage lives on the org
  # realm's entra method below instead.
  test "is locked when the effect is permanently_frozen on the org realm's entra method" do
    operator = operators(:one)
    admin_operator = operators(:two)
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    the_case = OrgEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: operator.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: operator.public_id,
      authentication_method: "entra",
      effect: "permanently_frozen",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert policy.locked?(
      enforcement_case_class: OrgEnforcementCase,
      principal_public_id: operator.public_id,
      authentication_method: "entra",
    )
  end

  test "is locked for the Org realm entra method independently of the App realm" do
    operator = operators(:one)
    admin_operator = operators(:two)
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    the_case = OrgEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: operator.public_id,
      applied_by_operator_public_id: admin_operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: operator.public_id,
      authentication_method: "entra",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    assert policy.locked?(
      enforcement_case_class: OrgEnforcementCase,
      principal_public_id: operator.public_id,
      authentication_method: "entra",
    )
    assert_not policy.locked?(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: operator.public_id,
      authentication_method: "entra",
    )
  end

  test "is not locked once the case has ended" do
    client = clients(:one)
    operator = operators(:one)
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "google",
      effect: "unusable",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    EnforcementCaseEndOperation.call(
      enforcement_case: the_case, reason: "revoked",
      ended_by_operator_public_id: operator.public_id,
    )

    assert_not policy.locked?(
      enforcement_case_class: AppEnforcementCase,
      principal_public_id: client.public_id,
      authentication_method: "google",
    )
  end
end
