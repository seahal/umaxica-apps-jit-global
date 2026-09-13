# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ControllerBaseInheritanceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  BARE_CONTROLLERS = [
    Auth::App::BareController,
    Auth::Com::BareController,
    Auth::Org::BareController,
    Base::App::BareController,
    Base::Com::BareController,
    Base::Dev::BareController,
    Base::Net::BareController,
    Base::Org::BareController,
    Core::App::BareController,
    Core::Com::BareController,
    Core::Dev::BareController,
    Core::Net::BareController,
    Core::Org::BareController,
    Docs::App::BareController,
    Docs::Com::BareController,
    Docs::Org::BareController,
    Guid::Net::BareController,
    Help::App::BareController,
    Help::Com::BareController,
    Help::Org::BareController,
    Info::App::BareController,
    Info::Com::BareController,
    Info::Org::BareController,
    News::App::BareController,
    News::Com::BareController,
    News::Org::BareController,
    Palm::App::BareController,
    Side::App::BareController,
    Side::Com::BareController,
    Side::Org::BareController,
  ].freeze

  APPLICATION_CONTROLLERS = [
    Auth::App::ApplicationController,
    Auth::Com::ApplicationController,
    Auth::Org::ApplicationController,
    Base::App::ApplicationController,
    Base::Com::ApplicationController,
    Base::Dev::ApplicationController,
    Base::Net::ApplicationController,
    Base::Org::ApplicationController,
    Core::App::ApplicationController,
    Core::Com::ApplicationController,
    Core::Org::ApplicationController,
    Side::App::ApplicationController,
    Side::Com::ApplicationController,
    Side::Org::ApplicationController,
  ].freeze

  test "bare controllers inherit directly from ActionController base" do
    BARE_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass,
                   "#{controller.name} must bypass ApplicationController and its callbacks"
      if controller.module_parent.const_defined?(:ApplicationController, false)
        assert_not_operator controller, :<, controller.module_parent::ApplicationController
      end

      assert_includes controller.ancestors, RateLimit
    end
  end

  test "bare controller source does not normalize inheritance to application controller" do
    violations =
      Rails.root.glob("app/controllers/**/bare_controller.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        path.relative_path_from(Rails.root).to_s if content.include?("class BareController < ApplicationController")
      end

    assert_empty violations,
                 "BareController must inherit ActionController::Base directly:\n#{violations.join("\n")}"
  end

  test "surface application controllers inherit directly from ActionController base" do
    APPLICATION_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  # Guards against the silent-degradation case where a new surface adds its own
  # bare_controller.rb but the author forgets to register it in BARE_CONTROLLERS,
  # letting that controller escape the inheritance assertions above. The runtime
  # list and the on-disk files must stay in lockstep.
  test "BARE_CONTROLLERS stays in sync with bare_controller.rb files on disk" do
    discovered =
      Rails.root.glob("app/controllers/**/bare_controller.rb").map do |path|
        relative = path.relative_path_from(Rails.root.join("app/controllers"))
        relative.to_s.delete_suffix(".rb").camelize.constantize
      end.sort_by(&:name)

    assert_equal BARE_CONTROLLERS.sort_by(&:name), discovered,
                 "BARE_CONTROLLERS must list every bare_controller.rb so each is inheritance-checked"
  end

  test "legacy open controller compatibility bases are retired" do
    [
      Base::App,
      Base::Com,
      Base::Org,
      Core::App,
      Core::Com,
      Core::Org,
      Auth::App,
      Auth::Com,
      Auth::Org,
      Side::App,
      Side::Com,
      Side::Org,
    ].each do |namespace|
      assert_not namespace.const_defined?(:OpenController, false), namespace.name
    end
  end

  test "check namespace controllers do not inherit checkpoint namespace implementations" do
    violations =
      Rails.root.glob("app/controllers/auth/**/*_controller.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        next unless content.match?(/class\s+.*::Checks?::?.*Controller\s*<\s*.*::Checkpoints?::?.*Controller/)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty violations,
                 "Check namespace controllers must not inherit stale Checkpoint implementations:\n" \
                 "#{violations.join("\n")}"
  end

  test "application routes reference loadable controller classes" do
    missing =
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next if controller.blank?

        class_name = "#{controller.camelize}Controller"
        class_name.constantize
        nil
      rescue NameError
        class_name
      end.uniq.sort

    framework_prefixes = /\A(?:ActionMailbox|ActiveStorage|MissionControl|RailsDb|Turbo)::/
    missing.reject! { |class_name| class_name.match?(framework_prefixes) }

    assert_empty missing, "Routes reference missing controller classes:\n#{missing.join("\n")}"
  end
end
