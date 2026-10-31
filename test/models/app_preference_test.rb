# frozen_string_literal: true
# typed: false

require "test_helper"

class AppPreferenceTest < ActiveSupport::TestCase
  PREFERENCE_CHILD_ASSOCIATIONS = %i(app_preference_cookie app_preference_region app_preference_timezone
                                     app_preference_language app_preference_theme app_preference_currency
                                     app_preference_date_format app_preference_time_format app_preference_motion
                                     app_preference_density app_preference_page_size app_preference_consent_receipt
                                     app_preference_browser_binding app_preference_web_push
                                     app_preference_adult_content_gate
                                     app_preference_chronicles replacements).freeze

  setup do
    AppPreferenceStatus.ensure_defaults!
  end

  test "generates public_id on create" do
    preference = create_preference!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates the fixed public_id length" do
    preference = AppPreference.new(public_id: "a" * 26)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :wrong_length)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123x"
    preference = create_preference!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one app_preference_cookie" do
    preference = create_preference!
    preference = AppPreference.includes(:app_preference_cookie).find(preference.id)
    cookie = preference.create_app_preference_cookie!

    loaded_preference = AppPreference.includes(:app_preference_cookie).find(preference.id)

    assert_equal cookie, loaded_preference.app_preference_cookie
  end

  test "destroys app_preference_cookie when destroyed" do
    preference = create_preference!
    preference = AppPreference.includes(:app_preference_cookie).find(preference.id)
    cookie = preference.create_app_preference_cookie!
    cookie_id = cookie.id
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil AppPreferenceCookie.find_by(id: cookie_id)
  end

  test "persists app browser binding consent receipt and Web Push option as preference children" do
    preference = create_preference!
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    AppPreferenceWebPushOption.ensure_defaults!

    web_push = preference.create_app_preference_web_push!
    binding = preference.create_app_preference_browser_binding!(digest: "a" * 64)
    receipt = preference.create_app_preference_consent_receipt!(
      version: SecureRandom.uuid, recorded_at: Time.current,
    )

    assert_equal AppPreferenceWebPushOption::DISABLED, web_push.option_id
    assert_equal "disabled", web_push.option.name
    assert_equal preference.id, binding.preference_id
    assert_equal "a" * 64, binding.digest
    assert_equal preference.id, receipt.preference_id
    assert_predicate receipt.version, :present?
    assert_predicate receipt.recorded_at, :present?

    web_push.update!(option_id: AppPreferenceWebPushOption::ENABLED)

    assert_equal "enabled", web_push.reload.option.name
  end

  test "destroys app supplemental children with their preference" do
    preference = create_preference!
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    AppPreferenceWebPushOption.ensure_defaults!
    binding = preference.create_app_preference_browser_binding!(digest: "b" * 64)
    receipt = preference.create_app_preference_consent_receipt!(
      version: SecureRandom.uuid, recorded_at: Time.current,
    )
    web_push = preference.create_app_preference_web_push!
    child_ids = [binding.id, receipt.id, web_push.id]

    AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id).destroy!

    assert_nil AppPreferenceBrowserBinding.find_by(id: child_ids.fetch(0))
    assert_nil AppPreferenceConsentReceipt.find_by(id: child_ids.fetch(1))
    assert_nil AppPreferenceWebPush.find_by(id: child_ids.fetch(2))
  end

  test "rejects malformed app browser binding digests and unsupported Web Push options" do
    preference = create_preference!

    binding = AppPreferenceBrowserBinding.new(preference:, digest: "A" * 64)
    web_push = AppPreferenceWebPush.new(preference:, option_id: 2)

    assert_not_predicate binding, :valid?
    assert_not_predicate web_push, :valid?
  end

  test "has one app_preference_region" do
    preference = create_preference!
    option = app_preference_region_options(:jp)
    preference = AppPreference.includes(:app_preference_region).find(preference.id)
    region = preference.create_app_preference_region!(option: option)

    loaded_preference = AppPreference.includes(:app_preference_region).find(preference.id)

    assert_equal region, loaded_preference.app_preference_region
  end

  test "destroys app_preference_region when destroyed" do
    preference = create_preference!
    option = app_preference_region_options(:jp)
    preference = AppPreference.includes(:app_preference_region).find(preference.id)
    region = preference.create_app_preference_region!(option: option)
    region_id = region.id
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil AppPreferenceRegion.find_by(id: region_id)
  end

  test "has one app_preference_timezone" do
    preference = create_preference!
    option = app_preference_timezone_options(:asia_tokyo)
    preference = AppPreference.includes(:app_preference_timezone).find(preference.id)
    timezone = preference.create_app_preference_timezone!(option: option)

    loaded_preference = AppPreference.includes(:app_preference_timezone).find(preference.id)

    assert_equal timezone, loaded_preference.app_preference_timezone
  end

  test "destroys app_preference_timezone when destroyed" do
    preference = create_preference!
    option = app_preference_timezone_options(:asia_tokyo)
    preference = AppPreference.includes(:app_preference_timezone).find(preference.id)
    timezone = preference.create_app_preference_timezone!(option: option)
    timezone_id = timezone.id
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil AppPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one app_preference_language" do
    preference = create_preference!
    option = app_preference_language_options(:ja)
    preference = AppPreference.includes(:app_preference_language).find(preference.id)
    language = preference.create_app_preference_language!(option: option)

    loaded_preference = AppPreference.includes(:app_preference_language).find(preference.id)

    assert_equal language, loaded_preference.app_preference_language
  end

  test "destroys app_preference_language when destroyed" do
    preference = create_preference!
    option = app_preference_language_options(:ja)
    preference = AppPreference.includes(:app_preference_language).find(preference.id)
    language = preference.create_app_preference_language!(option: option)
    language_id = language.id
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil AppPreferenceLanguage.find_by(id: language_id)
  end

  test "has one app_preference_theme" do
    preference = create_preference!
    option = app_preference_theme_options(:light)
    preference = AppPreference.includes(:app_preference_theme).find(preference.id)
    theme = preference.create_app_preference_theme!(option: option)

    loaded_preference = AppPreference.includes(:app_preference_theme).find(preference.id)

    assert_equal theme, loaded_preference.app_preference_theme
  end

  test "destroys app_preference_theme when destroyed" do
    preference = create_preference!
    option = app_preference_theme_options(:light)
    preference = AppPreference.includes(:app_preference_theme).find(preference.id)
    theme = preference.create_app_preference_theme!(option: option)
    theme_id = theme.id
    preference = AppPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil AppPreferenceTheme.find_by(id: theme_id)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::AppPreference)
  end

  private

  def create_preference!(**attributes)
    now = Time.current
    AppPreference.create!(
      { jti: SecureRandom.uuid, last_issued_at: now, last_issued_expires_at: now + 400.days }.merge(attributes),
    )
  end
end
