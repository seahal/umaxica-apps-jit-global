# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch3ServicesTest < ActiveSupport::TestCase
  test "OidcTokenExchangeCoordinator consume_and_issue_tokens! grant failure arms" do
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      code: "x",
      redirect_uri: "https://example.test/cb",
      client_id: "base-rails-rp",
      code_verifier: "v",
    )

    connection = Object.new
    connection.define_singleton_method(:connected_to) { |**_, &block| block.call }
    connection.define_singleton_method(:transaction) { |&block| block.call }
    coordinator.define_singleton_method(:connection_class_for) { |_| connection }
    coordinator.define_singleton_method(:root_token_from_authorization_code) do |code|
      code.root_token
    end

    inactive = Object.new
    inactive.define_singleton_method(:active?) { false }
    result = coordinator.send(:consume_and_issue_tokens!, build_auth_code(resource: inactive))

    assert_not result.success?
    assert_equal "invalid_grant", result.error

    {
      expired: true,
      consumed: true,
      revoked: true,
    }.each do |flag, value|
      kwargs = { :resource => active_resource, flag => value }
      result = coordinator.send(:consume_and_issue_tokens!, build_auth_code(**kwargs))

      assert_equal "invalid_grant", result.error, flag
    end

    unbound = build_auth_code(resource: active_resource, root_token: nil)
    result = coordinator.send(:consume_and_issue_tokens!, unbound)

    assert_equal "invalid_grant", result.error

    dead_root = Object.new
    dead_root.define_singleton_method(:currently_usable?) { false }
    dead = build_auth_code(resource: active_resource, root_token: dead_root)
    result = coordinator.send(:consume_and_issue_tokens!, dead)

    assert_equal "invalid_grant", result.error
  end

  test "AcmeSelectableContext persist_selection! requires session" do
    klass =
      Class.new do
        include AcmeSelectableContext

        def session = nil

        def config = nil

        def principal = nil

        def accounts = []
      end
    error =
      assert_raises(AcmeSelectableContext::InvalidSelection) do
        klass.new.persist_selection!({ public: { account_public_id: "a" } })
      end
    assert_equal "session_required", error.message
  end

  private

  def active_resource
    resource = Object.new
    resource.define_singleton_method(:active?) { true }
    resource
  end

  def build_auth_code(resource:, expired: false, consumed: false, revoked: false, root_token: :default)
    code = Object.new
    code.define_singleton_method(:resource) { resource }
    code.define_singleton_method(:expired?) { expired }
    code.define_singleton_method(:consumed?) { consumed }
    code.define_singleton_method(:revoked?) { revoked }
    code.define_singleton_method(:lock!) { true }
    code.define_singleton_method(:scope) { "openid" }
    token =
      if root_token == :default
        t = Object.new
        t.define_singleton_method(:currently_usable?) { true }
        t
      else
        root_token
      end
    coordinator_root = token
    # root_token_from_authorization_code usually reads association; stub on coordinator side via code methods
    code.define_singleton_method(:client_token) { coordinator_root }
    code.define_singleton_method(:visitor_token) { nil }
    code.define_singleton_method(:operator_token) { nil }
    code.define_singleton_method(:root_token) { coordinator_root }
    code
  end
end
