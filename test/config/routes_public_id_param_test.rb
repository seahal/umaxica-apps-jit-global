# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RoutesPublicIdParamTest < ActiveSupport::TestCase
  # The Acme account/organization resources resolve `public_id` through the
  # default `params[:id]` and `to_param`, never by renaming the route segment
  # (adr/acme-account-organization-resource-boundary.md). The published content
  # resources are the deliberate exception: Phase C1 makes `public_id` the opaque
  # identity of `GET /api/v0/entries/:public_id` and its OpenAPI path parameter,
  # so those four route files legitimately declare `param: :public_id`.
  CONTENT_ROUTE_FILES = %w(docs.rb help.rb info.rb news.rb).freeze

  test "routes do not use param public_id" do
    route_files = Rails.root.glob("{config/routes,config/routing}/*.rb")
    violations =
      route_files.filter_map do |file|
        next if CONTENT_ROUTE_FILES.include?(file.basename.to_s)
        next unless file.read.match?(/param:\s*:public_id/)

        file.relative_path_from(Rails.root).to_s
      end

    assert_empty violations, "Remove `param: :public_id` from route files: #{violations.join(", ")}"
  end
end
