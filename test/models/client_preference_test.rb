# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_preferences
# Database name: app_principal
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
#  user_id         :bigint           not null
#
# Indexes
#
#  index_client_preferences_on_public_id  (public_id) UNIQUE
#  index_client_preferences_on_user_id    (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id) ON DELETE => cascade
#
require "test_helper"

class ClientPreferenceTest < ActiveSupport::TestCase
  test "belongs to user" do
    pref = client_preferences(:one)

    assert_predicate pref.user, :present?
  end

  test "has one language child" do
    pref = client_preferences(:one)

    assert_predicate pref.user_preference_language, :present?
  end

  test "has one timezone child" do
    pref = client_preferences(:one)

    assert_predicate pref.user_preference_timezone, :present?
  end

  test "has one region child" do
    pref = client_preferences(:one)

    assert_predicate pref.user_preference_region, :present?
  end

  test "has one theme child" do
    pref = client_preferences(:one)

    assert_predicate pref.user_preference_theme, :present?
  end

  test "user_id is unique" do
    pref = client_preferences(:one)
    duplicate = ClientPreference.new(user_id: pref.user_id)

    assert_not duplicate.valid?
  end

  test "cookie consent defaults to false" do
    user = clients(:sample_user)
    pref = ClientPreference.new(user: user)

    assert_not pref.consented
    assert_not pref.functional
    assert_not pref.performant
    assert_not pref.targetable
  end

  test "generates public_id on create" do
    user = clients(:sample_user)
    pref = ClientPreference.create!(user: user)

    assert_not_nil pref.public_id
    assert_equal 21, pref.public_id.length
  end

  test "does not overwrite existing public_id" do
    user = clients(:sample_user)
    pref = ClientPreference.create!(user: user, public_id: "user_pref_custom_1")

    assert_equal "user_pref_custom_1", pref.public_id
  end

  test "loading an existing preference preserves stored defaults" do
    pref = client_preferences(:one)
    pref.update!(
      consented: true,
      functional: true,
      performant: true,
      targetable: true,
    )

    loaded = ClientPreference.find(pref.id)

    assert loaded.consented
    assert loaded.functional
    assert loaded.performant
    assert loaded.targetable
  end

  test "1:1 relationship with user" do
    user = clients(:one)

    assert_predicate user.user_preference, :present?
    assert_equal user.id, user.user_preference.user_id
  end
end
