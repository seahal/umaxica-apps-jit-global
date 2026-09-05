# typed: false
# frozen_string_literal: true

require "test_helper"

# Every sign-up code step answers a resend that is inside its cooldown the same
# way: on the code page, with a too-many-requests status and the shared message.
# Answering differently on one step would tell a caller which step it hit.
class Auth::OtpCeremonyRateLimitAnswersTest < ActiveSupport::TestCase
  counts_rate_limits!
  self.fixture_table_names = []

  def harness_for(controller_class, record)
    Class.new(controller_class) do
      attr_accessor :page_status

      def render_sign_up_email_edit(status: :ok)
        self.page_status = status
      end

      def render_sign_up_telephone_edit(status: :ok)
        self.page_status = status
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.instance_variable_set(:@user_email, record) if record.is_a?(ClientEmail) || record.is_a?(VisitorEmail)
      h.instance_variable_set(:@user_telephone, record) if record.is_a?(ClientTelephone)
      h.instance_variable_set(:@visitor_telephone, record) if record.is_a?(VisitorTelephone)
    end
  end

  {
    Auth::Com::Sign::Up::Check::Email::OtpsController => VisitorEmail,
    Auth::App::Sign::Up::Check::Telephone::OtpsController => ClientTelephone,
    Auth::Com::Sign::Up::Check::Telephone::OtpsController => VisitorTelephone,
  }.each do |controller_class, record_class|
    test "#{controller_class.name} answers a cooldown resend on its own code page" do
      harness = harness_for(controller_class, record_class.new)

      harness.invoke(:render_otp_ceremony_result, Struct.new(:status).new(:rate_limited))

      assert_equal :too_many_requests, harness.page_status
    end
  end
end
