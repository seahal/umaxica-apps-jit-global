# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch21MorePreciseTest < ActiveSupport::TestCase
  test "entra redirect uri blank origin raises" do
    hosts = Object.new
    hosts.define_singleton_method(:auth_staff) { "" }
    boot = { hosts: hosts }

    Rails.configuration.x.stub(:boot_config, boot) do
      assert_raises(KeyError) { ExternalAuthenticationEntraRedirectUri.call }
    end
  end
end
