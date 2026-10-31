# frozen_string_literal: true
# typed: false

# == Schema Information
#
# Table name: com_preferences
# Database name: com_setting
#
#  id                       :bigint           not null, primary key
#  jti                      :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  public_id                :string           not null
#  status_id                :bigint           default(2), not null
#
# Indexes
#
#  index_com_preferences_on_jti                (jti) UNIQUE
#  index_com_preferences_on_public_id          (public_id) UNIQUE
#  index_com_preferences_on_status_id          (status_id)
#
# Foreign Keys
#
#  fk_com_preferences_on_status_id          (status_id => com_preference_statuses.id)
#

require "test_helper"

class ComPreferenceTest < ActiveSupport::TestCase
  test "issuance timestamps must be present before persistence" do
    preference = ComPreference.new(jti: SecureRandom.uuid)

    assert_not preference.valid?
    assert_includes preference.errors.attribute_names, :last_issued_at
    assert_includes preference.errors.attribute_names, :last_issued_expires_at

    preference.last_issued_at = Time.current
    preference.last_issued_expires_at = 400.days.from_now

    assert_predicate preference, :valid?
  end
  PREFERENCE_CHILD_ASSOCIATIONS = %i(com_preference_cookie com_preference_consent_receipt
                                     com_preference_web_push com_preference_browser_binding
                                     com_preference_region com_preference_timezone
                                     com_preference_language com_preference_theme com_preference_currency
                                     com_preference_date_format com_preference_time_format com_preference_motion
                                     com_preference_density com_preference_page_size com_preference_adult_content_gate
                                     com_preference_chronicles).freeze

  setup do
    ComPreferenceStatus.find_or_create_by!(id: ComPreferenceStatus::ACTIVE)
  end

  test "generates public_id on create" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )

    assert_not_nil preference.public_id
    assert_equal 21, preference.public_id.length
  end

  test "a preference requires a unique nonempty generation" do
    issued_at = Time.current
    attributes = { last_issued_at: issued_at, last_issued_expires_at: issued_at + 400.days }
    [nil, ""].each do |generation|
      preference = ComPreference.new(**attributes, jti: generation)

      assert_not preference.valid?
      assert preference.errors.of_kind?(:jti, :blank)
    end

    ComPreference.create!(**attributes, jti: "generation-used")
    duplicate = ComPreference.new(**attributes, jti: "generation-used")

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:jti, :taken)
  end

  test "database rejects missing and duplicate generations" do
    issued_at = Time.current
    first = ComPreference.create!(
      jti: "database-generation", last_issued_at: issued_at, last_issued_expires_at: issued_at + 400.days,
    )
    attributes = {
      public_id: PublicId.generate, last_issued_at: issued_at, last_issued_expires_at: issued_at + 400.days,
    }

    assert_raises(ActiveRecord::NotNullViolation) do
      ComPreference.transaction(requires_new: true) { ComPreference.insert_all!([attributes.merge(jti: nil)]) }
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      ComPreference.transaction(requires_new: true) { ComPreference.insert_all!([attributes.merge(jti: first.jti)]) }
    end
  end

  test "a preference with audit history cannot be destroyed" do
    preference = com_preferences(:one)
    audit = com_preference_chronicles(:one)

    assert_raises(ActiveRecord::DeleteRestrictionError) { preference.destroy! }
    assert_predicate ComPreference.where(id: preference.id), :exists?
    assert_predicate ComPreferenceChronicle.where(id: audit.id), :exists?
  end

  test "destroying a preference removes its receipt, web push and browser binding children" do
    ComPreferenceWebPushOption.ensure_defaults!
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    push = ComPreferenceWebPush.create!(preference: preference, option_id: ComPreferenceWebPushOption::DISABLED)
    binding = ComPreferenceBrowserBinding.create!(preference: preference, digest: "a" * 64)
    receipt = ComPreferenceConsentReceipt.create!(
      preference: preference, version: SecureRandom.uuid, recorded_at: Time.current,
    )
    loaded = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)

    loaded.destroy!

    assert_not ComPreferenceWebPush.exists?(push.id)
    assert_not ComPreferenceBrowserBinding.exists?(binding.id)
    assert_not ComPreferenceConsentReceipt.exists?(receipt.id)
  end

  test "validates the fixed public_id length" do
    preference = ComPreference.new(public_id: "a" * 26)

    assert_not preference.valid?
    assert preference.errors.of_kind?(:public_id, :wrong_length)
  end

  test "does not overwrite existing public_id" do
    custom_id = "custom_public_id_123x"
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      public_id: custom_id,
    )

    assert_equal custom_id, preference.public_id
  end

  test "has one com_preference_cookie" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    preference = ComPreference.includes(:com_preference_cookie).find(preference.id)
    cookie = preference.create_com_preference_cookie!

    loaded_preference = ComPreference.includes(:com_preference_cookie).find(preference.id)

    assert_equal cookie, loaded_preference.com_preference_cookie
  end

  test "destroys com_preference_cookie when destroyed" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    preference = ComPreference.includes(:com_preference_cookie).find(preference.id)
    cookie = preference.create_com_preference_cookie!
    cookie_id = cookie.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceCookie.find_by(id: cookie_id)
  end

  test "has one com_preference_region" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_region_options(:jp)
    preference = ComPreference.includes(:com_preference_region).find(preference.id)
    region = preference.create_com_preference_region!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_region).find(preference.id)

    assert_equal region, loaded_preference.com_preference_region
  end

  test "destroys com_preference_region when destroyed" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_region_options(:jp)
    preference = ComPreference.includes(:com_preference_region).find(preference.id)
    region = preference.create_com_preference_region!(option: option)
    region_id = region.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceRegion.find_by(id: region_id)
  end

  test "has one com_preference_timezone" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_timezone_options(:asia_tokyo)
    preference = ComPreference.includes(:com_preference_timezone).find(preference.id)
    timezone = preference.create_com_preference_timezone!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_timezone).find(preference.id)

    assert_equal timezone, loaded_preference.com_preference_timezone
  end

  test "destroys com_preference_timezone when destroyed" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_timezone_options(:asia_tokyo)
    preference = ComPreference.includes(:com_preference_timezone).find(preference.id)
    timezone = preference.create_com_preference_timezone!(option: option)
    timezone_id = timezone.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceTimezone.find_by(id: timezone_id)
  end

  test "has one com_preference_language" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_language_options(:ja)
    preference = ComPreference.includes(:com_preference_language).find(preference.id)
    language = preference.create_com_preference_language!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_language).find(preference.id)

    assert_equal language, loaded_preference.com_preference_language
  end

  test "destroys com_preference_language when destroyed" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_language_options(:ja)
    preference = ComPreference.includes(:com_preference_language).find(preference.id)
    language = preference.create_com_preference_language!(option: option)
    language_id = language.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceLanguage.find_by(id: language_id)
  end

  test "has one com_preference_theme" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_theme_options(:light)
    preference = ComPreference.includes(:com_preference_theme).find(preference.id)
    theme = preference.create_com_preference_theme!(option: option)

    loaded_preference = ComPreference.includes(:com_preference_theme).find(preference.id)

    assert_equal theme, loaded_preference.com_preference_theme
  end

  test "destroys com_preference_theme when destroyed" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
    )
    option = com_preference_theme_options(:light)
    preference = ComPreference.includes(:com_preference_theme).find(preference.id)
    theme = preference.create_com_preference_theme!(option: option)
    theme_id = theme.id
    preference = ComPreference.includes(PREFERENCE_CHILD_ASSOCIATIONS).find(preference.id)
    preference.destroy!

    assert_nil ComPreferenceTheme.find_by(id: theme_id)
  end

  test "com preference does not expose refresh token rotation" do
    assert_not_respond_to ComPreference, :rotate!
    assert_not_respond_to ComPreference, :consume_once_by_digest!
  end

  test "com preference does not expose DBSC binding transitions" do
    preference = ComPreference.new

    assert_not_respond_to preference, :dbsc_enabled?
    assert_not_respond_to preference, :dbsc_status_active?
  end

  test "adult_content_gate returns nothing when no gate is set" do
    assert_equal "nothing", ComPreference.new.adult_content_gate
  end

  test "retiring an active preference cannot retire it again" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      status_id: ComPreferenceStatus::ACTIVE,
    )

    preference.retire!

    assert_equal ComPreferenceStatus::RETIRED, preference.reload.status_id

    assert_raises(PreferenceLifecycle::InvalidTransition) { preference.retire! }
    assert_equal ComPreferenceStatus::RETIRED, preference.reload.status_id
  end

  test "preference status is limited to active and retired references" do
    attributes = {
      jti: SecureRandom.uuid, last_issued_at: Time.current, last_issued_expires_at: 400.days.from_now,
    }

    [nil, 0, 3].each do |status|
      preference = ComPreference.new(**attributes, status_id: status)

      assert_not preference.valid?
      assert preference.errors.of_kind?(:status_id, :inclusion)
    end
    [ComPreferenceStatus::RETIRED, ComPreferenceStatus::ACTIVE].each do |status|
      assert_predicate ComPreference.new(**attributes, status_id: status), :valid?
    end
  end

  test "the status reference rejects integer values outside the two-state boundary in SQL" do
    [0, 3].each do |status|
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          ComPreferenceStatus.transaction(requires_new: true) { ComPreferenceStatus.insert_all!([{ id: status }]) }
        end

      assert_equal "23514", error.cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
      assert_equal "chk_com_preference_statuses_id",
                   error.cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
  end

  test "a retired preference cannot be reactivated through model update" do
    preference = ComPreference.create!(
      jti: SecureRandom.uuid,
      last_issued_at: Time.current,
      last_issued_expires_at: 400.days.from_now,
      status_id: ComPreferenceStatus::ACTIVE,
    )
    preference.retire!

    assert_raises(ActiveRecord::RecordInvalid) { preference.update!(status_id: ComPreferenceStatus::ACTIVE) }
    assert_equal ComPreferenceStatus::RETIRED, preference.reload.status_id
  end

  test "issuance retention elapses at the last issued expiry plus thirty days" do
    issued_at = Time.current.change(usec: 0)
    expires_at = issued_at + 400.days
    preference = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: issued_at, last_issued_expires_at: expires_at,
    )
    deadline = expires_at + 30.days

    [ComPreferenceStatus::ACTIVE, ComPreferenceStatus::RETIRED].each do |status|
      preference.retire! if status == ComPreferenceStatus::RETIRED

      assert_equal status, preference.status_id
      assert_not preference.issuance_retention_elapsed?(now: deadline - 1.second)
      assert preference.issuance_retention_elapsed?(now: deadline)
      assert preference.issuance_retention_elapsed?(now: deadline + 1.second)
    end
    assert_raises(ArgumentError) { preference.issuance_retention_elapsed?(now: nil) }
  end

  test "issued preference is active strictly before its stored expiry" do
    issued_at = Time.current.change(usec: 0)
    expires_at = issued_at + 400.days
    preference = ComPreference.create!(
      jti: SecureRandom.uuid, last_issued_at: issued_at, last_issued_expires_at: expires_at,
    )

    assert preference.issuance_active_at?(now: expires_at - Rational(1, 1_000_000))
    assert_not preference.issuance_active_at?(now: expires_at)
    assert_not preference.issuance_active_at?(now: expires_at + Rational(1, 1_000_000))
    assert_raises(ArgumentError) { preference.issuance_active_at?(now: nil) }
    preference.retire!

    assert_not preference.issuance_active_at?(now: expires_at - Rational(1, 1_000_000))
  end

  test "adult_content_gate returns the gate option name when a gate is set" do
    preference = ComPreference.new
    preference.build_com_preference_adult_content_gate(
      option: ComPreferenceAdultContentGateOption.new(id: ComPreferenceAdultContentGateOption::APPROVED),
    )

    assert_equal "approved", preference.adult_content_gate
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ComPreference)
  end
end
