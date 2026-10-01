# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth::Org
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    setup do
      host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
      @controller = ::Auth::Org::ApplicationController.new
      @controller.request = ActionDispatch::TestRequest.create(
        "rack.session" => {},
        "rack.session.options" => { id: SecureRandom.hex(16) },
      )
      @controller.response = ActionDispatch::TestResponse.new
      @staff =
        Operator.find_or_create_by!(id: 1) do |s|
          s.status_id = OperatorStatus::NOTHING
        end
    end

    test "includes expected concerns" do
      assert_includes @controller.class, ::PreferenceGlobal
      assert_includes @controller.class, RateLimit
    end

    test "defines full access controller" do
      assert_equal ::Auth::Org::ApplicationController, ::Auth::Org::FullAccessController.superclass
    end

    test "reflects localization and theme after actor context is set" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |callback| callback.kind == :before }.map(&:filter)

      expected_before_filters = %i(
        set_current_context
        set_preferences_cookie
        transparent_refresh_access_token
        set_current_actor
        apply_localization_preferences
        set_color_theme
        enforce_verification_if_required
        enforce_access_policy!
      )

      expected_before_filters.each_cons(2) do |first, second|
        assert_operator before_filters.index(first), :<, before_filters.index(second)
      end
    end

    test "clears actor context through around lifecycle" do
      callbacks = ApplicationController._process_action_callbacks
      around_filters = callbacks.select { |callback| callback.kind == :around }.map(&:filter)

      assert_includes around_filters, :with_actor_lifecycle
    end
    test "am_i_user? returns false" do
      assert_not @controller.send(:am_i_user?)
    end

    test "authenticate_operator! allows access when operator is logged in" do
      host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
      token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      jwt = AuthenticationToken.encode(
        @staff, host: host, session_public_id: token.public_id, resource_type: "operator",
                jwt_issuer_id: "surface:AUTH_ORG",
      )
      @controller.request.headers["Authorization"] = "Bearer #{jwt}"
      # Should not raise or redirect
      assert_nothing_raised do
        @controller.send(:authenticate_operator!)
      end
    end
  end
end
