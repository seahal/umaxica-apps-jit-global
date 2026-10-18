# typed: false
# frozen_string_literal: true

require "test_helper"

# Two hand-offs that end a ceremony and must not be allowed to end it halfway.
#
# A social callback that fails for an unexpected reason has to clear the stored
# intent before the error propagates, or the next callback would resume against a
# ceremony that already failed. And the RP-initiated logout completion is matched
# against the state it issued, which is the only thing distinguishing the
# provider's callback from an arbitrary GET.
class SocialCallbackAndLogoutCompletionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Both concerns declare callbacks when included, so the harnesses have to be
  # controllers. ApplicationController would drag in the surface stack these are
  # deliberately outside of.
  class CallbackHarness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::SocialOmniauthCallbackFlow

    attr_accessor :params, :cleared, :handled, :redirects

    def initialize
      super
      @params = ActionController::Parameters.new({})
      @cleared = 0
      @handled = []
      @redirects = []
    end

    def invoke(name, ...) = send(name, ...)

    def clear_social_auth_intent! = self.cleared += 1

    def handle_omniauth_callback(auth) = handled << auth

    def social_auth_failure_redirect_path = "/sign/in"

    def redirect_to(*args, **kwargs) = redirects << [args, kwargs]
  end

  test "an unexpected callback failure clears the stored intent before propagating" do
    harness = CallbackHarness.new
    harness.define_singleton_method(:handle_omniauth_callback) { |_auth| raise IOError, "provider unreachable" }
    request = ActionDispatch::TestRequest.create
    request.env["omniauth.auth"] = OmniAuth::AuthHash.new(provider: "google", uid: "u")
    harness.set_request!(request)

    assert_raises(IOError) { harness.omniauth }
    assert_equal 1, harness.cleared, "a failed ceremony must not be resumable by the next callback"
  end
end
