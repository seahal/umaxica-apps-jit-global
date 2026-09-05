# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Base
  module App
    # Base::App::BareController intentionally avoids the full application stack:
    # every controller below it must be a public, self-defending endpoint
    # (health, robots, sitemaps, csp-report, open, or an auth flow that
    # enforces its own pipeline). If a new controller is added under this
    # base, that is a security-relevant decision and this pin-down test must
    # fail so the addition gets explicit review instead of silently inheriting
    # the relaxed boundary.
    class BareControllerTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      REQUIRED_DESCENDANTS = %w(
        Base::App::Api::V0::HealthsController
        Base::App::Api::V0::RevisionsController
        Base::App::CspViolationReportsController
        Base::App::Health::LivenessesController
        Base::App::Health::ReadinessesController
        Base::App::Health::StartupsController
        Base::App::HealthsController
        Base::App::McpsController
        Base::App::Oauth::JwksController
        Base::App::Oauth::RevocationsController
        Base::App::Oauth::UserinfosController
        Base::App::WellKnown::DiscoveriesController
        Base::App::WellKnown::JwksController
        Base::App::Preference::EmailsController
        Base::App::RevisionsController
        Base::App::RobotsController
        Base::App::SitemapsController
      ).freeze
      OPTIONAL_TEST_DESCENDANTS = %w(
        Base::App::TestCsrfController
      ).freeze

      test "bare boundary does not inherit the full application controller" do
        assert_equal ActionController::Base, Base::App::BareController.superclass
        assert_not_operator Base::App::BareController, :<, Base::App::ApplicationController
      end

      test "only the reviewed allowlist inherits the bare public boundary" do
        Rails.application.eager_load!

        actual = Base::App::BareController.descendants.filter_map(&:name).grep(/\ABase::App::/).sort

        assert_not_empty actual, "expected BareController descendants to be loaded after eager_load!"

        allowed = (REQUIRED_DESCENDANTS + OPTIONAL_TEST_DESCENDANTS).sort
        unexpected = actual - allowed
        missing = REQUIRED_DESCENDANTS - actual

        assert_empty unexpected,
                     "Controllers under Base::App::BareController changed. Each one inherits the bare " \
                     "boundary; confirm the new/removed controller is a public, self-defending " \
                     "endpoint and update ALLOWED_DESCENDANTS deliberately.\n" \
                     "added:   #{unexpected.inspect}\n" \
                     "removed: #{missing.inspect}"
        assert_empty missing
      end
    end
  end
end
