# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  # D-59 (two.md section 3.5): the Sign Entry classification is a static declaration, and the
  # reachable Auth routes must equal the declared set. An action with no declaration is a failing
  # guard here, never a silent exclusion at request time.
  class SignEntryClassificationGuardTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    AUTH_CONTROLLER_PREFIX = "auth/"
    # Reachable interactive flows whose classification has to name the flow it continues.
    SIGN_IN_CLASS_PREFIXES = %w(Auth::App::Sign::In Auth::Org::Sign::In Auth::App::Web::V0::In).freeze
    SIGN_UP_CLASS_PREFIXES = %w(Auth::App::Sign::Up Auth::Org::Sign::Up).freeze

    test "every reachable Auth route resolves to a declared classification" do
      missing =
        auth_routes.filter_map do |route|
          controller_class = controller_class_for(route)
          if controller_class.nil?
            next "#{route.verb.presence || "ANY"} #{route.path.spec} => " \
                 "#{route.defaults[:controller]}##{route.defaults[:action]}: controller not found"
          end

          action = route.defaults[:action].to_sym
          next if classification_for(controller_class, action)

          "#{route.verb.presence || "ANY"} #{route.path.spec} => " \
            "#{controller_class.name}##{action}"
        end

      assert_empty missing,
                   "Reachable Auth actions must declare a Sign Entry classification:\n#{missing.join("\n")}"
    end

    test "the Auth application controllers carry no default classification" do
      # A default on the application controller would turn every future undeclared entry
      # controller into an implicit exclusion.
      assert_nil Auth::App::ApplicationController.sign_entry_classification_value
      assert_nil Auth::Org::ApplicationController.sign_entry_classification_value
    end

    test "every Auth controller declares one of the closed classifications" do
      invalid =
        auth_controller_classes.filter_map do |controller_class|
          next if unreserved_application_controller?(controller_class)

          value = controller_class.sign_entry_classification_value
          next "#{controller_class.name}: undeclared" if value.nil?

          unless SignEntryClassification::CLASSIFICATIONS.include?(value)
            next "#{controller_class.name}: unsupported #{value.inspect}"
          end

          reason = controller_class.sign_entry_classification_reason
          if value == :excluded && reason.blank?
            next "#{controller_class.name}: excluded without a reason"
          end

          overrides = controller_class.sign_entry_classification_overrides
          if overrides.value?(:excluded) && reason.blank?
            next "#{controller_class.name}: excluded action without a reason"
          end
          if value != :excluded && !overrides.value?(:excluded) && !controller_class.sign_entry_standby_only? &&
              reason.present?
            next "#{controller_class.name}: reason on a governed flow"
          end

          nil
        end

      assert_empty invalid, "Auth controllers must declare a valid classification:\n#{invalid.join("\n")}"
    end

    test "interactive classes are classified for the flow their namespace names" do
      mismatched =
        auth_controller_classes.filter_map do |controller_class|
          value = controller_class.sign_entry_classification_value
          expected =
            case value
            when :sign_in
              :sign_in if SIGN_IN_CLASS_PREFIXES.any? { |prefix| controller_class.name.start_with?(prefix) }
            when :sign_up
              :sign_up if SIGN_UP_CLASS_PREFIXES.any? { |prefix| controller_class.name.start_with?(prefix) }
            end
          next if expected == value

          "#{controller_class.name}: declared #{value.inspect}, namespace says #{expected.inspect}"
        end

      assert_empty mismatched,
                   "Sign In and Sign Up controllers must not carry the other flow's classification:\n" \
                   "#{mismatched.join("\n")}"
    end

    test "standby-only Emergency entry is an explicit exemption from the normal Sign In stop" do
      standby_classes = [
        Auth::Org::Sign::In::Emergency::PasskeysController,
        Auth::Org::Sign::In::Emergency::Passkey::OptionsController,
        Auth::Org::Sign::In::Emergency::Passkey::VerificationsController,
      ]

      standby_classes.each do |controller_class|
        assert_equal :sign_in, controller_class.sign_entry_classification_value, controller_class.name
        assert_predicate controller_class, :sign_entry_standby_only?, controller_class.name
        assert_match(/standby/i, controller_class.sign_entry_classification_reason, controller_class.name)
      end
    end

    test "parent_intent resolves its flow from the verified parent, never request parameters" do
      source = Rails.root.join("app/controllers/concerns/sign_entry_sentry_enforcement.rb").read

      verified_parent_body = source[/def sign_entry_intent_from_verified_parent.*?^  end$/m]

      assert_not_nil verified_parent_body, "sign_entry_intent_from_verified_parent must stay the single parent resolver"
      assert_no_match(/\bparams\b/, verified_parent_body, "parent_intent must not read request parameters")

      request_flow_body = source[/def sign_entry_sentry_flow_for_request.*?^  end$/m]

      assert_not_nil request_flow_body
      assert_no_match(/\bparams\b/, request_flow_body, "the request classification must not read request parameters")
    end

    test "the classification set is closed and excluded requires a reason" do
      assert_equal %i(sign_in sign_up parent_intent excluded), SignEntryClassification::CLASSIFICATIONS

      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, standby_only: true, reason: "standby"
        end
      end
      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_up, standby_only: true, reason: "standby"
        end
      end
      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, standby_only: "true"
        end
      end

      assert_raises(SignEntryClassification::UnsupportedClassificationError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_on
        end
      end

      assert_raises(SignEntryClassification::MissingExcludedReasonError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :excluded
        end
      end

      assert_raises(SignEntryClassification::MissingExcludedReasonError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, actions: { show: :excluded }
        end
      end

      controller_class =
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, reason: "health check", actions: { show: :excluded }
        end

      assert_equal :excluded, controller_class.sign_entry_classification_overrides[:show]
      assert_equal "health check", controller_class.sign_entry_classification_reason
    end

    private

    def auth_routes
      Rails.application.routes.routes.select do |route|
        route.defaults[:controller].to_s.start_with?(AUTH_CONTROLLER_PREFIX) &&
          route.defaults[:action].present?
      end
    end

    def controller_class_for(route)
      controller_name = route.defaults[:controller]
      return nil if controller_name.blank?

      "#{controller_name.camelize}Controller".safe_constantize
    end

    def classification_for(controller_class, action)
      controller_class.sign_entry_classification_overrides[action] ||
        controller_class.sign_entry_classification_value
    end

    def auth_controller_classes
      Rails.root.glob("app/controllers/auth/**/*_controller.rb").filter_map do |path|
        relative = path.relative_path_from(Rails.root.join("app/controllers")).to_s.delete_suffix(".rb")
        "#{relative.camelize}Controller".safe_constantize
      end.uniq
    end

    def unreserved_application_controller?(controller_class)
      [Auth::App::ApplicationController, Auth::Org::ApplicationController].include?(controller_class)
    end
  end
end
