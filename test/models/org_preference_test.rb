# frozen_string_literal: true
# typed: false

require "test_helper"

class OrgPreferenceTest < ActiveSupport::TestCase
  PREFERENCE_CHILD_ASSOCIATIONS = %i(org_preference_cookie org_preference_region org_preference_timezone
                                     org_preference_language org_preference_theme org_preference_currency
                                     org_preference_date_format org_preference_time_format org_preference_motion
                                     org_preference_density org_preference_page_size org_preference_consent_receipt
                                     org_preference_browser_binding org_preference_web_push
                                     org_preference_adult_content_gate
                                     org_preference_chronicles).freeze

  setup do
    OrgPreferenceStatus.find_or_create_by!(id: OrgPreferenceStatus::ACTIVE)
  end

  test "generates public_id on create" do
    preference = create_preference!

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "validates the fixed public_id length" do
    preference = OrgPreference.new(public_id: "a" * 26)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :wrong_length)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123x"
    preference = create_preference!(public_id: custom_id)

    assert_equal custom_id, preference.public_id
  end

  test "has one org_preference_cookie" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_cookie).find(preference.id)
    cookie = preference.create_org_preference_cookie!

    loaded_preference = OrgPreference.includes(:org_preference_cookie).find(preference.id)

    assert_equal cookie, loaded_preference.org_preference_cookie
  end

  test "destroys org_preference_cookie when destroyed" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_cookie).find(preference.id)
    cookie = preference.create_org_preference_cookie!
    cookie_id = cookie.id
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil OrgPreferenceCookie.find_by(id: cookie_id)
  end

  test "persists org browser binding consent receipt and Web Push option as preference children" do
    preference = create_preference!
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    OrgPreferenceWebPushOption.ensure_defaults!

    web_push = preference.create_org_preference_web_push!
    binding = preference.create_org_preference_browser_binding!(digest: "a" * 64)
    receipt = preference.create_org_preference_consent_receipt!(
      version: SecureRandom.uuid, recorded_at: Time.current,
    )

    assert_equal OrgPreferenceWebPushOption::DISABLED, web_push.option_id
    assert_equal "disabled", web_push.option.name
    assert_equal preference.id, binding.preference_id
    assert_equal "a" * 64, binding.digest
    assert_equal preference.id, receipt.preference_id
    assert_predicate receipt.version, :present?
    assert_predicate receipt.recorded_at, :present?

    web_push.update!(option_id: OrgPreferenceWebPushOption::ENABLED)

    assert_equal "enabled", web_push.reload.option.name
  end

  test "destroys org supplemental children with their preference" do
    preference = create_preference!
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    OrgPreferenceWebPushOption.ensure_defaults!
    binding = preference.create_org_preference_browser_binding!(digest: "b" * 64)
    receipt = preference.create_org_preference_consent_receipt!(
      version: SecureRandom.uuid, recorded_at: Time.current,
    )
    web_push = preference.create_org_preference_web_push!
    child_ids = [binding.id, receipt.id, web_push.id]

    OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id).destroy!

    assert_nil OrgPreferenceBrowserBinding.find_by(id: child_ids.fetch(0))
    assert_nil OrgPreferenceConsentReceipt.find_by(id: child_ids.fetch(1))
    assert_nil OrgPreferenceWebPush.find_by(id: child_ids.fetch(2))
  end

  test "rejects malformed org browser binding digests and unsupported Web Push options" do
    preference = create_preference!

    binding = OrgPreferenceBrowserBinding.new(preference:, digest: "A" * 64)
    web_push = OrgPreferenceWebPush.new(preference:, option_id: 2)

    assert_not_predicate binding, :valid?
    assert_not_predicate web_push, :valid?
  end

  test "has one org_preference_region" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_region).find(preference.id)
    region = preference.create_org_preference_region!

    loaded_preference = OrgPreference.includes(:org_preference_region).find(preference.id)

    assert_equal region, loaded_preference.org_preference_region
  end

  test "destroys org_preference_region when destroyed" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_region).find(preference.id)
    region = preference.create_org_preference_region!
    region_id = region.id
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil OrgPreferenceRegion.find_by(id: region_id)
  end

  test "has one org_preference_timezone" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_timezone).find(preference.id)
    timezone = preference.create_org_preference_timezone!

    loaded_preference = OrgPreference.includes(:org_preference_timezone).find(preference.id)

    assert_equal timezone, loaded_preference.org_preference_timezone
  end

  test "destroys org_preference_timezone when destroyed" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_timezone).find(preference.id)
    timezone = preference.create_org_preference_timezone!
    timezone_id = timezone.id
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil OrgPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one org_preference_language" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_language).find(preference.id)
    language = preference.create_org_preference_language!

    loaded_preference = OrgPreference.includes(:org_preference_language).find(preference.id)

    assert_equal language, loaded_preference.org_preference_language
  end

  test "destroys org_preference_language when destroyed" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_language).find(preference.id)
    language = preference.create_org_preference_language!
    language_id = language.id
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil OrgPreferenceLanguage.find_by(id: language_id)
  end

  test "has one org_preference_theme" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_theme).find(preference.id)
    theme = preference.create_org_preference_theme!

    loaded_preference = OrgPreference.includes(:org_preference_theme).find(preference.id)

    assert_equal theme, loaded_preference.org_preference_theme
  end

  test "destroys org_preference_theme when destroyed" do
    preference = create_preference!
    preference = OrgPreference.includes(:org_preference_theme).find(preference.id)
    theme = preference.create_org_preference_theme!
    theme_id = theme.id
    preference = OrgPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil OrgPreferenceTheme.find_by(id: theme_id)
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OrgPreference)
  end

  private

  def create_preference!(**attributes)
    now = Time.current
    OrgPreference.create!(
      { jti: SecureRandom.uuid, last_issued_at: now, last_issued_expires_at: now + 400.days }.merge(attributes),
    )
  end
end
