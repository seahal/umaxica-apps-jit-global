# frozen_string_literal: true

require "test_helper"

class OperatorTelephonePublicIdImmutabilityTest < ActiveSupport::TestCase
  test "the public identity is required after the operational NULL-only backfill" do
    assert_not OperatorTelephone.columns_hash.fetch("public_id").null
  end

  test "direct SQL cannot replace clear or blank an issued ORG Telephone identity" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550281", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.reload.attributes
    connection = OperatorTelephone.lease_connection

    ["z" * 21, nil, "", " ", "0"].each do |replacement|
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          OperatorTelephone.transaction(requires_new: true) do
            connection.execute(
              "UPDATE operator_telephones SET public_id = #{connection.quote(replacement)} " \
              "WHERE id = #{telephone.id}",
            )
          end
        end
      assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      assert_equal original, telephone.reload.attributes
    end
  end

  test "single and bulk bypass updates reject replacing an issued identity without changing other facts" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550282", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.reload.attributes

    %i(single bulk).each do |writer|
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          OperatorTelephone.transaction(requires_new: true) do
            if writer == :single
              telephone.update_columns(public_id: "z" * 21)
            else
              # The SQL boundary must protect writers that bypass model validation.
              OperatorTelephone.where(id: telephone.id).update_all(public_id: "z" * 21)
            end
          end
        end
      assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      assert_equal original, telephone.reload.attributes
    end
  end

  test "upsert cannot overwrite the public identity of its existing primary-key row" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550283", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.reload.attributes
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorTelephone.transaction(requires_new: true) do
          OperatorTelephone.upsert_all(
            [original.merge("public_id" => "z" * 21)], unique_by: :id, update_only: [:public_id],
          )
        end
      end

    assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
    assert_equal original, telephone.reload.attributes
  end

  test "an unchanged identity and independent attempt-state update remain writable" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    telephone = actor.staff_telephones.create!(
      raw_number: "+12025550284", confirm_policy: true, confirm_using_mfa: true,
    )
    original = telephone.public_id

    assert telephone.update_columns(public_id: original, otp_attempts_count: 1)
    assert_equal original, telephone.reload.public_id
    assert_equal 1, telephone.otp_attempts_count
  end
end
