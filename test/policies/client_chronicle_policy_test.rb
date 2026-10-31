# frozen_string_literal: true

require "test_helper"

class ClientChroniclePolicyTest < ActiveSupport::TestCase
  fixtures :clients, :operators

  test "client may list and show activity logs" do
    policy = ClientChroniclePolicy.new(ClientChronicle, user: clients(:one))

    assert policy.apply(:index?)
    assert policy.apply(:show?)
  end

  test "operator may not list or show client activity logs" do
    policy = ClientChroniclePolicy.new(ClientChronicle, user: operators(:one))

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end

  test "anonymous actor may not list or show client activity logs" do
    policy = ClientChroniclePolicy.new(ClientChronicle, user: nil)

    assert_not policy.apply(:index?)
    assert_not policy.apply(:show?)
  end
end
