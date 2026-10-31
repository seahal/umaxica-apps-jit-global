# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/unified-enforcement.md, D9: permanently_frozen is the one effect that
# outlives the Case that set it, so each realm restricts it to the two Case
# kinds that may impose it.
class EnforcementAuthenticationMethodEffectTest < ActiveSupport::TestCase
  REALMS = [
    {
      name: "app",
      effect_model: AppEnforcementAuthenticationMethodEffect,
      case_model: AppEnforcementCase,
      method: "passkey",
      principal: -> { clients(:one) },
    },
    {
      name: "org",
      effect_model: OrgEnforcementAuthenticationMethodEffect,
      case_model: OrgEnforcementCase,
      method: "entra",
      principal: -> { operators(:two) },
    },
  ].freeze

  REALMS.each do |realm|
    test "#{realm[:name]} realm rejects permanently_frozen on a case kind that may not impose it" do
      principal = instance_exec(&realm[:principal])
      enforcement_case = realm[:case_model].create!(
        kind: "temporary_freeze",
        duration_mode: "timed",
        visibility: "visible",
        release_mode: "automatic",
        effective_at: Time.current,
        expires_at: 1.day.from_now,
        reason_code: "abuse",
        principal_public_id: principal.public_id,
        applied_by_operator_public_id: operators(:one).public_id,
      )
      effect = realm[:effect_model].new(
        enforcement_case: enforcement_case,
        principal_public_id: principal.public_id,
        authentication_method: realm[:method],
        effect: "permanently_frozen",
        effective_at: Time.current,
      )

      assert_not_predicate effect, :valid?
      assert_includes effect.errors[:effect],
                      "permanently_frozen is only legal on permanent_ban or method_protection Cases"
    end

    test "#{realm[:name]} realm accepts permanently_frozen on a method_protection case" do
      principal = instance_exec(&realm[:principal])
      enforcement_case = realm[:case_model].create!(
        kind: "method_protection",
        duration_mode: "indefinite",
        visibility: "visible",
        release_mode: "operator",
        effective_at: Time.current,
        reason_code: "abuse",
        principal_public_id: principal.public_id,
        applied_by_operator_public_id: operators(:one).public_id,
      )
      effect = realm[:effect_model].new(
        enforcement_case: enforcement_case,
        principal_public_id: principal.public_id,
        authentication_method: realm[:method],
        effect: "permanently_frozen",
        effective_at: Time.current,
      )

      assert_predicate effect, :valid?
    end

    test "#{realm[:name]} realm leaves a non-freezing effect unconstrained by case kind" do
      principal = instance_exec(&realm[:principal])
      enforcement_case = realm[:case_model].create!(
        kind: "temporary_freeze",
        duration_mode: "timed",
        visibility: "visible",
        release_mode: "automatic",
        effective_at: Time.current,
        expires_at: 1.day.from_now,
        reason_code: "abuse",
        principal_public_id: principal.public_id,
        applied_by_operator_public_id: operators(:one).public_id,
      )
      effect = realm[:effect_model].new(
        enforcement_case: enforcement_case,
        principal_public_id: principal.public_id,
        authentication_method: realm[:method],
        effect: "mutation_locked",
        effective_at: Time.current,
      )

      assert_predicate effect, :valid?
    end
  end
end
