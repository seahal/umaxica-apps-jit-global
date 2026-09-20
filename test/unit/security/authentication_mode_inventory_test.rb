# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  class AuthenticationModeInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    class ParentController < ApplicationController
      include AuthenticationBase

      declare_authentication_mode! :open
    end

    class UndeclaredController < ParentController
    end

    class ConstantController < ApplicationController
      include AuthenticationBase

      AUTHENTICATION_MODE = :guest
    end

    class PrivateController < ApplicationController
      include AuthenticationBase

      declare_authentication_mode! :private
    end

    class MixedController < ApplicationController
      include AuthenticationBase

      declare_authentication_mode! :deny_all
      declare_authentication_mode! :open, only: :index
      declare_authentication_mode! :guest, only: :new
    end

    test "undeclared concrete controllers resolve to deny_all instead of inheriting parent mode" do
      assert_equal :open, ParentController.authentication_mode_for(:index)
      assert_empty UndeclaredController.access_policy_rules
      assert_empty UndeclaredController.local_authentication_mode_rules
      assert_equal :deny_all, UndeclaredController.authentication_mode_for(:index)
    end

    test "legacy access policy DSL temporarily maps to authentication mode metadata" do
      assert_equal :private, PrivateController.authentication_mode_for(:show)
    end

    test "local AUTHENTICATION_MODE constant is honored without inheritance" do
      assert_equal :guest, ConstantController.authentication_mode_for(:show)
    end

    test "action-specific authentication mode rules override the deny_all default" do
      assert_equal :open, MixedController.authentication_mode_for(:index)
      assert_equal :guest, MixedController.authentication_mode_for(:new)
      assert_equal :deny_all, MixedController.authentication_mode_for(:show)
    end

    test "surface application controllers default to deny_all" do
      [
        Auth::App::ApplicationController,
        Auth::Com::ApplicationController,
        Auth::Org::ApplicationController,
        Base::App::ApplicationController,
        Base::Com::ApplicationController,
        Base::Org::ApplicationController,
        Core::App::ApplicationController,
        Core::Com::ApplicationController,
        Core::Org::ApplicationController,
        Side::App::ApplicationController,
        Side::Com::ApplicationController,
        Side::Org::ApplicationController,
      ].each do |controller_class|
        assert_equal :deny_all, controller_class.authentication_mode_for(:index), controller_class.name
      end
    end

    test "controller files declare a local authentication mode" do
      missing =
        Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          relative_path unless content.match?(/\bAUTHENTICATION_MODE\s*=/)
        end

      assert_empty missing, "Controllers must declare local AUTHENTICATION_MODE:\n#{missing.join("\n")}"
    end

    test "controller files do not use legacy authentication posture DSL" do
      legacy =
        Rails.root.glob("app/controllers/**/*_controller.rb").filter_map do |path|
          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          matches = content.scan(/\b(?:deny_all!|public_strict!|auth_required!|guest_only!)/)
          "#{relative_path}: #{matches.uniq.join(", ")}" if matches.any?
        end

      assert_empty legacy, "Controllers must use AUTHENTICATION_MODE instead of legacy DSL:\n#{legacy.join("\n")}"
    end

    test "bare controllers inherit directly from action controller base" do
      violations =
        Rails.root.glob("app/controllers/**/bare_controller.rb").filter_map do |path|
          relative_path = path.relative_path_from(Rails.root).to_s
          content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
          relative_path unless content.match?(/class\s+BareController\s+<\s+ActionController::Base\b/)
        end

      assert_empty violations,
                   "Bare controllers must inherit ActionController::Base directly:\n#{violations.join("\n")}"
    end

    test "routes resolve to controllers with local authentication mode declarations" do
      missing =
        Rails.application.routes.routes.filter_map do |route|
          controller_name = route.defaults[:controller]
          action_name = route.defaults[:action]
          next if controller_name.blank? || action_name.blank?

          controller_class = "#{controller_name.camelize}Controller".safe_constantize
          next if controller_class.blank?
          next unless application_controller_class?(controller_class)
          next if controller_class.const_defined?(:AUTHENTICATION_MODE, false)
          next if controller_class.respond_to?(:local_authentication_mode_rules) &&
            controller_class.local_authentication_mode_rules.present?

          "#{route.verb.presence || "ANY"} #{route.path.spec} => #{controller_class.name}##{action_name}"
        end

      assert_empty missing, "Routes must not rely on inherited authentication mode:\n#{missing.join("\n")}"
    end

    private

    def application_controller_class?(controller_class)
      controller_class.name.start_with?("Auth::", "Base::", "Core::", "Jump::", "Side::", "Inertia")
    end
  end
end
