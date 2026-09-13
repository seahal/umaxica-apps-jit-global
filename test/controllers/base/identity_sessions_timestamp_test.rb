# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentitySessionsTimestampTest < ActiveSupport::TestCase
  SessionTimestampRecord = Struct.new(
    :id, :public_id, :created_at, :last_used_at, :discarded_at,
    keyword_init: true,
  ) do
    def emergency_authentication_context? = false
    def authentication_context_value = AuthenticationContextValue.normal
    def dbsc_enabled? = true
  end

  setup do
    @original_preference = Actor.preferences
    Actor.preferences = Actor::Preference.from_jwt(
      { "lx" => "en", "tz" => "america/new_york", "df" => "us", "tf" => "12" },
    )
    @record = SessionTimestampRecord.new(
      created_at: Time.utc(2026, 9, 13, 1, 8),
      last_used_at: Time.utc(2026, 9, 13, 2, 8),
      discarded_at: Time.utc(2026, 10, 13, 1, 8),
    )
  end

  teardown do
    Actor.preferences = @original_preference
  end

  %i(app com org).each do |surface|
    test "the shared session presenter applies the preference JWT for #{surface}" do
      I18n.with_locale(:en) do
        row = Base::Identity::SessionPresenter.new.present(@record, current: true, surface: surface)

        assert_equal "Unknown device", row.fetch(:device)
        assert_equal "09/12/2026 09:08 pm", row.fetch(:created)
        assert_equal "09/12/2026 10:08 pm", row.fetch(:last_activity)
        assert_equal "10/12/2026 09:08 pm", row.fetch(:expires_at)
        assert_equal "Current session", row.fetch(:status)
        assert_equal "Normal", row.fetch(:mode) if surface == :org
        refute row.key?(:mode) unless surface == :org
      end
    end
  end
end
