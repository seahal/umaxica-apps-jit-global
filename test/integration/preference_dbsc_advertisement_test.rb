# frozen_string_literal: true

require "test_helper"

class PreferenceDbscAdvertisementTest < ActionDispatch::IntegrationTest
  { "app" => "SERVICE", "com" => "CORPORATE", "org" => "STAFF" }.each do |surface, host_key|
    test "#{surface} Core advertises its host-local Preference DBSC endpoint" do
      host! ENV.fetch("PUBLIC_CORE_#{host_key}_URL")
      patch "/api/v0/preferences/theme", params: { theme: "dark" }, as: :json

      assert_response :ok
      value = response.headers.fetch(PreferenceIoKeys::Headers::DBSC_REGISTRATION)

      assert_includes value, 'path="/api/v0/preferences/dbsc"'
      assert_equal value, response.headers.fetch(PreferenceIoKeys::Headers::DBSC_SECURE_REGISTRATION)
    end

    %w(BASE AUTH).each do |family|
      test "#{surface} #{family} does not advertise an unsupported Preference DBSC endpoint" do
        host! ENV.fetch("PUBLIC_#{family}_#{host_key}_URL")
        patch "/api/v0/preferences/theme", params: { theme: "dark" }, as: :json

        assert_response :ok
        assert_nil response.headers[PreferenceIoKeys::Headers::DBSC_REGISTRATION]
        assert_nil response.headers[PreferenceIoKeys::Headers::DBSC_SECURE_REGISTRATION]
      end
    end
  end
end
