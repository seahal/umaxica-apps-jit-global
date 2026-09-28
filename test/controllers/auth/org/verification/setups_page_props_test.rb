# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff step-up setup page lists only the methods the operator has not
# configured yet, and offers cancellation as its only exit. An
# operator with every method configured is sent straight on rather than shown an
# empty page.
class AuthOrgVerificationSetupsPagePropsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Org::Verification::SetupsController
    attr_accessor :params_hash, :redirected

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def safe_redirect_to(target, **)
      self.redirected = target
    end

    def verification_redirect_path(**) = "/verification"

    def authorize!(*, **) = true

    def actor_root_path(**) = "/"

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp" }
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "an operator with nothing left to configure is sent on rather than shown an empty page" do
    @harness.instance_variable_set(:@pt, nil)

    @harness.stub(:step_up_supported_methods, []) do
      @harness.stub(:configured_step_up_methods, []) do
        @harness.new
      end
    end

    assert_equal "/verification", @harness.redirected
  end
end
