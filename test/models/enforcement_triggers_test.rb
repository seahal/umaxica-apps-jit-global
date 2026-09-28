# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/database-trigger-usage-boundary.md: a trigger is only real if a test
# proves it through a path that bypasses ActiveRecord entirely. Model
# callback tests prove nothing about the trigger and do not satisfy this
# requirement -- every test below uses delete_all or raw SQL.
class EnforcementTriggersTest < ActiveSupport::TestCase
  test "trigger inventory in app_zenith matches the expected set exactly" do
    triggers =
      ActiveRecord::Base.connected_to(role: :writing) do
        AppEnforcementCase.lease_connection.select_values(
          "SELECT trigger_name FROM information_schema.triggers " \
          "WHERE trigger_schema = 'public' ORDER BY trigger_name",
        )
      end

    assert_equal(
      %w(enforcement_protect_client_emails_delete enforcement_protect_clients_delete),
      triggers.uniq.sort,
      "Adding or removing a trigger requires updating this inventory test " \
      "(adr/database-trigger-usage-boundary.md: triggers are named, enumerated, and asserted).",
    )
  end

  # requires_new: true opens a savepoint, so the ROLLBACK TO SAVEPOINT Rails
  # issues when the block raises restores the connection for assertions made
  # afterward -- without it, PostgreSQL leaves the whole enclosing fixture
  # transaction aborted after the trigger's RAISE EXCEPTION.
  test "delete_all on client_emails raises when a permanently_frozen email Authentication Method Effect is in force" do
    client = clients(:one)
    operator = operators(:one)
    email = ClientEmail.create!(
      user_id: client.id,
      raw_address: "trigger-protected@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    the_case = AppEnforcementCase.new(
      kind: "method_protection",
      duration_mode: "indefinite",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "security_incident",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.authentication_method_effects.build(
      principal_public_id: client.public_id,
      authentication_method: "email",
      effect: "permanently_frozen",
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientEmail.transaction(requires_new: true) do
          ClientEmail.where(id: email.id).delete_all
        end
      end

    assert_match(/permanently_frozen Authentication Method Effect/, error.message)
    assert ClientEmail.exists?(email.id)
  end

  test "a client_emails row with no permanently_frozen effect deletes normally via delete_all" do
    client = clients(:one)
    email = ClientEmail.create!(
      user_id: client.id,
      raw_address: "unprotected@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    ClientEmail.where(id: email.id).delete_all

    assert_not ClientEmail.exists?(email.id)
  end

  test "raw SQL DELETE on clients raises when an in-force principal_hard_delete_blocked Principal Effect exists" do
    client = Client.create!(public_id: "trig_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)
    operator = operators(:one)

    the_case = AppEnforcementCase.new(
      kind: "permanent_ban",
      duration_mode: "permanent",
      visibility: "visible",
      release_mode: "break_glass_only",
      effective_at: Time.current,
      reason_code: "abuse",
      principal_public_id: client.public_id,
      applied_by_operator_public_id: operator.public_id,
    )
    the_case.build_principal_effect(
      principal_public_id: client.public_id,
      principal_hard_delete_blocked: true,
      effective_at: Time.current,
    )
    EnforcementCaseApplyOperation.call(
      enforcement_case: the_case,
      actor_operator_public_id: the_case.applied_by_operator_public_id,
    )

    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        Client.transaction(requires_new: true) do
          Client.lease_connection.execute("DELETE FROM clients WHERE id = #{client.id}")
        end
      end

    assert_match(/principal_hard_delete_blocked Principal Effect/, error.message)
    assert Client.exists?(client.id)
  end

  test "a client with no in-force principal_hard_delete_blocked effect deletes normally via raw SQL" do
    client = Client.create!(public_id: "trig_#{SecureRandom.uuid}".chars.first(16).join, status_id: ClientStatus::ACTIVE)

    Client.transaction(requires_new: true) do
      Client.lease_connection.execute("DELETE FROM clients WHERE id = #{client.id}")
    end

    assert_not Client.exists?(client.id)
  end
end
