# typed: false
# frozen_string_literal: true

require "test_helper"

class VerificationCookieableTest < ActiveSupport::TestCase
  test "cookie_name uses __Host- prefix only in secure-context environments" do
    {
      ClientVerification => "verification",
      OperatorVerification => "verification",
    }.each do |klass, plain_name|
      JitSessionCookieConfig.stub(:force_secure?, false) do
        assert_equal plain_name, klass.cookie_name
      end

      JitSessionCookieConfig.stub(:force_secure?, true) do
        assert_equal "__Host-#{plain_name}", klass.cookie_name
      end
    end
  end
end
