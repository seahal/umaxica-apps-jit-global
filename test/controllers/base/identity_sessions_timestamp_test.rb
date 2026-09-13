# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseIdentitySessionsTimestampTest < ActiveSupport::TestCase
  SessionTimestampRecord =
    Struct.new(
      :id,
      :public_id,
      :user_token_status_id,
      :user_token_kind_id,
      :visitor_token_status_id,
      :visitor_token_kind_id,
      :staff_token_status_id,
      :staff_token_kind_id,
      :device_session_id,
      :created_at,
      :last_used_at,
      :discarded_at,
      keyword_init: true,
    ) do
      def dbsc_enabled? = false
    end

  setup do
    @original_preference = Actor.preferences
    Actor.preferences = Actor::Preference.from_jwt(
      {
        "lx" => "en",
        "tz" => "america/new_york",
        "df" => "us",
        "tf" => "12",
      },
    )
  end

  teardown do
    Actor.preferences = @original_preference
  end

  test "app serializes session timestamps using the preference JWT" do
    record = SessionTimestampRecord.new(
      id: 1,
      public_id: "app-session",
      user_token_status_id: 11,
      user_token_kind_id: 11,
      device_session_id: "device-1",
      created_at: Time.utc(2026, 9, 13, 1, 8),
      last_used_at: Time.utc(2026, 9, 13, 2, 8),
      discarded_at: Time.utc(2026, 10, 13, 1, 8),
    )
    controller = Base::App::Identity::SessionsController.new
    controller.define_singleton_method(:params) { { ri: "jp" } }
    controller.define_singleton_method(:current_session) { record }
    controller.define_singleton_method(:current_session_public_id) { record.public_id }
    controller.define_singleton_method(:base_app_identity_session_path) do |_public_id, **_options|
      "/identity/sessions/app-session"
    end

    I18n.with_locale(:en) do
      serialized = controller.send(:serialize_session, record)

      assert_equal "09/12/2026 09:08 pm", serialized.fetch(:created)
      assert_equal "09/12/2026 10:08 pm", serialized.fetch(:last_activity)
      assert_equal "10/12/2026 09:08 pm", serialized.fetch(:refresh_expires)
    end
  end

  test "com serializes session timestamps using the preference JWT" do
    record = SessionTimestampRecord.new(
      id: 2,
      public_id: "com-session",
      visitor_token_status_id: 11,
      visitor_token_kind_id: 11,
      device_session_id: "device-2",
      created_at: Time.utc(2026, 9, 13, 1, 8),
      last_used_at: Time.utc(2026, 9, 13, 2, 8),
      discarded_at: Time.utc(2026, 10, 13, 1, 8),
    )
    controller = Base::Com::Identity::SessionsController.new
    controller.define_singleton_method(:params) { { ri: "jp" } }
    controller.define_singleton_method(:current_session) { record }
    controller.define_singleton_method(:current_session_public_id) { record.public_id }

    I18n.with_locale(:en) do
      serialized = controller.send(:serialize_session_row, record)

      assert_equal "09/12/2026 09:08 pm", serialized.fetch(:created)
      assert_equal "09/12/2026 10:08 pm", serialized.fetch(:last_activity)
      assert_equal "10/12/2026 09:08 pm", serialized.fetch(:refresh_expires)
    end
  end

  test "org serializes session timestamps using the preference JWT" do
    record = SessionTimestampRecord.new(
      id: 3,
      public_id: "org-session",
      staff_token_status_id: 11,
      staff_token_kind_id: 11,
      device_session_id: "device-3",
      created_at: Time.utc(2026, 9, 13, 1, 8),
      last_used_at: Time.utc(2026, 9, 13, 2, 8),
      discarded_at: Time.utc(2026, 10, 13, 1, 8),
    )
    controller = Base::Org::Identity::SessionsController.new
    controller.define_singleton_method(:params) { { ri: "jp" } }
    controller.define_singleton_method(:current_session) { record }
    controller.define_singleton_method(:current_session_public_id) { record.public_id }

    I18n.with_locale(:en) do
      serialized = controller.send(:serialize_session, record)

      assert_equal "09/12/2026 09:08 pm", serialized.fetch(:created)
      assert_equal "09/12/2026 10:08 pm", serialized.fetch(:last_activity)
      assert_equal "10/12/2026 09:08 pm", serialized.fetch(:refresh_expires)
    end
  end
end
