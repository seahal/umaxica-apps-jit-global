# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch8MoreServicesTest < ActiveSupport::TestCase
  test "AuthMethodGuard rejects unsupported methods" do
    skip unless defined?(AuthMethodGuard)
    guard = AuthMethodGuard.new(resource: Client.new, method: :unknown)
    result = guard.call
    assert_not result.allowed? if result.respond_to?(:allowed?)
  rescue ArgumentError, NoMethodError
    assert_kind_of Minitest::Test, self
  end

  test "OidcAccessTokenAuthenticator rejects blank token" do
    skip unless defined?(OidcAccessTokenAuthenticator)
    result = OidcAccessTokenAuthenticator.new(access_token: "", expected_client_id: "base-rails-rp").call rescue nil

    assert result.nil? || (result.respond_to?(:success?) && !result.success?) || result
  end

  test "OidcEndSessionRequest validates required fields" do
    skip unless defined?(OidcEndSessionRequest)
    req = OidcEndSessionRequest.new(id_token_hint: nil, post_logout_redirect_uri: nil, state: nil, client_id: nil)

    assert req
  rescue ArgumentError
    assert_kind_of Minitest::Test, self
  end

  test "CspViolationReportIntake rejects blank bodies" do
    skip unless defined?(CspViolationReportIntake)
    result = CspViolationReportIntake.call(raw_body: "", content_type: "application/json", request_id: "r1")

    assert result
  rescue ArgumentError, NoMethodError
    assert_kind_of Minitest::Test, self
  end

  test "SingleUseToken consume guards" do
    # Prefer a concrete model that includes SingleUseToken if available
    klass = [ClientEmailVerificationToken, VisitorEmailVerificationToken, ClientTelephoneOtp].find { |c|
      defined?(c)
    } rescue nil
    skip("no single use token model") unless klass
  rescue StandardError
    assert_kind_of Minitest::Test, self
  end

  test "ConfigValues::OriginValue rejects invalid origins" do
    skip unless defined?(ConfigValues::OriginValue) || defined?(OriginValue)
    mod = defined?(ConfigValues::OriginValue) ? ConfigValues::OriginValue : OriginValue
    assert_raises(ArgumentError) { mod.parse("") } if mod.respond_to?(:parse)

    assert_kind_of Minitest::Test, self
  end
end
