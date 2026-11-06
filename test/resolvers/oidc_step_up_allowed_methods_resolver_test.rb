# frozen_string_literal: true

require "test_helper"

class OidcStepUpAllowedMethodsResolverTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "APP NORMAL allows configured step-up methods and ADVANCED restricts them to Passkey" do
    normal = clients(:one)
    advanced = clients(:two)
    advanced.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal %i(passkey totp email_otp), OidcStepUpAllowedMethodsResolver.call(actor: normal)
    assert_equal [:passkey], OidcStepUpAllowedMethodsResolver.call(actor: advanced)
  end

  test "ORG allows only Passkey and an invalid APP Security Mode offers no method" do
    operator = operators(:one)
    invalid_app = clients(:one)
    invalid_app.security_mode_id = 0

    assert_equal [:passkey], OidcStepUpAllowedMethodsResolver.call(actor: operator)
    assert_empty OidcStepUpAllowedMethodsResolver.call(actor: invalid_app)
  end

  test "unsupported actors fail explicitly" do
    assert_raises(ArgumentError) { OidcStepUpAllowedMethodsResolver.call(actor: Object.new) }
  end
end
