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

  class LogoutHarness < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ::FqdnAvailabilityGate
    include ::OidcRpLogoutLauncher

    attr_accessor :params, :session, :consumed, :completions, :heads

    def initialize
      super
      @params = ActionController::Parameters.new({})
      @session = {}
      @consumed = 0
      @completions = 0
      @heads = []
    end

    def invoke(name, ...) = send(name, ...)

    def consume_sign_out_notice
      self.consumed += 1
      { "state" => "consumed" }
    end

    def render_oidc_rp_logout_completion = self.completions += 1

    def sign_out_active_context_present? = false

    def logout_surface_name = "app"

    def head(status, **)
      heads << status
      status
    end
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

  test "a callback with no auth hash is redirected rather than handled" do
    harness = CallbackHarness.new
    harness.set_request!(ActionDispatch::TestRequest.create)

    harness.invoke(:handle_missing_auth)

    assert_equal 1, harness.redirects.size
    assert_equal ["/sign/in"], harness.redirects.first.first
    assert_empty harness.handled
  end

  test "a surface that does not need the writing role handles the callback directly" do
    harness = CallbackHarness.new

    assert_not harness.invoke(:social_omniauth_callback_requires_writing_role?)

    harness.invoke(:run_social_omniauth_callback, :auth)

    assert_equal [:auth], harness.handled
  end

  # OmniAuth's test mode short-circuits the request phase, so the callback action
  # has to read the mocked hash back out itself and put it where the real
  # middleware would have.
  test "in OmniAuth test mode the mocked hash is read back and installed on the request" do
    harness = CallbackHarness.new
    harness.set_request!(ActionDispatch::TestRequest.create)
    harness.params = ActionController::Parameters.new(provider: "google")
    mock = OmniAuth::AuthHash.new(provider: "google", uid: "mocked")
    previous = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google] = mock

    assert_equal mock, harness.invoke(:test_mode_omniauth_auth_hash)
    assert_equal mock, harness.request.env["omniauth.auth"]

    OmniAuth.config.mock_auth.delete(:google)

    assert_nil harness.invoke(:test_mode_omniauth_auth_hash)
  ensure
    OmniAuth.config.mock_auth.delete(:google)
    OmniAuth.config.test_mode = previous
  end

  test "the logout completion is only consumed when the returned state matches the issued one" do
    matching = LogoutHarness.new
    matching.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY] = "notice-id"
    matching.params = ActionController::Parameters.new(state: "issued-state")
    store = Object.new
    store.define_singleton_method(:read) do |raw_id:|
      raise ArgumentError, "unexpected notice id" unless raw_id == "notice-id"

      { "face" => "app", "state" => "issued-state" }
    end

    Valkey::AuthState::SignOutNoticeStore.stub(:new, store) do
      matching.invoke(:complete_oidc_rp_logout!)
    end

    assert_equal 1, matching.consumed
    assert_equal 1, matching.completions
    assert_empty matching.heads
  end

  test "a state of the wrong length or the wrong value completes without consuming" do
    # Same length but different value, and a different length: the comparison
    # checks the length first so the constant-time compare is never fed a
    # mismatched pair.
    ["issued-state-but-longer", "issued-statX"].each do |provided|
      harness = LogoutHarness.new
      harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY] = "notice-id"
      harness.params = ActionController::Parameters.new(state: provided)
      store = Object.new
      store.define_singleton_method(:read) { |**| { "face" => "app", "state" => "issued-state" } }

      Valkey::AuthState::SignOutNoticeStore.stub(:new, store) do
        harness.invoke(:complete_oidc_rp_logout!)
      end

      assert_equal 0, harness.consumed, provided
      assert_equal 0, harness.completions, provided
      assert_equal [:not_found], harness.heads, provided
    end
  end

  test "a missing state on either side completes without consuming" do
    [
      ["issued-state", nil],
      ["", "issued-state"],
    ].each do |expected, provided|
      harness = LogoutHarness.new
      harness.session[SignOutNotice::SIGN_OUT_NOTICE_SESSION_KEY] = "notice-id"
      harness.params = ActionController::Parameters.new(state: provided)
      store = Object.new
      store.define_singleton_method(:read) { |**| { "face" => "app", "state" => expected } }

      Valkey::AuthState::SignOutNoticeStore.stub(:new, store) do
        harness.invoke(:complete_oidc_rp_logout!)
      end

      assert_equal 0, harness.consumed, [expected, provided].inspect
      assert_equal 0, harness.completions, [expected, provided].inspect
      assert_equal [:not_found], harness.heads, [expected, provided].inspect
    end
  end
end
