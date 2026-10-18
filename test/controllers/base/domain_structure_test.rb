# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Base
  class DomainStructureTest < ActionDispatch::IntegrationTest
    test "base/com authenticates its RP credential and retains Visitor authorization and verification" do
      controller = Base::Com::ApplicationController.new

      assert_includes controller.class, ::BrowserRpAuthentication
      assert_includes controller.class, ::BrowserRpSafeRequestRefresh
      assert_includes controller.class, ::BrowserRpUnsafeRequestRefresh
      assert_not_includes controller.class, ::AuthenticationVisitor
      assert_includes controller.class, ::AuthorizationVisitor,
                      "Base::Com should use Visitor authorization"
      assert_includes controller.class, ::VerificationVisitor,
                      "Base::Com should use Visitor verification"
    end

    test "base/org validates and refreshes RP credentials on both safe and unsafe requests" do
      callbacks = Base::Org::ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map(&:filter)

      assert_includes before_filters, :authenticate_browser_rp_safe_request!
      assert_includes before_filters, :authenticate_browser_rp_unsafe_request!
      assert_not_includes before_filters, :transparent_refresh_access_token
    end
  end
end
