# typed: false
# frozen_string_literal: true

require "test_helper"

class ComVisitorPreferenceCurrentBehaviorTest < ActiveSupport::TestCase
  test "base com application controller includes preference adoption" do
    assert_includes Base::Com::ApplicationController.ancestors, PreferenceAdoption
  end

  test "core com application controller includes preference adoption" do
    assert_includes Core::Com::ApplicationController.ancestors, PreferenceAdoption
  end
end

class ComVisitorPreferenceControllerAdoptionTest < ActionDispatch::IntegrationTest
  test "base com signed-in visitor preference recreation synchronizes visitor mirror" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! host
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)

    visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
      mfa_level_id: VisitorMfaLevel::NOTHING,
      mfa_status_id: VisitorMfaStatus::UNCONFIGURED,
      discard_at: 20.years.from_now,
      purge_eligible_at: 20.years.from_now,
    )

    cookies.delete(PreferenceCookieName.refresh(surface: :com))

    get base_com_root_path,
        headers: as_visitor_headers(visitor, host: host)

    assert_response :redirect
    assert_predicate ComPreference, :exists?, "expected the request to bootstrap a ComPreference"
    assert_not_nil visitor.reload.visitor_preference,
                   "expected PreferenceAdoption to synchronize the VisitorPreference mirror"
  end
end
