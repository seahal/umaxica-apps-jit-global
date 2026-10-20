# frozen_string_literal: true

require "test_helper"

class BaseOrgSupportRelayTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the support action relays GET and HEAD through owner reads and POST through writes" do
    # Exercise the existing public action's HTTP orchestration; Browser RP admission is covered
    # separately by the request authentication tests. Only the remote owner is replaced here.
    %w(GET HEAD POST).each do |verb|
      controller = Base::Org::SupportController.new
      request = ActionDispatch::TestRequest.create(
        "REQUEST_METHOD" => verb, "PATH_INFO" => "/support", "QUERY_STRING" => "ri=jp",
      )
      request.host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
      controller.set_request!(request)
      controller.set_response!(ActionDispatch::TestResponse.new)
      result = OrgAdminAuthorityClient::Result.new(
        status: :ok, data: { "areas" => [] }, errors: {}, http_status: 200,
      )
      client = Minitest::Mock.new
      client.expect((verb == "POST") ? :post : :get, result) do |path, params, extra_headers:|
        assert_equal "/support", path
        assert_equal "jp", params.fetch("ri")
        assert_equal "html", extra_headers.fetch("X-Browser-Format")
        true
      end
      OrgAdminAuthorityClient.stub(:new, client) { controller.index }

      assert_equal 200, controller.response.status
      assert_equal({ "areas" => [] }, JSON.parse(controller.response.body))
      client.verify
    end
  end
end
