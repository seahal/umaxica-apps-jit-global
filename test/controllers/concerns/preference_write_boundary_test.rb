# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWriteBoundaryTest < ActiveSupport::TestCase
  REALM_MODELS = {
    com: ComPreference,
    app: AppPreference,
    org: OrgPreference,
  }.freeze

  test "accepts the closed operation set on the owning surface" do
    {
      "base/com" => :com, "base/app" => :app, "base/org" => :org,
    }.each do |surface_key, realm|
      result = PreferenceWriteBoundary.authorize!(
        surface_key: surface_key, operation: :save, realm_model: REALM_MODELS.fetch(realm),
      )

      assert_equal realm, result[:realm]
      assert_equal :save, result[:operation]
    end
  end

  test "wires the Visa sign_in and sign_out operations for realms that own a Visa read" do
    result = PreferenceWriteBoundary.authorize!(
      surface_key: "visa/app", operation: :sign_in, realm_model: "AppPreference",
    )

    assert_equal [:app, :sign_in], result.values_at(:realm, :operation)

    result = PreferenceWriteBoundary.authorize!(
      surface_key: "visa/org", operation: :sign_out, realm_model: "OrgPreference",
    )

    assert_equal [:org, :sign_out], result.values_at(:realm, :operation)
  end

  test "refuses an operation outside the closed enumeration" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :purge, realm_model: ComPreference,
        )
      end

    assert_match(/unsupported preference operation/, error.message)
  end

  test "refuses a sign-in write pointed at the com realm" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :sign_in, realm_model: ComPreference,
        )
      end

    assert_match(/may not use operation :sign_in/, error.message)
  end

  test "refuses an unlisted surface entirely" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "core/org", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_equal "core/org", error.message
  end

  test "refuses a surface that names another realm's model class" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "base/com", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_match(/may not write/, error.message)
  end

  test "refuses a lookalike model name and a missing model" do
    ["Other::ComPreference", "ComPreferencePreference", "", nil].each do |model|
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(surface_key: "base/com", operation: :save, realm_model: model)
      end
    end
  end

  test "static Base writer authorization covers only declared realm update and reset callers" do
    {
      "base/com" => [
        Base::Com::Api::V0::Preferences::CookiesController,
        Base::Com::Api::V0::Preferences::ThemesController,
        Base::Com::Api::V0::Preferences::WebPushesController,
        Base::Com::Preference::CookiesController,
        Base::Com::Preference::ThemesController,
        Base::Com::Preference::CurrenciesController,
        Base::Com::Preference::CalendarsController,
        Base::Com::Preference::ClocksController,
        Base::Com::Preference::MotionsController,
        Base::Com::Preference::DensitiesController,
        Base::Com::Preference::PaginationsController,
        Base::Com::Preference::LanguagesController,
        Base::Com::Preference::TimezonesController,
        Base::Com::Preference::RegionsController,
        Base::Com::Preference::ScreensController,
      ],
      "base/app" => [
        Base::App::Api::V0::Preferences::CookiesController,
        Base::App::Api::V0::Preferences::ThemesController,
        Base::App::Preference::CookiesController,
        Base::App::Preference::ThemesController,
        Base::App::Preference::CurrenciesController,
        Base::App::Preference::CalendarsController,
        Base::App::Preference::ClocksController,
        Base::App::Preference::MotionsController,
        Base::App::Preference::DensitiesController,
        Base::App::Preference::PaginationsController,
        Base::App::Preference::LanguagesController,
        Base::App::Preference::TimezonesController,
        Base::App::Preference::RegionsController,
        Base::App::Preference::ScreensController,
      ],
      "base/org" => [
        Base::Org::Api::V0::Preferences::CookiesController,
        Base::Org::Api::V0::Preferences::ThemesController,
        Base::Org::Preference::CookiesController,
        Base::Org::Preference::ThemesController,
        Base::Org::Preference::CurrenciesController,
        Base::Org::Preference::CalendarsController,
        Base::Org::Preference::ClocksController,
        Base::Org::Preference::MotionsController,
        Base::Org::Preference::DensitiesController,
        Base::Org::Preference::PaginationsController,
        Base::Org::Preference::LanguagesController,
        Base::Org::Preference::TimezonesController,
        Base::Org::Preference::RegionsController,
        Base::Org::Preference::ScreensController,
      ],
    }.each do |surface_key, controllers|
      realm = surface_key.split("/").last.to_sym
      controllers.each do |controller|
        result = PreferenceWriteBoundary.authorize_writer!(
          controller:, action: "update", surface_key:, operation: :save,
          realm_model: REALM_MODELS.fetch(realm),
        )

        assert_equal [realm, :save], result.values_at(:realm, :operation)
      end

      reset_controller =
        case realm
        when :com then Base::Com::Preference::CustomizationsController
        when :app then Base::App::Preference::CustomizationsController
        when :org then Base::Org::Preference::CustomizationsController
        end
      result = PreferenceWriteBoundary.authorize_writer!(
        controller: reset_controller, action: "destroy", surface_key:, operation: :reset,
        realm_model: REALM_MODELS.fetch(realm),
      )

      assert_equal [realm, :reset], result.values_at(:realm, :operation)
    end
  end

  test "static Visa writer authorization is limited to verified results and committed logout confirmations" do
    {
      ["visa/app", :sign_in, AppPreference] => Visa::App::Oauth::AuthorizationsController,
      ["visa/app", :sign_out, AppPreference] => Visa::App::Oidc::Logouts::ConfirmationsController,
      ["visa/org", :sign_in, OrgPreference] => Visa::Org::Oauth::AuthorizationsController,
      ["visa/org", :sign_out, OrgPreference] => Visa::Org::Oidc::Logouts::ConfirmationsController,
    }.each do |(surface_key, operation, realm_model), controller|
      result = PreferenceWriteBoundary.authorize_writer!(
        controller:, action: "create", surface_key:, operation:, realm_model:,
      )

      expected_realm = (realm_model == AppPreference) ? :app : :org

      assert_equal [expected_realm, operation], result.values_at(:realm, :operation)
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Visa::App::Oauth::AuthorizationsController, action: "show", surface_key: "visa/app",
        operation: :sign_in, realm_model: AppPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Visa::App::Oidc::LogoutsController, action: "create", surface_key: "visa/app",
        operation: :sign_out, realm_model: AppPreference,
      )
    end
  end

  test "static writer authorization refuses cross-realm and non-preference callers" do
    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::Preference::CookiesController, action: "update", surface_key: "base/org",
        operation: :save, realm_model: OrgPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::RootsController, action: "update", surface_key: "base/app",
        operation: :save, realm_model: AppPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Base::App::Preference::CookiesController, action: "update", surface_key: "base/app",
        operation: :sign_in, realm_model: AppPreference,
      )
    end
  end
end
