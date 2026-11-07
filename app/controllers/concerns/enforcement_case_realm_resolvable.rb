# typed: false
# frozen_string_literal: true

# adr/unified-enforcement.md, Realm isolation / Approval: resolves the
# Enforcement Case model class for the realm segment in the route
# (/support/{app,org}/enforcement_cases). A realm-scoped route can only
# ever resolve to that realm's own Case class -- there is no code path by
# which an app-scoped request can reach org data.
module EnforcementCaseRealmResolvable
  extend ActiveSupport::Concern

  CASE_CLASS_BY_REALM = {
    "app" => AppEnforcementCase,
    "org" => OrgEnforcementCase,
  }.freeze

  private

  def enforcement_case_class
    CASE_CLASS_BY_REALM.fetch(params.fetch(:realm).to_s) { raise ActionController::RoutingError, "unknown realm" }
  end
end
