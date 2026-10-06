# typed: false
# frozen_string_literal: true

require "test_helper"

# Disabling the last usable sign-in method would lock the operator out of the
# staff surface, so that edit is refused and the page is re-shown instead of
# being applied.
class BaseOrgIdentitySecretCredentialsGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::Org::Identity::SecretCredentialsController
    attr_accessor :params_hash, :redirected, :disabling

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def authorize!(*, **) = true

    def current_operator = nil

    def disabling_secret_credential? = disabling

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  test "disabling the last usable method is refused and the credential page is re-shown" do
    harness = Harness.new
    harness.params_hash = { ri: "jp" }
    harness.request = ActionDispatch::TestRequest.create
    harness.disabling = true
    harness.instance_variable_set(:@secret_credential, Struct.new(:public_id).new("secret-public-id"))

    AuthMethodGuard.stub(:can_remove_secret_credential?, false) do
      harness.update
    end

    assert_includes harness.redirected.first.first, "secret-public-id"
    assert_equal :see_other, harness.redirected.last.fetch(:status)
  end
end
