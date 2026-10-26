# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
# require "helpers/auth_helpers"

class Base::EdgeV0TokenChecksTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
      actor: ->(test_case) { test_case.clients(:one) },
      build_token: ->(test_case) { ClientToken.create!(authentication_epoch: 0, user: test_case.clients(:one)) },
      resource_type: "client",
    },
    {
      host: ENV.fetch("PUBLIC_VISA_STAFF_URL"),
      actor: ->(test_case) { test_case.operators(:one) },
      build_token: ->(test_case) { OperatorToken.create!(authentication_epoch: 0, staff: test_case.operators(:one)) },
      resource_type: "operator",
    },
    {
      host: ENV.fetch("PUBLIC_VISA_CORPORATE_URL"),
      actor: ->(test_case) { test_case.visitors(:reserved_visitor) },
      build_token: ->(test_case) {
        VisitorToken.create!(authentication_epoch: 0, visitor: test_case.visitors(:reserved_visitor))
      },
      resource_type: "visitor",
    },
  ].freeze

  test "GET check without an access token returns 401 on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "/edge/v0/token/check",
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :unauthorized
      assert_equal({ "authenticated" => false }, response.parsed_body)
    end
  end
end
