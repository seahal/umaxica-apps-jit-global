# typed: false
# frozen_string_literal: true

require "test_helper"

class ComEnforcementCaseTest < ActiveSupport::TestCase
  test "apply! transitions a temporary_freeze with an access-blocking Principal Effect to active and locks the " \
       "visitor" do
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)

    the_case = ComEnforcementCase.new(
      kind: "temporary_freeze",
      duration_mode: "timed",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      expires_at: 1.day.from_now,
      reason_code: "security_incident",
      principal_public_id: visitor.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: visitor.public_id,
      access_blocking: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )
    visitor.reload

    assert_equal "active", the_case.state
    assert_predicate visitor, :admin_locked?
    assert_equal 1,
                 EnforcementEvent.where(realm: "com", case_public_id: the_case.public_id, event_type: "applied").count
  end

  test "com realm authentication method effects reject google as an unsupported method" do
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)

    the_case = ComEnforcementCase.create!(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "operator",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: visitor.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    effect = the_case.authentication_method_effects.build(
      principal_public_id: visitor.public_id,
      authentication_method: "google",
      effect: "unusable",
      effective_at: Time.current,
    )

    # Model validation is the first line of defense; the DB CHECK constraint
    # (chk_com_enforcement_method_effects_method) is the second, reached only
    # by a write that bypasses the model layer entirely.
    assert_not_predicate effect, :valid?, "google should not be a valid com-realm authentication_method"

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        effect.save!(validate: false)
      end

    assert_match(/chk_com_enforcement_method_effects_method/, error.message)
  end
end
