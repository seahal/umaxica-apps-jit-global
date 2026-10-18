# typed: false
# frozen_string_literal: true

require "openssl"
require "test_helper"

# The Warp chrome renders a theme control, so Warp has to persist the choice itself: without its
# own /api/v0/preferences/theme authority the PATCH 404s and the theme reverts on the next load.
class Warp::App::Api::V0::Preferences::ThemeControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1")

  setup do
    @host = ENV.fetch("PUBLIC_WARP_SERVICE_URL", "warp.app.localhost")
    host! @host
  end

  test "PATCH update persists the chosen theme and a follow-up GET reports it" do
    option_class = PreferenceClassRegistry.option_class("Client", :theme)
    option_class.ensure_defaults! if option_class.respond_to?(:ensure_defaults!)
    public_key_for = ->(_kid, **_options) { PREFERENCE_JWT_KEY }

    PreferenceJwtConfiguration.stub(:private_key, PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, public_key_for) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, [@host]) do
                  patch warp_app_api_v0_preferences_theme_path, params: { theme: "dark" }, as: :json

                  assert_response :ok
                  assert_equal "dr", response.parsed_body["theme"]

                  get warp_app_api_v0_preferences_theme_path, as: :json

                  assert_response :ok
                  assert_equal "dr", response.parsed_body["theme"]
                end
              end
            end
          end
        end
      end
    end
  end

  test "GET show without any preference state returns the system default" do
    get warp_app_api_v0_preferences_theme_path, as: :json

    assert_response :ok
    assert_equal "sy", response.parsed_body["theme"]
  end
end
