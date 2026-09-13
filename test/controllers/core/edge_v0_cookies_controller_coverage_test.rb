# frozen_string_literal: true

require "test_helper"

# Core edge cookie controllers are kept alongside the Web variants, but Core
# routes currently dispatch preference cookie traffic to Web controllers.
# Invoke show/update through process_action with stubs so the Edge files still
# clear the per-file line floor.
class CoreEdgeV0CookiesControllerCoverageTest < ActiveSupport::TestCase
  CONTROLLERS = [
    Core::App::Edge::V0::CookiesController,
    Core::Com::Edge::V0::CookiesController,
    Core::Org::Edge::V0::CookiesController,
  ].freeze

  test "show and update render the banner payload on every Core edge surface" do
    CONTROLLERS.each do |controller_class|
      controller = controller_class.new
      preference = Object.new
      rendered = {}

      controller.define_singleton_method(:issue_preference_dbsc_registration_header_for) { |_| true }
      controller.define_singleton_method(:show_banner?) { false }
      controller.define_singleton_method(:preference_dbsc_payload_for) { |_| { "secured" => false } }
      controller.define_singleton_method(:load_preference_record_from_refresh_token!) { |**_| [preference, nil] }
      controller.define_singleton_method(:apply_consented_update_from_request!) { @applied = true }
      controller.define_singleton_method(:set_consented_buffer_cookie!) { @buffered = true }
      controller.define_singleton_method(:render) { |**kwargs| rendered.replace(kwargs) }

      controller.show

      assert_equal :ok, rendered[:status]
      assert_not rendered.dig(:json, :show_banner)
      assert_equal({ "secured" => false }, rendered.dig(:json, :dbsc))

      controller.update

      assert controller.instance_variable_get(:@applied)
      assert controller.instance_variable_get(:@buffered)
      assert_equal :ok, rendered[:status]
    end
  end
end
