# typed: false
# frozen_string_literal: true

require "test_helper"

# Every surface answers the shared ceremony flows with its own paths. These are
# one-line seams the shared code calls, and each is the point where a surface
# could be sent to another surface's page -- a staff verification returning to
# the end-user entry point, or a corporate logout completing on the app host.
# They are pinned per surface rather than exercised only where a request happens
# to reach them.
class SurfaceSeamPathsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, params: { ri: "jp" })
    Class.new(controller_class) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.params_hash = params
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  {
    "app" => [Base::App::VerificationsController,
              Base::App::Verification::CompletionsController,
              Base::App::Verification::CancellationsController,],
    "com" => [Base::Com::VerificationsController,
              Base::Com::Verification::CompletionsController,
              Base::Com::Verification::CancellationsController,],
    "org" => [Base::Org::VerificationsController,
              Base::Org::Verification::CompletionsController,
              Base::Org::Verification::CancellationsController,],
  }.each do |surface, controller_classes|
    test "the #{surface} verification seams return to the #{surface} verification page" do
      controller_classes.each do |controller_class|
        path = harness_for(controller_class).invoke(:actor_verification_path, ri: "jp")

        assert_includes path, "/verification", controller_class.name
      end
    end
  end

  {
    "app" => Base::App::Oidc::LogoutsController,
    "com" => Base::Com::Oidc::LogoutsController,
    "org" => Base::Org::Oidc::LogoutsController,
  }.each do |surface, controller_class|
    test "the #{surface} logout completion path stays on the #{surface} surface" do
      path = harness_for(controller_class).invoke(:oidc_logout_completed_path, ri: "jp")

      assert_includes path, "/lobby", controller_class.name
    end
  end

  {
    "app" => Base::App::RootsController,
    "com" => Base::Com::RootsController,
    "org" => Base::Org::RootsController,
  }.each do |surface, controller_class|
    test "the base #{surface} landing page names its own surface" do
      props = harness_for(controller_class).invoke(:root_landing_props)

      assert_equal I18n.t("landing.thin_endpoint"), props.fetch(:description)
      assert_predicate props.fetch(:heading), :present?
    end
  end

  {
    "app" => Auth::App::RootsController,
    "com" => Auth::Com::RootsController,
    "org" => Auth::Org::RootsController,
  }.each do |surface, controller_class|
    test "the credential #{surface} landing page names its own surface" do
      props = harness_for(controller_class).invoke(:root_landing_props)

      assert_equal I18n.t("landing.thin_endpoint"), props.fetch(:description)
      assert_predicate props.fetch(:heading), :present?
    end
  end

  {
    "com" => Base::Com::WelcomesController,
    "org" => Base::Org::WelcomesController,
  }.each do |surface, controller_class|
    test "the #{surface} welcome hand-off returns to the #{surface} dashboard" do
      assert_predicate harness_for(controller_class).invoke(:after_welcome_path), :present?
    end
  end
end
