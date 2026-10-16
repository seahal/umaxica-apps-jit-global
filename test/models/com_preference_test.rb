# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preferences
# Database name: com_setting
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
#  index_com_preferences_on_binding_method_id  (binding_method_id)
#  index_com_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_com_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_com_preferences_on_jti                (jti) UNIQUE
#  index_com_preferences_on_public_id          (public_id) UNIQUE
#  index_com_preferences_on_purge_eligible_at          (purge_eligible_at)
#  index_com_preferences_on_replaced_by_id     (replaced_by_id)
#  index_com_preferences_on_status_id          (status_id)
#  index_com_preferences_on_token_digest       (token_digest)
#  index_com_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_com_preferences_on_binding_method_id  (binding_method_id => com_preference_binding_methods.id)
#  fk_com_preferences_on_dbsc_status_id     (dbsc_status_id => com_preference_dbsc_statuses.id)
#  fk_com_preferences_on_status_id          (status_id => com_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => com_preferences.id) ON DELETE => nullify
#

require "test_helper"

class ComPreferenceTest < ActiveSupport::TestCase
  PREFERENCE_CHILD_ASSOCIATIONS = %i(com_preference_cookie com_preference_region com_preference_timezone
                                     com_preference_language com_preference_theme com_preference_currency
                                     com_preference_date_format com_preference_time_format com_preference_motion
                                     com_preference_density com_preference_page_size com_preference_adult_content_gate
                                     com_preference_chronicles replacements).freeze

  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::NOTHING)
  end

  test "generates public_id on create" do
    preference = ComPreference.create!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates public_id maximum length" do
    preference = ComPreference.new(public_id: "a" * 26)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :too_long)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123"
    preference = ComPreference.create!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one com_preference_cookie" do
    preference = ComPreference.create!
    preference = ComPreference.includes(:com_preference_cookie).find(preference.id)
    cookie = preference.create_com_preference_cookie!

    loaded_preference = ComPreference.includes(:com_preference_cookie).find(preference.id)

    assert_equal cookie, loaded_preference.com_preference_cookie
  end

  test "destroys com_preference_cookie when destroyed" do
    preference = ComPreference.create!
    preference = ComPreference.includes(:com_preference_cookie).find(preference.id)
    cookie = preference.create_com_preference_cookie!
    cookie_id = cookie.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceCookie.find_by(id: cookie_id)
  end

  test "has one com_preference_region" do
    preference = ComPreference.create!
    option = com_preference_region_options(:jp)
    preference = ComPreference.includes(:com_preference_region).find(preference.id)
    region = preference.create_com_preference_region!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_region).find(preference.id)

    assert_equal region, loaded_preference.com_preference_region
  end

  test "destroys com_preference_region when destroyed" do
    preference = ComPreference.create!
    option = com_preference_region_options(:jp)
    preference = ComPreference.includes(:com_preference_region).find(preference.id)
    region = preference.create_com_preference_region!(option: option)
    region_id = region.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceRegion.find_by(id: region_id)
  end

  test "has one com_preference_timezone" do
    preference = ComPreference.create!
    option = com_preference_timezone_options(:asia_tokyo)
    preference = ComPreference.includes(:com_preference_timezone).find(preference.id)
    timezone = preference.create_com_preference_timezone!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_timezone).find(preference.id)

    assert_equal timezone, loaded_preference.com_preference_timezone
  end

  test "destroys com_preference_timezone when destroyed" do
    preference = ComPreference.create!
    option = com_preference_timezone_options(:asia_tokyo)
    preference = ComPreference.includes(:com_preference_timezone).find(preference.id)
    timezone = preference.create_com_preference_timezone!(option: option)
    timezone_id = timezone.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one com_preference_language" do
    preference = ComPreference.create!
    option = com_preference_language_options(:ja)
    preference = ComPreference.includes(:com_preference_language).find(preference.id)
    language = preference.create_com_preference_language!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_language).find(preference.id)

    assert_equal language, loaded_preference.com_preference_language
  end

  test "destroys com_preference_language when destroyed" do
    preference = ComPreference.create!
    option = com_preference_language_options(:ja)
    preference = ComPreference.includes(:com_preference_language).find(preference.id)
    language = preference.create_com_preference_language!(option: option)
    language_id = language.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceLanguage.find_by(id: language_id)
  end

  test "has one com_preference_theme" do
    preference = ComPreference.create!
    option = com_preference_theme_options(:light)
    preference = ComPreference.includes(:com_preference_theme).find(preference.id)
    theme = preference.create_com_preference_theme!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_theme).find(preference.id)

    assert_equal theme, loaded_preference.com_preference_theme
  end

  test "destroys com_preference_theme when destroyed" do
    preference = ComPreference.create!
    option = com_preference_theme_options(:light)
    preference = ComPreference.includes(:com_preference_theme).find(preference.id)
    theme = preference.create_com_preference_theme!(option: option)
    theme_id = theme.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceTheme.find_by(id: theme_id)
  end

  test "consume_once_by_digest! is replay-detectable" do
    digest = ComPreference.digest_refresh_token("com-consume-once")
    preference = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    first = ComPreference.consume_once_by_digest!(digest: digest)

    assert_equal preference.id, first.id
    assert_predicate first.used_at, :present?
    assert_nil ComPreference.consume_once_by_digest!(digest: digest)
    assert_predicate preference.reload, :replay?
  end

  test "consume_once_by_digest! rejects revoked compromised and expired rows" do
    revoked = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      token_digest: ComPreference.digest_refresh_token("com-revoked"),
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    compromised = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      token_digest: ComPreference.digest_refresh_token("com-compromised"),
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    expired = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      discard_at: 1.minute.ago,
      token_digest: ComPreference.digest_refresh_token("com-expired"),
      jti: SecureRandom.uuid,
    )

    assert_nil ComPreference.consume_once_by_digest!(digest: revoked.token_digest)
    assert_nil ComPreference.consume_once_by_digest!(digest: compromised.token_digest)
    assert_nil ComPreference.consume_once_by_digest!(digest: expired.token_digest)
  end

  test "rotate! creates replacement row and replacement link" do
    digest = ComPreference.digest_refresh_token("com-rotate")
    original = ComPreference.create!(
      status_id: ComPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    rotated = ComPreference.rotate!(presented_digest: digest, now: Time.current)

    assert_predicate rotated, :present?
    assert_predicate rotated.issued_refresh_token, :present?
    assert_not_equal original.id, rotated.id
    assert_equal rotated.id, original.reload.replaced_by_id
  end

  test "adult_content_gate returns nothing when no gate is set" do
    assert_equal "nothing", ComPreference.new.adult_content_gate
  end

  test "adult_content_gate returns the gate option name when a gate is set" do
    preference = ComPreference.new
    preference.build_com_preference_adult_content_gate(
      option: ComPreferenceAdultContentGateOption.new(id: ComPreferenceAdultContentGateOption::APPROVED),
    )

    assert_equal "approved", preference.adult_content_gate
  end
end
