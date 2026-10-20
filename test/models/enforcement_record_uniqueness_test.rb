# frozen_string_literal: true

require "test_helper"

class EnforcementRecordUniquenessTest < ActiveSupport::TestCase
  REALMS = [
    [AppEnforcementCase, AppEnforcementAppeal, AppEnforcementPrincipalEffect, :app_enforcement_case_id],
    [ComEnforcementCase, ComEnforcementAppeal, ComEnforcementPrincipalEffect, :com_enforcement_case_id],
    [OrgEnforcementCase, OrgEnforcementAppeal, OrgEnforcementPrincipalEffect, :org_enforcement_case_id],
  ].freeze

  REALMS.each do |case_class, appeal_class, effect_class, case_key|
    [[appeal_class, { reason_code: "incorrect_decision",
                      statement: "Appeal statement",
                      submitted_at: Time.utc(2026, 1, 1),
                      state: "submitted", },],
     [effect_class, { principal_public_id: "consistency-principal",
                      effective_at: Time.utc(2026, 1, 1),
                      access_blocking: false,
                      recovery_blocked: false,
                      reactivation_blocked: false,
                      withdrawal_purge_blocked: false,
                      principal_hard_delete_blocked: false, },],].each do |model, initial|
      test "#{model.name} preserves separate Cases and raw uniqueness" do
        first_case = case_class.create!(
          kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
          release_mode: "verification_required", effective_at: Time.utc(2026, 1, 1),
          reason_code: "security_incident", principal_public_id: "consistency-principal",
          applied_by_operator_public_id: "consistency-operator",
        )
        second_case = case_class.create!(
          kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
          release_mode: "verification_required", effective_at: Time.utc(2026, 1, 1),
          reason_code: "security_incident", principal_public_id: "consistency-principal",
          applied_by_operator_public_id: "consistency-operator",
        )
        record = model.create!(initial.merge(enforcement_case: first_case))
        other = model.create!(initial.merge(enforcement_case: second_case))

        assert_predicate record, :valid?
        record.save!

        assert_equal first_case.id, record.reload[case_key]
        assert_equal second_case.id, other.reload[case_key]
        error =
          assert_raises(ActiveRecord::RecordNotUnique) do
            model.transaction(requires_new: true) do
              model.new(initial.merge(enforcement_case: first_case)).save!(validate: false)
            end
          end
        assert_instance_of PG::UniqueViolation, error.cause
      end

      test "#{model.name} refuses duplicate model writes before persistence" do
        enforcement_case = case_class.create!(
          kind: "security_lock", state: "draft", duration_mode: "indefinite", visibility: "visible",
          release_mode: "verification_required", effective_at: Time.utc(2026, 1, 1),
          reason_code: "security_incident", principal_public_id: "consistency-principal",
          applied_by_operator_public_id: "consistency-operator",
        )
        first = model.create!(initial.merge(enforcement_case: enforcement_case))
        duplicate = model.new(initial.merge(enforcement_case: enforcement_case))

        assert_not duplicate.valid?
        assert duplicate.errors.of_kind?(case_key, :taken)
        [:en, :ja].each do |locale|
          I18n.with_locale(locale) { assert_not_empty duplicate.errors.full_messages }
        end
        assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
        assert_predicate duplicate, :new_record?
        assert_equal first.id, model.find_by!(case_key => enforcement_case.id).id
      end
    end
  end
end
