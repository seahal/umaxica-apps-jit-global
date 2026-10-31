# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcTokenExchangeBoundaryTest < ActiveSupport::TestCase
  test "token exchange service does not mint actor-root sessions" do
    source = Rails.root.join("app/services/oidc_token_exchange_coordinator.rb").read

    assert_no_match(/ClientToken\.create!?/, source)
    assert_no_match(/OperatorToken\.create!?/, source)
    assert_no_match(/create_login_token_record/, source)
    assert_no_match(/\blog_in\b/, source)
  end

  test "token exchange service does not rotate the root refresh token directly" do
    source = Rails.root.join("app/services/oidc_token_exchange_coordinator.rb").read

    assert_no_match(/root_token\.rotate_refresh_token!/, source)
  end
end
