# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_profile_statuses
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#

require "test_helper"

class ClientProfileStatusTest < ActiveSupport::TestCase
  test "has many clients" do
    assert_equal :has_many, ClientProfileStatus.reflect_on_association(:clients).macro
  end

  test "has many status_clients" do
    assert_equal :has_many, ClientProfileStatus.reflect_on_association(:status_clients).macro
  end
end
