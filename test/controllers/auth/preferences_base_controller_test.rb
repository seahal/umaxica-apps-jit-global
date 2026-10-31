# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthPreferencesBaseControllerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "preference bases use surface application controllers and ActorSupport" do
    [
      Auth::App::PreferencesBaseController,
      Auth::Org::PreferencesBaseController,
    ].each do |controller|
      assert_equal controller.module_parent::ApplicationController, controller.superclass
      assert_includes controller.included_modules, ActorSupport
      assert_includes controller.included_modules, ActionPolicy::Controller
    end
  end

  test "open preference bases keep their surface layouts" do
    assert_equal "auth/app/application", Auth::App::PreferencesBaseController._layout
    assert_equal "auth/org/application", Auth::Org::PreferencesBaseController._layout
  end

  test "preference bases authorize writes after actor resolution" do
    [
      Auth::App::PreferencesBaseController,
      Auth::Org::PreferencesBaseController,
    ].each do |controller|
      before_filters = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      assert_operator before_filters.index(:set_current_actor), :<,
                      before_filters.index(:authorize_preference_write!)
    end
  end
end
