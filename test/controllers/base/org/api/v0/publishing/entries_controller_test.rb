# frozen_string_literal: true

require "test_helper"

class Base::Org::Api::V0::Publishing::EntriesControllerTest < ActionController::TestCase
  self.fixture_table_names = []

  test "authenticated reads query exactly the requested publishing cell" do
    cells = {
      ["docs", "app"] => Publishing::Docs::App::Entry,
      ["docs", "com"] => Publishing::Docs::Com::Entry,
      ["docs", "org"] => Publishing::Docs::Org::Entry,
      ["help", "app"] => Publishing::Help::App::Entry,
      ["help", "com"] => Publishing::Help::Com::Entry,
      ["help", "org"] => Publishing::Help::Org::Entry,
      ["info", "app"] => Publishing::Info::App::Entry,
      ["info", "com"] => Publishing::Info::Com::Entry,
      ["info", "org"] => Publishing::Info::Org::Entry,
      ["news", "app"] => Publishing::News::App::Entry,
      ["news", "com"] => Publishing::News::Com::Entry,
      ["news", "org"] => Publishing::News::Org::Entry,
    }
    operator = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)
    auth = OidcAccessTokenAuthenticator::Result.new(
      success: true, payload: { "client_id" => "edit-org-ww" }, resource: operator, token: nil, error: nil,
    )
    cells.each do |(surface, audience), expected_class|
      query = Minitest::Mock.new
      page = PublishingManagementEntriesQuery::Page.new(
        entries: [], number: 1, per_page: 25, total: 0, has_more: false,
      )
      query.expect(:page, page, [], number: 1)
      build_query =
        lambda do |entry_class:|
          assert_equal expected_class, entry_class
          query
        end
      OidcClientRegistry.stub(:authenticate_assertion, true) do
        OidcAccessTokenAuthenticator.stub(:call, auth) do
          PublishingManagementEntriesQuery.stub(:new, build_query) do
            get :index, params: { surface:, audience: }

            assert_response :success
            assert_equal [], response.parsed_body.fetch("entries")
          end
        end
      end
      query.verify
    end
  end

  test "unknown and empty publishing targets are excluded by the public route" do
    [["unknown", "app"], ["docs", "unknown"], ["", "app"], ["docs", ""]].each do |surface, audience|
      assert_raises(ActionController::UrlGenerationError) do
        get :index, params: { surface:, audience: }
      end
    end
  end

  test "unverified callers cannot read publishing entries" do
    OidcClientRegistry.stub(:authenticate_assertion, false) do
      get :index, params: { surface: "docs", audience: "app" }

      assert_response :unauthorized
      assert_equal "invalid_client", response.parsed_body.fetch("error")
    end
  end

  test "an authenticated suspended operator is refused by the publishing policy" do
    operator = Operator.new(
      security_mode_id: SecurityModeConfigurable::ADVANCED, deactivated_at: 1.minute.ago,
      purge_eligible_at: Float::INFINITY,
    )
    auth = OidcAccessTokenAuthenticator::Result.new(
      success: true, payload: { "client_id" => "edit-org-ww" }, resource: operator, token: nil, error: nil,
    )
    OidcClientRegistry.stub(:authenticate_assertion, true) do
      OidcAccessTokenAuthenticator.stub(:call, auth) do
        get :index, params: { surface: "docs", audience: "app" }

        assert_response :forbidden
        assert_equal "forbidden", response.parsed_body.fetch("error")
      end
    end
  end
end
