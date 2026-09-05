# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AcmePublicResourceRoutesTest < ActiveSupport::TestCase
  def test_accounts_and_organizations_routes_are_index_show_only
    route_file = File.read(File.expand_path("../../config/routes/base.rb", __dir__))

    assert_match(/resources :accounts, only: %i\(index show\)/, route_file)
    assert_match(/resources :organizations, only: %i\(index show\)/, route_file)
    assert_no_match(/resources :accounts, only: %i\(index new create show edit update\)/, route_file)
    assert_no_match(/resources :organizations, only: %i\(index new create show edit update\)/, route_file)
  end

  # adr/acme-account-organization-resource-boundary.md keeps the Acme account and
  # organization resources on the default `params[:id]` parameter, resolving
  # `public_id` in the controller via `to_param` rather than renaming the route
  # segment. The published content resources are the deliberate exception: Phase
  # C1 addresses `GET /api/v0/entries/:public_id` by an opaque `public_id` that is
  # part of the API contract and its OpenAPI path parameter name, so those route
  # files legitimately declare `param: :public_id`.
  CONTENT_ROUTE_FILES = %w(docs.rb help.rb info.rb news.rb).freeze

  def test_route_files_do_not_use_param_public_id
    route_files = Dir.glob(File.expand_path("../../config/routes/*.rb", __dir__))
    violations =
      route_files.filter_map do |path|
        next if CONTENT_ROUTE_FILES.include?(File.basename(path))

        File.read(path).match?(/param:\s*:public_id/) ? File.basename(path) : nil
      end

    assert_empty violations, "Remove `param: :public_id` from route files: #{violations.join(", ")}"
  end
end
