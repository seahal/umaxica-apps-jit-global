# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch3ServicesTest < ActiveSupport::TestCase
  test "OidcTokenExchangeCoordinator issue_tokens_for_consumed! grant failure arms" do
    coordinator = OidcTokenExchangeCoordinator.new(
      grant_type: "authorization_code",
      code: "x",
      redirect_uri: "https://example.test/cb",
      client_id: "base-rails-rp",
      code_verifier: "v",
      expected_resource_type: "client",
    )

    connection = Object.new
    connection.define_singleton_method(:connected_to) { |**_, &block| block.call }
    connection.define_singleton_method(:transaction) { |&block| block.call }
    coordinator.define_singleton_method(:connection_class_for) { |_| connection }

    inactive = Object.new
    inactive.define_singleton_method(:active?) { false }
    coordinator.define_singleton_method(:resolve_resource) { |_| inactive }
    coordinator.define_singleton_method(:resolve_root_token) { |_| usable_root }
    result = coordinator.send(:issue_tokens_for_consumed!, issued_payload, dpop_jkt: nil)

    assert_not result.success?
    assert_equal "invalid_grant", result.error

    resource = active_resource
    coordinator.define_singleton_method(:resolve_resource) { |_| resource }
    coordinator.define_singleton_method(:resolve_root_token) { |_| nil }
    result = coordinator.send(:issue_tokens_for_consumed!, issued_payload, dpop_jkt: nil)

    assert_equal "invalid_grant", result.error

    dead_root = Object.new
    dead_root.define_singleton_method(:currently_usable?) { false }
    coordinator.define_singleton_method(:resolve_root_token) { |_| dead_root }
    result = coordinator.send(:issue_tokens_for_consumed!, issued_payload, dpop_jkt: nil)

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

  def usable_root
    token = Object.new
    token.define_singleton_method(:currently_usable?) { true }
    token
  end

  def issued_payload
    {
      "client_id" => "base-rails-rp",
      "redirect_uri" => "https://example.test/cb",
      "subject" => "cli_one_id",
      "base_session_ref" => "tok_1",
      "code_challenge" => "challenge",
      "code_challenge_method" => "S256",
      "nonce" => "n",
      "scope" => "openid",
      "auth_time" => Time.current.iso8601,
      "resource_type" => "client",
      "issued_at" => Time.current.iso8601,
      "expires_at" => 10.seconds.from_now.iso8601,
      "state" => "issued",
    }
  end
end
