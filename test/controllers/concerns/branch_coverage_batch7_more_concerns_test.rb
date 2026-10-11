# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch7MoreConcernsTest < ActiveSupport::TestCase
  test "SignOidcLogout missing column helpers and revoke path" do
    klass =
      Class.new(ApplicationController) do
        include SignOidcLogout

        def token_class
          Object.new.tap { |k| k.define_singleton_method(:column_names) { [] } }
        end

        def request = ActionDispatch::TestRequest.create

        def params = ActionController::Parameters.new({})
      end
    h = klass.new

    assert_nil h.send(:oidc_current_session_token_by_device_session, "sid")
    assert_nil h.send(:oidc_current_session_token_by_sid, "sid")
    token = Object.new
    token.define_singleton_method(:respond_to?) { |name, *| %i(revoke! reload).include?(name.to_sym) }
    token.define_singleton_method(:revoked?) { false }
    token.define_singleton_method(:reload) { self }
    revoked = false
    token.define_singleton_method(:revoke!) { revoked = true }
    h.send(:revoke_oidc_current_session_token!, token)

    assert revoked
  end

  test "SocialCallbackGuard test_mode and rejection paths without params" do
    klass =
      Class.new do
        include SocialCallbackGuard

        attr_accessor :request_value

        def request = request_value

        def session = {}
      end
    h = klass.new
    h.request_value = ActionDispatch::TestRequest.create
    def h.respond_to?(name, include_all = false)
      return false if name.to_sym == :params

      super
    end
    h.send(:test_mode_mock_auth_present?)

    assert_not h.send(:test_mode_mock_auth_present?)
  end

  test "CommonRedirect redirect_to_pt logs failures and uses default" do
    klass =
      Class.new(ApplicationController) do
        include CommonRedirect

        attr_accessor :redirects

        def initialize
          super
          @redirects = []
        end

        def request = ActionDispatch::TestRequest.create

        def session = {}

        def redirect_to(*args, **kwargs)
          @redirects << [args, kwargs]
        end
      end
    h = klass.new
    bad = Struct.new(:ok?, :value, :kind, :source, :failure_reason, :unsafe_value_digest).new(
      false, nil, :rejected, :pt, :unsafe, "d",
    )
    h.define_singleton_method(:resolve_redirect_target) { |**| bad }
    h.send(:redirect_to_pt, default: "/fallback", pt: "token")

    assert_equal ["/fallback"], h.redirects.first.first
  end
end
