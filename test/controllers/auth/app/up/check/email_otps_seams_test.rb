# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up email code step answers a resend that is inside its cooldown on
# the code page itself, and an address that has no registration behind it is
# verified against a dummy so the two are indistinguishable in both timing and
# response.
class AuthAppUpCheckEmailOtpsSeamsTest < ActiveSupport::TestCase
  counts_rate_limits!
  self.fixture_table_names = []

  class Harness < Auth::App::Sign::Up::Check::Email::OtpsController
    attr_accessor :page_status, :dummy_verified

    def render_sign_up_email_edit(status: :ok)
      self.page_status = status
    end

    def verify_dummy_otp(code)
      self.dummy_verified = code
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.instance_variable_set(:@user_email, ClientEmail.new)
  end

  test "a resend inside its cooldown is answered on the code page with a too-many-requests status" do
    @harness.invoke(:render_otp_ceremony_result, Struct.new(:status).new(:rate_limited))

    assert_equal :too_many_requests, @harness.page_status
    assert_includes @harness.instance_variable_get(:@user_email).errors.full_messages.join(" "),
                    I18n.t("sign.app.registration.email.create.otp_resend_too_soon")
  end

  test "a code submitted for an address with no registration is verified against a dummy" do
    result = @harness.invoke(:verify_dummy_otp_ceremony!, "123456")

    assert_equal "123456", @harness.dummy_verified
    assert_not result.success?
    assert_equal :invalid_code, result.status
  end
end
