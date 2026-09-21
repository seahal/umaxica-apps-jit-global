# typed: false
# == Schema Information
#
# Table name: app_preferences
# Database name: app_setting
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
#  status_id                :bigint           default(0), not null
#
# Indexes
#
#  index_app_preferences_on_binding_method_id  (binding_method_id)
#  index_app_preferences_on_dbsc_session_id    (dbsc_session_id) UNIQUE
#  index_app_preferences_on_dbsc_status_id     (dbsc_status_id)
#  index_app_preferences_on_jti                (jti) UNIQUE
#  index_app_preferences_on_public_id          (public_id) UNIQUE
#  index_app_preferences_on_purge_eligible_at          (purge_eligible_at)
#  index_app_preferences_on_replaced_by_id     (replaced_by_id)
#  index_app_preferences_on_status_id          (status_id)
#  index_app_preferences_on_token_digest       (token_digest)
#  index_app_preferences_on_used_at            (used_at)
#
# Foreign Keys
#
#  fk_app_preferences_on_binding_method_id  (binding_method_id => app_preference_binding_methods.id)
#  fk_app_preferences_on_dbsc_status_id     (dbsc_status_id => app_preference_dbsc_statuses.id)
#  fk_app_preferences_on_status_id          (status_id => app_preference_statuses.id)
#  fk_rails_...                             (replaced_by_id => app_preferences.id) ON DELETE => nullify
#

# frozen_string_literal: true

require "test_helper"

class AppPreferenceTest < ActiveSupport::TestCase
  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "generates public_id on create" do
    preference = AppPreference.create!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates public_id maximum length" do
    preference = AppPreference.new(public_id: "a" * 22)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :too_long)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123"
    preference = AppPreference.create!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one app_preference_cookie" do
    preference = AppPreference.create!
    cookie = preference.create_app_preference_cookie!

    assert_equal cookie, preference.app_preference_cookie
  end

  test "destroys app_preference_cookie when destroyed" do
    preference = AppPreference.create!
    cookie = preference.create_app_preference_cookie!
    cookie_id = cookie.id
    preference.destroy!

    assert_nil AppPreferenceCookie.find_by(id: cookie_id)
  end

  test "has one app_preference_region" do
    preference = AppPreference.create!
    option = app_preference_region_options(:jp)
    region = preference.create_app_preference_region!(option: option)

    assert_equal region, preference.app_preference_region
  end

  test "destroys app_preference_region when destroyed" do
    preference = AppPreference.create!
    option = app_preference_region_options(:jp)
    region = preference.create_app_preference_region!(option: option)
    region_id = region.id
    preference.destroy!

    assert_nil AppPreferenceRegion.find_by(id: region_id)
  end

  test "has one app_preference_timezone" do
    preference = AppPreference.create!
    option = app_preference_timezone_options(:asia_tokyo)
    timezone = preference.create_app_preference_timezone!(option: option)

    assert_equal timezone, preference.app_preference_timezone
  end

  test "destroys app_preference_timezone when destroyed" do
    preference = AppPreference.create!
    option = app_preference_timezone_options(:asia_tokyo)
    timezone = preference.create_app_preference_timezone!(option: option)
    timezone_id = timezone.id
    preference.destroy!

    assert_nil AppPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one app_preference_language" do
    preference = AppPreference.create!
    option = app_preference_language_options(:ja)
    language = preference.create_app_preference_language!(option: option)

    assert_equal language, preference.app_preference_language
  end

  test "destroys app_preference_language when destroyed" do
    preference = AppPreference.create!
    option = app_preference_language_options(:ja)
    language = preference.create_app_preference_language!(option: option)
    language_id = language.id
    preference.destroy!

    assert_nil AppPreferenceLanguage.find_by(id: language_id)
  end

  test "has one app_preference_theme" do
    preference = AppPreference.create!
    option = app_preference_theme_options(:light)
    theme = preference.create_app_preference_theme!(option: option)

    assert_equal theme, preference.app_preference_theme
  end

  test "destroys app_preference_theme when destroyed" do
    preference = AppPreference.create!
    option = app_preference_theme_options(:light)
    theme = preference.create_app_preference_theme!(option: option)
    theme_id = theme.id
    preference.destroy!

    assert_nil AppPreferenceTheme.find_by(id: theme_id)
  end

  test "consume_once_by_digest! marks token used only once" do
    digest = AppPreference.digest_refresh_token("app-consume-once")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    consumed = AppPreference.consume_once_by_digest!(digest: digest)

    assert_equal preference.id, consumed.id
    assert_predicate consumed.used_at, :present?

    second = AppPreference.consume_once_by_digest!(digest: digest)

    assert_nil second
    assert_predicate preference.reload, :replay?
  end

  test "consume_once_by_digest! rejects revoked compromised and expired rows" do
    revoked_digest = AppPreference.digest_refresh_token("revoked")
    compromised_digest = AppPreference.digest_refresh_token("compromised")
    expired_digest = AppPreference.digest_refresh_token("expired")

    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      token_digest: revoked_digest,
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      token_digest: compromised_digest,
      discard_at: Time.current,
      jti: SecureRandom.uuid,
    )
    AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.minute.ago,
      token_digest: expired_digest,
      jti: SecureRandom.uuid,
    )

    assert_nil AppPreference.consume_once_by_digest!(digest: revoked_digest)
    assert_nil AppPreference.consume_once_by_digest!(digest: compromised_digest)
    assert_nil AppPreference.consume_once_by_digest!(digest: expired_digest)
  end

  test "revoked? reflects revoked and compromised timestamps" do
    preference = AppPreference.new

    assert_not preference.revoked?

    preference.discard_at = Time.current

    assert_predicate preference, :revoked?
  end

  test "rotated_within_grace? is true for a just-consumed token with a replacement" do
    replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discard_at: 1.day.from_now)
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      used_at: Time.current,
      replaced_by_id: replacement.id,
    )

    assert_predicate preference, :rotated_within_grace?
  end

  test "rotated_within_grace? honors the window boundary" do
    now = Time.current
    replacement = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING, discard_at: 1.day.from_now)
    window = SingleUseToken::PREFERENCE_REFRESH_GRACE_WINDOW
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      replaced_by_id: replacement.id,
    )

    # Just inside the window it is a benign concurrent sibling.
    preference.update!(used_at: now - window + 1.second)

    assert preference.rotated_within_grace?(window: window, now: now)

    # Just past the window it is a genuine replay, not grace.
    preference.update!(used_at: now - window - 1.second)

    assert_not preference.rotated_within_grace?(window: window, now: now)
  end

  test "rotated_within_grace? is false for self-replacement or without consumption" do
    # Self-replacement (the create-time default) is not a real rotation even if
    # the row is somehow marked consumed.
    self_replaced = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      used_at: Time.current,
    )
    not_consumed = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      replaced_by_id: self_replaced.id,
    )

    assert_equal self_replaced.id, self_replaced.replaced_by_id, "default replaced_by points at self"
    assert_not self_replaced.rotated_within_grace?
    assert_not not_consumed.rotated_within_grace?
  end

  test "rotate! produces a parent that qualifies for the concurrency grace window" do
    digest = AppPreference.digest_refresh_token("rotate-grace")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    rotated = AppPreference.rotate!(presented_digest: digest, now: Time.current)
    preference.reload

    assert_predicate preference, :replay?
    assert_predicate preference, :rotated_within_grace?
    assert_equal rotated.id, preference.replaced_by_id
    assert_not_predicate rotated, :replay?, "replacement must remain unconsumed for sibling requests"
  end

  test "rotate! creates replacement and links replaced_by_id" do
    digest = AppPreference.digest_refresh_token("rotate-me")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    rotated = AppPreference.rotate!(presented_digest: digest, now: Time.current)

    assert_predicate rotated, :present?
    assert_predicate rotated.issued_refresh_token, :present?
    assert_not_equal preference.id, rotated.id
    assert_equal preference.status_id, rotated.status_id
    assert_predicate rotated.token_digest, :present?
    assert_equal rotated.id, preference.reload.replaced_by_id
  end

  test "rotate! moves all preference child records to replacement" do
    [
      AppPreferenceRegionOption,
      AppPreferenceTimezoneOption,
      AppPreferenceLanguageOption,
      AppPreferenceThemeOption,
      AppPreferenceCurrencyOption,
      AppPreferenceDateFormatOption,
      AppPreferenceTimeFormatOption,
      AppPreferenceMotionOption,
      AppPreferenceDensityOption,
      AppPreferencePageSizeOption,
      AppPreferenceAdultContentGateOption,
    ].each(&:ensure_defaults!)

    digest = AppPreference.digest_refresh_token("rotate-with-children")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    child_records =
      {
        app_preference_cookie: preference.create_app_preference_cookie!(functional: true),
        app_preference_region: preference.create_app_preference_region!(option_id: AppPreferenceRegionOption::JP),
        app_preference_timezone: preference.create_app_preference_timezone!(option_id: AppPreferenceTimezoneOption::ASIA_TOKYO),
        app_preference_language: preference.create_app_preference_language!(option_id: AppPreferenceLanguageOption::JA),
        app_preference_theme: preference.create_app_preference_theme!(option_id: AppPreferenceThemeOption::DARK),
        app_preference_currency: preference.create_app_preference_currency!(option_id: AppPreferenceCurrencyOption::JPY),
        app_preference_date_format: preference.create_app_preference_date_format!(option_id: AppPreferenceDateFormatOption::ISO),
        app_preference_time_format: preference.create_app_preference_time_format!(option_id: AppPreferenceTimeFormatOption::HOUR_24),
        app_preference_motion: preference.create_app_preference_motion!(option_id: AppPreferenceMotionOption::STANDARD),
        app_preference_density: preference.create_app_preference_density!(option_id: AppPreferenceDensityOption::STANDARD),
        app_preference_page_size: preference.create_app_preference_page_size!(option_id: AppPreferencePageSizeOption::PER_20),
        app_preference_adult_content_gate: preference.create_app_preference_adult_content_gate!(
          option_id: AppPreferenceAdultContentGateOption::NOTHING,
        ),
      }

    rotated = AppPreference.rotate!(presented_digest: digest, now: Time.current)

    child_records.each do |association_name, child|
      assert_equal rotated.id, child.reload.preference_id, "#{association_name} should move to replacement"
      assert_equal child.id, rotated.reload.public_send(association_name).id
    end
    assert_equal rotated.id, preference.reload.replaced_by_id
  end

  test "rotate! consumes token without device fallback" do
    digest = AppPreference.digest_refresh_token("rotate-wrong-device")
    preference = AppPreference.create!(
      status_id: AppPreferenceStatus::NOTHING,
      discard_at: 1.day.from_now,
      token_digest: digest,
      jti: SecureRandom.uuid,
    )

    rotated = AppPreference.rotate!(presented_digest: digest, now: Time.current)

    assert_predicate rotated, :present?
    preference.reload

    assert_predicate preference.used_at, :present?
    assert_equal rotated.id, preference.replaced_by_id
  end
end
