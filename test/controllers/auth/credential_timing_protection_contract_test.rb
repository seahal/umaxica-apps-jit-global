# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCredentialTimingProtectionContractTest < ActiveSupport::TestCase
  MINIMUM_RESPONSE_BUDGET_CONTROLLERS = [
    Auth::App::Sign::In::PasskeysController,
    Auth::App::Sign::In::Passkey::OptionsController,
    Auth::App::Sign::In::Passkey::VerificationsController,
    Auth::Com::Sign::In::PasskeysController,
    Auth::Com::Sign::In::Passkey::OptionsController,
    Auth::Com::Sign::In::Passkey::VerificationsController,
    Auth::Org::Sign::In::PasskeysController,
    Auth::Org::Sign::In::Passkey::OptionsController,
    Auth::Org::Sign::In::Passkey::VerificationsController,
  ].freeze

  DUMMY_WORK_CONTROLLERS = [
    Auth::App::Sign::In::EmailsController,
  ].freeze

  test "credential controllers that include MinimumResponseBudget register start and enforce callbacks" do
    MINIMUM_RESPONSE_BUDGET_CONTROLLERS.each do |controller_class|
      filters = controller_class._process_action_callbacks.map(&:filter)

      assert_includes filters, :start_minimum_response_budget, controller_class.name
      assert_includes filters, :enforce_minimum_response_budget, controller_class.name
    end
  end

  test "credential controllers either use response budget or documented dummy work" do
    protected_controllers = MINIMUM_RESPONSE_BUDGET_CONTROLLERS + DUMMY_WORK_CONTROLLERS
    expected = [
      Auth::App::Sign::In::EmailsController,
      Auth::App::Sign::In::PasskeysController,
      Auth::App::Sign::In::Passkey::OptionsController,
      Auth::App::Sign::In::Passkey::VerificationsController,
      Auth::Com::Sign::In::PasskeysController,
      Auth::Com::Sign::In::Passkey::OptionsController,
      Auth::Com::Sign::In::Passkey::VerificationsController,
      Auth::Org::Sign::In::PasskeysController,
      Auth::Org::Sign::In::Passkey::OptionsController,
      Auth::Org::Sign::In::Passkey::VerificationsController,
    ]

    assert_equal expected.map(&:name).sort, protected_controllers.map(&:name).sort
  end

  # The Entra strategy's request phase used to pad its response time so a valid
  # and an invalid connection_public_id could not be told apart by timing. The
  # org surface now federates a single tenant read from configuration, so the
  # request phase performs no per-request record lookup and there is no pair of
  # inputs whose timing could differ. The protection was removed with the lookup
  # rather than left as a pad over nothing; this asserts the lookup really is
  # gone, which is what made it unnecessary.
  test "Entra OmniAuth strategy's request phase performs no timing-sensitive record lookup" do
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    body = File.read(strategy_class.instance_method(:request_phase).source_location.first)

    assert_not_includes strategy_class.private_instance_methods, :active_connection
    assert_no_match(/OrganizationEntraConnection/, body)
  end
end
