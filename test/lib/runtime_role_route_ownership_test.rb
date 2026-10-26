# frozen_string_literal: true

require "test_helper"

# R5-WU17 role ingress boundary: every routed controller has exactly one owning runtime role, and a
# role process serves only its own controllers.
class RuntimeRoleRouteOwnershipTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Framework engines are not application surfaces; a role process does not serve them. The
  # inertia_rails DevTools routes are drawn in every environment but only match in development;
  # the test below shows they are unreachable here.
  FRAMEWORK_PREFIXES = %w(rails/ active_storage/ action_mailbox/ turbo/ inertia_rails/devtools/).freeze

  test "inertia_rails DevTools routes are unreachable outside development" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/_inertia/devtools/entries")
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/_inertia/devtools/entries/1")
    end
  end

  test "every routed application controller has an owning role" do
    unowned =
      routed_controllers.reject { |path| path.start_with?(*FRAMEWORK_PREFIXES) }.filter_map do |path|
        RuntimeRole.route_owner(path)
        nil
      rescue RuntimeRole::UnownedRoute
        path
      end

    assert_empty unowned
  end

  test "every owning role is a known runtime role" do
    owners =
      routed_controllers.reject { |path| path.start_with?(*FRAMEWORK_PREFIXES) }.map do |path|
        RuntimeRole.route_owner(path)
      end.uniq - [RuntimeRole::ANY_ROLE]

    assert_empty owners - RuntimeRole::ALL
  end

  test "Base identity and credential pages belong to the realm RP" do
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/identity/birthdates")
    assert_equal "rp-base-com-ww", RuntimeRole.route_owner("base/com/verification/setups")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/identity/secret_credentials")
    assert_equal "op-base-app", RuntimeRole.route_owner("base/app/ceremony_binding_confirmations")
    assert_equal "op-base-org", RuntimeRole.route_owner("visa/org/oauth/tokens")
  end

  test "Visa roots and logout completion and credential endpoints are OP owned in every realm" do
    %w(app com org).each do |realm|
      %w(roots sign_byes edge/v0/token/checks edge/v0/token/refreshes).each do |path|
        controller = "visa/#{realm}/#{path}"

        assert_equal "op-base-#{realm}", RuntimeRole.route_owner(controller)
        assert RuntimeRole.serves?(controller, "op-base-#{realm}")
        assert_not RuntimeRole.serves?(controller, "rp-base-#{realm}-ww")
      end
    end
  end

  test "Base Self-RP entry, callback, Refresh, logout receiver and relay pages belong to the Base cell" do
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/sign/entries")
    assert_equal "rp-base-com-ww", RuntimeRole.route_owner("base/com/oidc/callbacks")
    assert_equal "rp-base-org-ww", RuntimeRole.route_owner("base/org/oidc/closures")
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/avatars")
  end

  test "domain owner APIs belong to their domain authority" do
    assert_equal "domain-avatar", RuntimeRole.route_owner("base/app/api/v0/avatar/avatars")
    assert_equal "domain-publishing", RuntimeRole.route_owner("base/org/api/v0/publishing/entries")
    assert_equal "domain-org", RuntimeRole.route_owner("base/org/api/v0/support/accounts")
  end

  test "RP families map to their own cell" do
    assert_equal "rp-core-com-jp", RuntimeRole.route_owner("core/com/roots")
    assert_equal "rp-warp-org-jp", RuntimeRole.route_owner("warp/org/roots")
    assert_equal "rp-palm-app-jp", RuntimeRole.route_owner("palm/app/roots")
    assert_equal "rp-edit-org-ww", RuntimeRole.route_owner("edit/org/roots")
    assert_equal "rp-tech-org-ww", RuntimeRole.route_owner("tech/org/roots")
    assert_equal "auth-com", RuntimeRole.route_owner("auth/com/sign/in/emails")
  end

  test "a prefix matches whole path segments only" do
    # `identities` is its own entry; `identityx` shares the characters of `identity` but no segment.
    assert_equal "rp-base-app-ww", RuntimeRole.route_owner("base/app/identities")
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("base/app/identityx") }
  end

  test "an unknown family or empty path is unowned" do
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("unknown/app/roots") }
    assert_raises(RuntimeRole::UnownedRoute) { RuntimeRole.route_owner("") }
  end

  test "a role serves its own controllers and shared paths, and nothing else" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "open"

    assert RuntimeRole.serves?("core/app/roots", "rp-core-app-jp")
    assert RuntimeRole.serves?("base/app/healths", "rp-core-app-jp")
    assert_not RuntimeRole.serves?("core/com/roots", "rp-core-app-jp")
    assert RuntimeRole.serves?("base/app/identity/birthdates", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/ceremony_binding_confirmations", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/avatars", "op-base-app")
    assert_not RuntimeRole.serves?("unknown/app/roots", "op-base-app")
  end

  test "a closed RP cell serves only its back-channel logout receiver and health" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "closed"

    assert RuntimeRole.serves?("base/app/oidc/closures", "rp-base-app-ww")
    assert RuntimeRole.serves?("base/app/healths", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("base/app/avatars", "rp-base-app-ww")
    assert_not RuntimeRole.serves?("core/app/oidc/callbacks", "rp-core-app-jp")
  end

  test "an RP cell refuses to guess its browser admission" do
    ENV["UMAXICA_RP_BROWSER_ADMISSION"] = "ajar"

    assert_raises(RuntimeRole::UnknownRole) { RuntimeRole.serves?("core/app/roots", "rp-core-app-jp") }
    ENV.delete("UMAXICA_RP_BROWSER_ADMISSION")
    assert_raises(KeyError) { RuntimeRole.serves?("core/app/roots", "rp-core-app-jp") }
  end

  test "the shared transitional role serves every controller, including unowned ones" do
    assert RuntimeRole.serves?("base/app/identity/birthdates", RuntimeRole::SHARED)
    assert RuntimeRole.serves?("unknown/app/roots", RuntimeRole::SHARED)
  end

  teardown { ENV.delete("UMAXICA_RP_BROWSER_ADMISSION") }

  private

  def routed_controllers
    Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq
  end
end
