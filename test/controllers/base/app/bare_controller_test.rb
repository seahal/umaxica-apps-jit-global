# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Visa
  module App
    # Visa::App::BareController intentionally avoids the full application stack:
    # every controller below it must be a public, self-defending endpoint
    # (health, robots, sitemaps, csp-report, open, or an auth flow that
    # enforces its own pipeline). If a new controller is added under this
    # base, that is a security-relevant decision and this pin-down test must
    # fail so the addition gets explicit review instead of silently inheriting
    # the relaxed boundary.
    class BareControllerTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      REQUIRED_DESCENDANTS = %w(
        Visa::App::Api::V0::HealthsController
        Visa::App::Api::V0::RevisionsController
        Visa::App::CspViolationReportsController
        Visa::App::Health::LivenessesController
        Visa::App::Health::ReadinessesController
        Visa::App::Health::StartupsController
        Visa::App::HealthsController
        Visa::App::Oauth::RevocationsController
        Visa::App::Oauth::UserinfosController
        Visa::App::WellKnown::DiscoveriesController
        Visa::App::WellKnown::JwksController
        Visa::App::RevisionsController
        Visa::App::RobotsController
      ).freeze
      OPTIONAL_TEST_DESCENDANTS = %w(
        Base::App::TestCsrfController
      ).freeze

      test "bare boundary does not inherit the full application controller" do
        assert_equal ActionController::Base, Visa::App::BareController.superclass
        assert_not_operator Visa::App::BareController, :<, Visa::App::AuthorityController
      end

      test "only the reviewed allowlist inherits the bare public boundary" do
        Rails.application.eager_load!

        actual = Visa::App::BareController.descendants.filter_map(&:name).grep(/\AVisa::App::/).sort

        assert_not_empty actual, "expected BareController descendants to be loaded after eager_load!"

        allowed = (REQUIRED_DESCENDANTS + OPTIONAL_TEST_DESCENDANTS).sort
        unexpected = actual - allowed
        missing = REQUIRED_DESCENDANTS - actual

        assert_empty unexpected,
                     "Controllers under Visa::App::BareController changed. Each one inherits the bare " \
                     "boundary; confirm the new/removed controller is a public, self-defending " \
                     "endpoint and update ALLOWED_DESCENDANTS deliberately.\n" \
                     "added:   #{unexpected.inspect}\n" \
                     "removed: #{missing.inspect}"
        assert_empty missing
      end
    end
  end
end
