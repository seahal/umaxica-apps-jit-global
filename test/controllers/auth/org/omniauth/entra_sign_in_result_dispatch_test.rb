# typed: false
# frozen_string_literal: true

require "test_helper"

# Entra ID is the first stage of normal org sign-in, not the whole of it.
#
# A successful callback must establish no session and issue no token. What it
# produces is a pending transaction naming the operator Entra selected, plus a
# handoff to the passkey stage; the ceremony is completed there, or at the
# secret stage when the passkey is lost.
class Auth::Org::Omniauth::EntraSignInResultDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Org::Omniauth::OmniauthCallbacksController
    attr_reader :redirected

    def initialize
      super
      @session = {}
      @region = "jp"
    end

    def session = @session

    def current_region_identifier = @region

    def redirect_to(*args, **kwargs)
      @redirected = [args, kwargs]
    end

    def new_auth_org_sign_in_passkey_path(**options)
      "/sign/in/passkey/new?#{options.to_query}"
    end

    def invoke(name, ...) = send(name, ...)
  end

  Operatorish = Struct.new(:id, :public_id)
  Identityish = Struct.new(:id)

  setup do
    @harness = Harness.new
  end

  test "a successful callback hands the browser to the passkey stage without issuing a session" do
    @harness.invoke(
      :start_normal_sign_in_second_stage!,
      operator: Operatorish.new(42, "0123456789ABCDEF"),
      identity: Identityish.new(7),
    )

    paths, options = @harness.redirected

    assert_equal "/sign/in/passkey/new?pt&ri=jp", paths.first
    assert_equal :see_other, options.fetch(:status)
  end

  test "the pending transaction binds the operator, the entra identity, and the ceremony purpose" do
    @harness.invoke(
      :start_normal_sign_in_second_stage!,
      operator: Operatorish.new(42, "0123456789ABCDEF"),
      identity: Identityish.new(7),
    )

    transaction = @harness.session.fetch(OrgNormalSignInTransaction::SESSION_KEY)

    assert_equal OrgNormalSignInTransaction::PURPOSE, transaction.fetch("purpose")
    assert_equal 42, transaction.fetch("operator_id")
    assert_equal 7, transaction.fetch("entra_identity_id")
    assert_operator transaction.fetch("expires_at"), :>, Time.current.to_i
    assert_operator transaction.fetch("expires_at"), :<=, (Time.current + OrgNormalSignInTransaction::TTL).to_i
  end
end
