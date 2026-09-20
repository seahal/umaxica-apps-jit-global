# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preferences
# Database name: org_principal
#
#  id              :bigint           not null, primary key
#  consent_version :uuid
#  consented       :boolean          default(FALSE), not null
#  consented_at    :datetime
#  currency        :string           default("jpy"), not null
#  date_format     :string           default("iso"), not null
#  density         :string           default("standard"), not null
#  functional      :boolean          default(FALSE), not null
#  language        :string           default("ja"), not null
#  motion          :string           default("standard"), not null
#  page_size       :string           default("infinity"), not null
#  performant      :boolean          default(FALSE), not null
#  region          :string           default("jp"), not null
#  targetable      :boolean          default(FALSE), not null
#  theme           :string           default("sy"), not null
#  time_format     :string           default("24"), not null
#  timezone        :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  public_id       :string(21)
#  staff_id        :bigint           not null
#
# Indexes
#
#  index_operator_preferences_on_public_id  (public_id) UNIQUE
#  index_operator_preferences_on_staff_id   (staff_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#
require "test_helper"

class OperatorPreferenceTest < ActiveSupport::TestCase
  test "belongs to staff" do
    pref = operator_preferences(:one)

    assert_predicate pref.staff, :present?
  end

  test "has one language child" do
    pref = operator_preferences(:one)

    assert_predicate pref.staff_preference_language, :present?
  end

  test "has one timezone child" do
    pref = operator_preferences(:one)

    assert_predicate pref.staff_preference_timezone, :present?
  end

  test "has one region child" do
    pref = operator_preferences(:one)

    assert_predicate pref.staff_preference_region, :present?
  end

  test "has one theme child" do
    pref = operator_preferences(:one)

    assert_predicate pref.staff_preference_theme, :present?
  end

  test "staff_id is unique" do
    pref = operator_preferences(:one)
    duplicate = OperatorPreference.new(staff_id: pref.staff_id)

    assert_not duplicate.valid?
  end

  test "cookie consent defaults to false" do
    staff = operators(:sample_staff)
    pref = OperatorPreference.new(staff: staff)

    assert_not pref.consented
    assert_not pref.functional
    assert_not pref.performant
    assert_not pref.targetable
  end

  test "generates public_id on create" do
    staff = operators(:sample_staff)
    pref = OperatorPreference.create!(staff: staff)

    assert_not_nil pref.public_id
    assert_equal 21, pref.public_id.length
  end

  test "does not overwrite existing public_id" do
    staff = operators(:sample_staff)
    pref = OperatorPreference.create!(staff: staff, public_id: "staff_pref_custom")

    assert_equal "staff_pref_custom", pref.public_id
  end

  test "loading an existing preference preserves stored defaults" do
    pref = operator_preferences(:one)
    pref.update!(
      consented: true,
      functional: true,
      performant: true,
      targetable: true,
    )

    loaded = OperatorPreference.find(pref.id)

    assert loaded.consented
    assert loaded.functional
    assert loaded.performant
    assert loaded.targetable
  end

  test "1:1 relationship with staff" do
    staff = operators(:one)

    assert_predicate staff.staff_preference, :present?
    assert_equal staff.id, staff.staff_preference.staff_id
  end

  test "adult_content_gate returns nothing when no gate is set" do
    assert_equal "nothing", OperatorPreference.new.adult_content_gate
  end

  test "adult_content_gate returns the gate option name when a gate is set" do
    preference = OperatorPreference.new
    preference.build_operator_preference_adult_content_gate(
      option: OperatorPreferenceAdultContentGateOption.new(id: OperatorPreferenceAdultContentGateOption::APPROVED),
    )

    assert_equal "approved", preference.adult_content_gate
  end
end
