# typed: false
# == Schema Information
#
# Table name: org_preferences
# Database name: org_setting
#
#  id                       :bigint           not null, primary key
#  dbsc_challenge           :text
#  dbsc_challenge_issued_at :datetime
#  dbsc_public_key          :jsonb
#  discard_at             :datetime         default(Infinity), not null
#  explicit_fields          :jsonb            not null
#  jti                      :string
#  purge_eligible_at                :datetime         default(Infinity), not null
#  token_digest             :binary
#  used_at                  :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  binding_method_id        :bigint           default(0), not null
#  dbsc_session_id          :string
#  dbsc_status_id           :bigint           default(0), not null
#  public_id                :string           not null
#  replaced_by_id           :bigint
#  status_id                :bigint           default(2), not null
#
# Indexes
#
#  index_org_preferences_on_binding_method_id  (binding_method_id)
#  index_org_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_org_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_org_preferences_on_jti                (jti) UNIQUE
#  index_org_preferences_on_public_id          (public_id) UNIQUE
#  index_org_preferences_on_purge_eligible_at          (purge_eligible_at)
#  index_org_preferences_on_replaced_by_id     (replaced_by_id)
#  index_org_preferences_on_status_id          (status_id)
#  index_org_preferences_on_token_digest       (token_digest)
#  index_org_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_org_preferences_on_binding_method_id  (binding_method_id => org_preference_binding_methods.id)
#  fk_org_preferences_on_dbsc_status_id     (dbsc_status_id => org_preference_dbsc_statuses.id)
#  fk_org_preferences_on_status_id          (status_id => org_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => org_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

require "test_helper"

class OrgPreferenceTest < ActiveSupport::TestCase
  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::NOTHING)
  end

  test "generates public_id on create" do
    preference = OrgPreference.create!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates public_id maximum length" do
    preference = OrgPreference.new(public_id: "a" * 22)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :too_long)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123"
    preference = OrgPreference.create!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one org_preference_cookie" do
    preference = OrgPreference.create!
    cookie = preference.create_org_preference_cookie!

    assert_equal cookie, preference.org_preference_cookie
  end

  test "destroys org_preference_cookie when destroyed" do
    preference = OrgPreference.create!
    cookie = preference.create_org_preference_cookie!
    cookie_id = cookie.id
    preference.destroy!

    assert_nil OrgPreferenceCookie.find_by(id: cookie_id)
  end

  test "has one org_preference_region" do
    preference = OrgPreference.create!
    region = preference.create_org_preference_region!

    assert_equal region, preference.org_preference_region
  end

  test "destroys org_preference_region when destroyed" do
    preference = OrgPreference.create!
    region = preference.create_org_preference_region!
    region_id = region.id
    preference.destroy!

    assert_nil OrgPreferenceRegion.find_by(id: region_id)
  end

  test "has one org_preference_timezone" do
    preference = OrgPreference.create!
    timezone = preference.create_org_preference_timezone!

    assert_equal timezone, preference.org_preference_timezone
  end

  test "destroys org_preference_timezone when destroyed" do
    preference = OrgPreference.create!
    timezone = preference.create_org_preference_timezone!
    timezone_id = timezone.id
    preference.destroy!

    assert_nil OrgPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one org_preference_language" do
    preference = OrgPreference.create!
    language = preference.create_org_preference_language!

    assert_equal language, preference.org_preference_language
  end

  test "destroys org_preference_language when destroyed" do
    preference = OrgPreference.create!
    language = preference.create_org_preference_language!
    language_id = language.id
    preference.destroy!

    assert_nil OrgPreferenceLanguage.find_by(id: language_id)
  end

  test "has one org_preference_theme" do
    preference = OrgPreference.create!
    theme = preference.create_org_preference_theme!

    assert_equal theme, preference.org_preference_theme
  end

  test "destroys org_preference_theme when destroyed" do
    preference = OrgPreference.create!
    theme = preference.create_org_preference_theme!
    theme_id = theme.id
    preference.destroy!

    assert_nil OrgPreferenceTheme.find_by(id: theme_id)
  end

  test "consume_once_by_digest! is replay-detectable" do
    digest = OrgPreference.digest_refresh_token("org-consume-once")
    preference = OrgPreference.create!(
      status_id: OrgPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    first = OrgPreference.consume_once_by_digest!(digest: digest)

    assert_equal preference.id, first.id
    assert_predicate first.used_at, :present?
    assert_nil OrgPreference.consume_once_by_digest!(digest: digest)
    assert_predicate preference.reload, :replay?
  end

  test "consume_once_by_digest! rejects revoked compromised and expired rows" do
    revoked = OrgPreference.create!(
      status_id: OrgPreferenceStatus::NOTHING,
      token_digest: OrgPreference.digest_refresh_token("org-revoked"),
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    compromised = OrgPreference.create!(
      status_id: OrgPreferenceStatus::NOTHING,
      token_digest: OrgPreference.digest_refresh_token("org-compromised"),
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    expired = OrgPreference.create!(
      status_id: OrgPreferenceStatus::NOTHING,
      discard_at: 1.minute.ago,
      token_digest: OrgPreference.digest_refresh_token("org-expired"),
      jti: SecureRandom.uuid,
    )

    assert_nil OrgPreference.consume_once_by_digest!(digest: revoked.token_digest)
    assert_nil OrgPreference.consume_once_by_digest!(digest: compromised.token_digest)
    assert_nil OrgPreference.consume_once_by_digest!(digest: expired.token_digest)
  end

  test "rotate! creates replacement row and replacement link" do
    digest = OrgPreference.digest_refresh_token("org-rotate")
    original = OrgPreference.create!(
      status_id: OrgPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    rotated = OrgPreference.rotate!(presented_digest: digest, now: Time.current)

    assert_predicate rotated, :present?
    assert_predicate rotated.issued_refresh_token, :present?
    assert_not_equal original.id, rotated.id
    assert_equal rotated.id, original.reload.replaced_by_id
  end

  test "adult_content_gate returns nothing when no gate is set" do
    assert_equal "nothing", OrgPreference.new.adult_content_gate
  end

  test "adult_content_gate returns the gate option name when a gate is set" do
    preference = OrgPreference.new
    preference.build_org_preference_adult_content_gate(
      option: OrgPreferenceAdultContentGateOption.new(id: OrgPreferenceAdultContentGateOption::APPROVED),
    )

    assert_equal "approved", preference.adult_content_gate
  end
end
