# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCurrencyAssociationDestroyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ensure_reference_defaults!
  end

  test "destroying client destroys currency preference child" do
    client = Client.create!
    preference = ClientPreference.create!(user: client)
    currency = ClientPreferenceCurrency.create!(preference: preference)

    # An Identity is physically erased only once it has lapsed and is purgeable.
    client.reload.update!(discard_at: client.created_at, purge_eligible_at: client.created_at)
    client.destroy!

    assert_not ClientPreference.exists?(preference.id)
    assert_not ClientPreferenceCurrency.exists?(currency.id)
  end

  test "destroying visitor destroys currency preference child" do
    visitor = Visitor.create!
    preference = VisitorPreference.create!(visitor: visitor)
    currency = VisitorPreferenceCurrency.create!(preference: preference)

    # An Identity is physically erased only once it has lapsed and is purgeable.
    visitor.reload.update!(discard_at: visitor.created_at, purge_eligible_at: visitor.created_at)
    visitor.destroy!

    assert_not VisitorPreference.exists?(preference.id)
    assert_not VisitorPreferenceCurrency.exists?(currency.id)
  end

  test "destroying operator destroys currency preference child" do
    operator = Operator.create!
    preference = OperatorPreference.create!(staff: operator)
    currency = OperatorPreferenceCurrency.create!(preference: preference)

    operator.destroy!

    assert_not OperatorPreference.exists?(preference.id)
    assert_not OperatorPreferenceCurrency.exists?(currency.id)
  end

  private

  def ensure_reference_defaults!
    [
      ClientStatus,
      ClientVisibility,
      ClientMfaLevel,
      ClientMfaStatus,
      ClientPreferenceCurrencyOption,
      VisitorStatus,
      VisitorVisibility,
      VisitorMfaLevel,
      VisitorMfaStatus,
      VisitorPreferenceCurrencyOption,
      OperatorStatus,
      OperatorVisibility,
      OperatorMfaLevel,
      OperatorMfaStatus,
      OperatorPreferenceCurrencyOption,
    ].each(&:ensure_defaults!)
  end
end
